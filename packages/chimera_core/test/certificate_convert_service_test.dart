import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final pem = _fixture('pem').readAsStringSync();
  final encoded = _fixture('base64').readAsStringSync().trim();
  final der = _fixture('der').readAsBytesSync();

  for (final (source, input) in [
    (CertificateInputRepresentation.pem, pem),
    (CertificateInputRepresentation.base64, encoded),
  ]) {
    for (final target in CertificateOutputRepresentation.values) {
      test(
        'Given${source.name}Text_WhenConvertedTo${target.name}_ThenExactOutputReturns',
        () async {
          final output = _success(
            await const CertificateConvertService().execute(
              CertificateConvertOperationRequest.fromText(
                input,
                source: source,
                target: target,
              ),
            ),
          );
          _expectOutput(
            output,
            source,
            target,
            input.length,
            pem,
            encoded,
            der,
          );
        },
      );
    }
  }

  for (final (source, input) in [
    (CertificateInputRepresentation.pem, ascii.encode(pem)),
    (CertificateInputRepresentation.base64, ascii.encode(encoded)),
    (CertificateInputRepresentation.der, der),
  ]) {
    for (final target in CertificateOutputRepresentation.values) {
      test(
        'Given${source.name}Bytes_WhenConvertedTo${target.name}_ThenExactOutputReturns',
        () async {
          final output = _success(
            await const CertificateConvertService().execute(
              CertificateConvertOperationRequest.fromBytes(
                input,
                source: source,
                target: target,
              ),
            ),
          );
          _expectOutput(
            output,
            source,
            target,
            input.length,
            pem,
            encoded,
            der,
          );
        },
      );
    }
  }

  test('GivenDefaultFactories_WhenConverted_ThenSourceIsDetected', () async {
    const service = CertificateConvertService();
    final text = _success(
      await service.execute(
        CertificateConvertOperationRequest.fromText(
          encoded,
          target: CertificateOutputRepresentation.pem,
        ),
      ),
    );
    final bytes = _success(
      await service.execute(
        CertificateConvertOperationRequest.fromBytes(
          der,
          target: CertificateOutputRepresentation.base64,
        ),
      ),
    );
    expect(text.sourceRepresentation, CertificateInputRepresentation.base64);
    expect(bytes.sourceRepresentation, CertificateInputRepresentation.der);
  });

  for (final (target, text, bytes, count) in [
    (CertificateOutputRepresentation.pem, pem, null, 778),
    (CertificateOutputRepresentation.base64, encoded, null, 712),
    (CertificateOutputRepresentation.der, null, der, 534),
  ]) {
    test('Given${target.name}Output_WhenSerialized_ThenExactOrderedJsonReturns', () async {
      final output = _success(
        await const CertificateConvertService().execute(
          CertificateConvertOperationRequest.fromText(pem, target: target),
        ),
      );
      expect(
        jsonEncode(output.toJson()),
        '{"sourceRepresentation":"pem","targetRepresentation":"${target.name}",'
        '"text":${jsonEncode(text)},"bytes":${jsonEncode(bytes)},'
        '"inputByteCount":778,"derByteCount":534,"outputByteCount":$count}',
      );
      expect(() => output.toJson().clear(), throwsUnsupportedError);
    });
  }

  test(
    'GivenMutableDer_WhenConverted_ThenResultAndJsonOwnImmutableBytes',
    () async {
      final source = List<int>.of(der);
      final output = _success(
        await const CertificateConvertService().execute(
          CertificateConvertOperationRequest.fromBytes(
            source,
            target: CertificateOutputRepresentation.der,
          ),
        ),
      );
      final json = output.toJson();
      final snapshot = json['bytes']! as List<int>;
      source[0] = 0;
      expect(output.bytes, orderedEquals(der));
      expect(snapshot, orderedEquals(der));
      expect(output.bytes, same(output.result.bytes));
      expect(() => output.bytes[0] = 0, throwsUnsupportedError);
      expect(
        () => output.bytes.buffer.asUint8List()[0] = 0,
        throwsUnsupportedError,
      );
      expect(() => snapshot[0] = 0, throwsUnsupportedError);
      expect(() => snapshot.add(0), throwsUnsupportedError);
      final nextJson = output.toJson();
      expect(nextJson, json);
      expect(nextJson, isNot(same(json)));
      expect(nextJson['bytes'], isNot(same(snapshot)));
      expect(snapshot, isNot(same(output.bytes)));
    },
  );

  for (final textSource in [true, false]) {
    test(
      'Given${textSource ? 'Text' : 'Byte'}Request_WhenExecuted_ThenConvertsOnceWithoutCachingViews',
      () async {
        var allocations = 0;
        var textViews = 0;
        final converter = CertificateConverter.forTesting(
          allocateOutput: (length) {
            allocations++;
            return Uint8List(length);
          },
          decodeText: (bytes) {
            textViews++;
            return ascii.decode(bytes);
          },
        );
        final output = _success(
          await CertificateConvertService(converter: converter).execute(
            textSource
                ? CertificateConvertOperationRequest.fromText(
                    pem,
                    target: CertificateOutputRepresentation.base64,
                  )
                : CertificateConvertOperationRequest.fromBytes(
                    der,
                    target: CertificateOutputRepresentation.base64,
                  ),
          ),
        );
        expect(allocations, 1);
        expect(textViews, 0);
        expect(output.text, encoded);
        expect(output.toJson()['text'], encoded);
        expect(textViews, 2);
        expect(allocations, 1);
      },
    );
  }

  final invalidRequests = {
    'malformed-certificate': CertificateConvertOperationRequest.fromText(
      'sensitive-certificate C:\\private\\certificate.pem',
      target: CertificateOutputRepresentation.pem,
    ),
    'unsupported-representation': CertificateConvertOperationRequest.fromText(
      pem,
      source: CertificateInputRepresentation.der,
      target: CertificateOutputRepresentation.der,
    ),
    'multiple-certificates': CertificateConvertOperationRequest.fromText(
      '$pem$pem',
      target: CertificateOutputRepresentation.base64,
    ),
    'byte-range': CertificateConvertOperationRequest.fromBytes([
      256,
    ], target: CertificateOutputRepresentation.pem),
  };
  for (final entry in invalidRequests.entries) {
    test(
      'Given${entry.key}_WhenConverted_ThenRedactedValidationReturns',
      () async {
        _expectFailure(
          await const CertificateConvertService().execute(entry.value),
          FailureKind.validation,
          'certificate-convert.invalid-input',
          'error.certificateConvert.validation',
          'input',
          entry.key,
        );
      },
    );
  }

  for (final (field, reason, converter, input) in [
    (
      'input',
      'input-limit',
      const CertificateConverter(
        inspector: CertificateInspector(maxInputBytes: 0),
      ),
      der,
    ),
    (
      'input',
      'decoded-limit',
      const CertificateConverter(
        inspector: CertificateInspector(maxDecodedBytes: 0),
      ),
      der,
    ),
    (
      'output',
      'output-limit',
      const CertificateConverter(maxOutputBytes: 0),
      der,
    ),
    (
      'input',
      'allocation-limit',
      const CertificateConverter(),
      _ExhaustedBytes(),
    ),
    (
      'output',
      'allocation-limit',
      CertificateConverter.forTesting(
        allocateOutput: (_) => throw OutOfMemoryError(),
      ),
      der,
    ),
  ]) {
    test(
      'Given$field${reason}_WhenConverted_ThenRedactedResourceReturns',
      () async {
        _expectFailure(
          await CertificateConvertService(converter: converter).execute(
            CertificateConvertOperationRequest.fromBytes(
              input,
              target: CertificateOutputRepresentation.pem,
            ),
          ),
          FailureKind.resource,
          'certificate-convert.resource-limit',
          'error.certificateConvert.resource',
          field,
          reason,
        );
      },
    );
  }

  test(
    'GivenUnexpectedConverterError_WhenExecuted_ThenErrorPropagates',
    () async {
      final error = StateError('unexpected collaborator error');
      final converter = CertificateConverter.forTesting(
        allocateOutput: (_) => throw error,
      );
      await expectLater(
        CertificateConvertService(converter: converter).execute(
          CertificateConvertOperationRequest.fromBytes(
            der,
            target: CertificateOutputRepresentation.pem,
          ),
        ),
        throwsA(same(error)),
      );
    },
  );
}

void _expectOutput(
  CertificateConvertOutput output,
  CertificateInputRepresentation source,
  CertificateOutputRepresentation target,
  int inputCount,
  String pem,
  String encoded,
  List<int> der,
) {
  expect(output.sourceRepresentation, source);
  expect(output.targetRepresentation, target);
  expect(output.inputByteCount, inputCount);
  expect(output.derByteCount, 534);
  final (text, bytes, count) = switch (target) {
    CertificateOutputRepresentation.pem => (pem, ascii.encode(pem), 778),
    CertificateOutputRepresentation.base64 => (
      encoded,
      ascii.encode(encoded),
      712,
    ),
    CertificateOutputRepresentation.der => (null, der, 534),
  };
  expect(output.text, text);
  expect(output.bytes, orderedEquals(bytes));
  expect(output.outputByteCount, count);
}

CertificateConvertOutput _success(
  ChimeraResult<CertificateConvertOutput> result,
) => result.fold(
  onSuccess: (output) => output,
  onFailure: (failure) => fail('Expected success: ${failure.code}'),
);

void _expectFailure(
  ChimeraResult<CertificateConvertOutput> result,
  FailureKind kind,
  String code,
  String messageKey,
  String field,
  String reason,
) {
  result.fold(
    onSuccess: (_) => fail('Expected failure'),
    onFailure: (failure) {
      expect(failure.kind, kind);
      expect(failure.code, code);
      expect(failure.messageKey, messageKey);
      expect(failure.details, {'field': field, 'reason': reason});
      expect(() => failure.details.clear(), throwsUnsupportedError);
    },
  );
}

File _fixture(String extension) {
  var directory = Directory.current.absolute;
  while (true) {
    final fixture = File.fromUri(
      directory.uri.resolve(
        'tests/fixtures/certificates/certificate.$extension',
      ),
    );
    if (fixture.existsSync()) return fixture;
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Could not locate certificate test fixtures.');
    }
    directory = parent;
  }
}

final class _ExhaustedBytes extends ListBase<int> {
  @override
  int get length => throw OutOfMemoryError();
  @override
  set length(int value) => throw UnsupportedError('Read only');
  @override
  int operator [](int index) => throw OutOfMemoryError();
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('Read only');
}
