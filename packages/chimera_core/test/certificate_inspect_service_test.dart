import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final pem = _certificateFixture('pem').readAsStringSync();
  final base64 = _certificateFixture('base64').readAsStringSync();
  final der = _certificateFixture('der').readAsBytesSync();

  for (final representation in CertificateInputRepresentation.values) {
    if (representation != CertificateInputRepresentation.der) {
      test(
        'Given${representation.name}Text_WhenInspected_ThenMetadataReturns',
        () async {
          final output = _success(
            await const CertificateInspectService().execute(
              CertificateInspectOperationRequest.fromText(
                representation == CertificateInputRepresentation.base64
                    ? base64
                    : pem,
                representation: representation,
              ),
            ),
          );
          expect(
            output.representation,
            representation == CertificateInputRepresentation.auto
                ? CertificateInputRepresentation.pem
                : representation,
          );
          expect(output.serialNumberHex, '01AB');
          expect(output.derByteCount, 534);
        },
      );
    }
    test(
      'Given${representation.name}Bytes_WhenInspected_ThenMetadataReturns',
      () async {
        final input = switch (representation) {
          CertificateInputRepresentation.pem => utf8.encode(pem),
          CertificateInputRepresentation.base64 => utf8.encode(base64),
          _ => der,
        };
        final output = _success(
          await const CertificateInspectService().execute(
            CertificateInspectOperationRequest.fromBytes(
              input,
              representation: representation,
            ),
          ),
        );
        expect(
          output.representation,
          representation == CertificateInputRepresentation.auto
              ? CertificateInputRepresentation.der
              : representation,
        );
        expect(output.inputByteCount, input.length);
        expect(output.derByteCount, 534);
        expect(output.version, 3);
        expect(output.serialNumberHex, '01AB');
      },
    );
  }

  test('GivenDefaultFactories_WhenInspected_ThenAutoDetects', () async {
    final service = const CertificateInspectService();
    expect(
      _success(
        await service.execute(
          CertificateInspectOperationRequest.fromText(base64),
        ),
      ).representation,
      CertificateInputRepresentation.base64,
    );
    expect(
      _success(
        await service.execute(
          CertificateInspectOperationRequest.fromBytes(utf8.encode(pem)),
        ),
      ).representation,
      CertificateInputRepresentation.pem,
    );
  });

  test('GivenFixture_WhenSerialized_ThenExactOrderedMetadataJsonReturns', () async {
    final output = _success(
      await const CertificateInspectService().execute(
        CertificateInspectOperationRequest.fromText(pem),
      ),
    );
    expect(
      jsonEncode(output.toJson()),
      '{"representation":"pem","version":3,"serialNumberHex":"01AB",'
      '"subject":[{"oid":"2.5.4.3","name":"commonName","value":"example.test"},'
      '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"},'
      '{"oid":"1.2.3.4","name":null,"value":"Unknown attribute"}],'
      '"issuer":[{"oid":"2.5.4.3","name":"commonName","value":"Example CA"},'
      '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"}],'
      '"notBefore":"2024-01-01T00:00:00.000Z","notAfter":"2034-01-01T00:00:00.000Z",'
      '"signatureAlgorithm":{"oid":"1.2.840.113549.1.1.11","name":"sha256WithRSAEncryption"},'
      '"publicKeyAlgorithm":{"oid":"1.2.840.113549.1.1.1","name":"rsaEncryption"},'
      '"extensions":[{"oid":"2.5.29.19","name":"basicConstraints","critical":true},'
      '{"oid":"1.2.3.5","name":null,"critical":false}],"inputByteCount":778,"derByteCount":534}',
    );
    expect(output.notBefore, DateTime.utc(2024));
    expect(output.notAfter, DateTime.utc(2034));
  });

  test(
    'GivenMetadata_WhenSerialized_ThenAllCollectionsAreImmutableSnapshots',
    () async {
      final output = _success(
        await const CertificateInspectService().execute(
          CertificateInspectOperationRequest.fromBytes(der),
        ),
      );
      final json = output.toJson();
      expect(() => json.clear(), throwsUnsupportedError);
      for (final key in ['subject', 'issuer', 'extensions']) {
        final list = json[key]! as List<Object?>;
        expect(() => list.clear(), throwsUnsupportedError);
        expect(
          () => (list.first! as Map<String, Object?>).clear(),
          throwsUnsupportedError,
        );
      }
      for (final key in ['signatureAlgorithm', 'publicKeyAlgorithm']) {
        expect(
          () => (json[key]! as Map<String, Object?>).clear(),
          throwsUnsupportedError,
        );
      }
      expect(() => output.subject.clear(), throwsUnsupportedError);
      expect(() => output.issuer.clear(), throwsUnsupportedError);
      expect(() => output.extensions.clear(), throwsUnsupportedError);
      expect(output.toJson(), json);
      expect(output.toJson(), isNot(same(json)));
    },
  );

  test(
    'GivenOffsetDates_WhenSerialized_ThenUtcMillisecondPrecisionIsStable',
    () {
      final attributes = <CertificateAttribute>[
        const CertificateAttribute(oid: '2.5.4.3', name: null, value: 'first'),
        const CertificateAttribute(oid: '2.5.4.3', name: null, value: 'second'),
      ];
      final extensions = <CertificateExtensionMetadata>[];
      final output = CertificateInspectOutput(
        result: CertificateInspectionResult(
          representation: CertificateInputRepresentation.der,
          version: 1,
          serialNumberHex: '00',
          subject: attributes,
          issuer: attributes,
          notBefore: DateTime.parse('2024-01-01T03:00:00.123456+03:00'),
          notAfter: DateTime.parse('2034-01-01T03:00:00.987654+03:00'),
          signatureAlgorithm: const CertificateAlgorithm(
            oid: '1.2.3',
            name: null,
          ),
          publicKeyAlgorithm: const CertificateAlgorithm(
            oid: '1.2.4',
            name: null,
          ),
          extensions: extensions,
          inputByteCount: 10,
          derByteCount: 10,
        ),
      );
      attributes.clear();
      extensions.add(
        const CertificateExtensionMetadata(
          oid: '1.2.5',
          name: null,
          critical: false,
        ),
      );
      final json = output.toJson();
      expect(json['notBefore'], '2024-01-01T00:00:00.123Z');
      expect(json['notAfter'], '2034-01-01T00:00:00.987Z');
      expect(output.subject.map((a) => a.value), ['first', 'second']);
      expect(output.issuer.map((a) => a.value), ['first', 'second']);
      expect(json['signatureAlgorithm'], {'oid': '1.2.3', 'name': null});
      expect(json['publicKeyAlgorithm'], {'oid': '1.2.4', 'name': null});
      expect(json['extensions'], isEmpty);
    },
  );

  final validationCases = <String, CertificateInspectOperationRequest>{
    'malformed-certificate': CertificateInspectOperationRequest.fromText(
      'sensitive-invalid-certificate',
    ),
    'unsupported-representation': CertificateInspectOperationRequest.fromText(
      pem,
      representation: CertificateInputRepresentation.der,
    ),
    'multiple-certificates': CertificateInspectOperationRequest.fromText(
      '$pem\n$pem',
    ),
    'byte-range': CertificateInspectOperationRequest.fromBytes([256]),
  };
  for (final entry in validationCases.entries) {
    test(
      'Given${entry.key}_WhenInspected_ThenRedactedValidationReturns',
      () async {
        _expectFailure(
          await const CertificateInspectService().execute(entry.value),
          FailureKind.validation,
          'certificate-inspect.invalid-input',
          'error.certificateInspect.validation',
          entry.key,
        );
      },
    );
  }
  for (final entry in <String, CertificateInspector>{
    'input-limit': const CertificateInspector(maxInputBytes: 0),
    'decoded-limit': const CertificateInspector(maxDecodedBytes: 0),
    'allocation-limit': const CertificateInspector(),
  }.entries) {
    test(
      'Given${entry.key}_WhenInspected_ThenRedactedResourceReturns',
      () async {
        final input = entry.key == 'allocation-limit'
            ? _AllocationFailureBytes()
            : der;
        _expectFailure(
          await CertificateInspectService(inspector: entry.value)
              .execute(CertificateInspectOperationRequest.fromBytes(input)),
          FailureKind.resource,
          'certificate-inspect.resource-limit',
          'error.certificateInspect.resource',
          entry.key,
        );
      },
    );
  }
}

File _certificateFixture(String extension) {
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

CertificateInspectOutput _success(
  ChimeraResult<CertificateInspectOutput> result,
) => result.fold(
  onSuccess: (output) => output,
  onFailure: (failure) => fail('Expected success: ${failure.code}'),
);

void _expectFailure(
  ChimeraResult<CertificateInspectOutput> result,
  FailureKind kind,
  String code,
  String messageKey,
  String reason,
) {
  result.fold(
    onSuccess: (_) => fail('Expected failure'),
    onFailure: (failure) {
      expect(failure.kind, kind);
      expect(failure.code, code);
      expect(failure.messageKey, messageKey);
      expect(failure.details, {'field': 'input', 'reason': reason});
      expect(
        failure.details.toString(),
        isNot(contains('sensitive-invalid-certificate')),
      );
    },
  );
}

final class _AllocationFailureBytes extends ListBase<int> {
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
