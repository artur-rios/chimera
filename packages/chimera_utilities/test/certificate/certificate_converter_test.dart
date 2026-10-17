import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final fixtures = Directory('../../tests/fixtures/certificates');
  final pem = File('${fixtures.path}/certificate.pem').readAsStringSync();
  final encoded = File('${fixtures.path}/certificate.base64')
      .readAsStringSync()
      .trim();
  final der = File('${fixtures.path}/certificate.der').readAsBytesSync();
  const converter = CertificateConverter();

  group('CertificateConverter', () {
    for (final (source, bytes) in [
      (CertificateInputRepresentation.pem, ascii.encode(pem)),
      (CertificateInputRepresentation.der, der),
      (CertificateInputRepresentation.base64, ascii.encode(encoded)),
    ]) {
      for (final target in CertificateOutputRepresentation.values) {
        for (final selected in [CertificateInputRepresentation.auto, source]) {
          test(
            'Given${source.name}Bytes_When${selected.name}To${target.name}_ThenExactOutputReturns',
            () {
              final result = converter.convertBytes(
                bytes,
                source: selected,
                target: target,
              );
              _expectOutput(
                result,
                source,
                target,
                bytes.length,
                pem,
                encoded,
                der,
              );
            },
          );
        }
      }
    }

    for (final (source, text) in [
      (CertificateInputRepresentation.pem, pem),
      (CertificateInputRepresentation.base64, encoded),
    ]) {
      for (final target in CertificateOutputRepresentation.values) {
        for (final selected in [CertificateInputRepresentation.auto, source]) {
          test(
            'Given${source.name}Text_When${selected.name}To${target.name}_ThenExactOutputReturns',
            () {
              final result = converter.convertText(
                text,
                source: selected,
                target: target,
              );
              _expectOutput(
                result,
                source,
                target,
                utf8.encode(text).length,
                pem,
                encoded,
                der,
              );
            },
          );
        }
      }
    }

    test('GivenWhitespaceWrappers_WhenSameFormatConverted_ThenCanonicalBytesReturn', () {
      final wrappedPem = ' \t\r\n${pem.replaceAll('\n', '\r\n')}\t ';
      final wrappedBase64 =
          ' \n${encoded.substring(0, 20)}\t\r\n${encoded.substring(20)} ';
      expect(
        converter
            .convertText(
              wrappedPem,
              target: CertificateOutputRepresentation.pem,
            )
            .text,
        pem,
      );
      expect(
        converter
            .convertText(
              wrappedBase64,
              target: CertificateOutputRepresentation.base64,
            )
            .text,
        encoded,
      );
    });

    test('GivenMutableSource_WhenConverted_ThenOutputOwnsImmutableBytes', () {
      final source = List<int>.of(der);
      final result = converter.convertBytes(
        source,
        target: CertificateOutputRepresentation.der,
      );
      source[0] = 0;
      expect(result.bytes, orderedEquals(der));
      expect(() => result.bytes[0] = 0, throwsUnsupportedError);
      expect(
        () => result.bytes.buffer.asUint8List()[0] = 0,
        throwsUnsupportedError,
      );
    });

    test(
      'GivenPaddingLengths_WhenEncoded_ThenCanonicalPaddingPreservesDer',
      () {
        // Original four-byte serial TLV begins at offset 13. Reduce it by one
        // or enlarge it by one, adjusting the literal outer/TBS lengths.
        for (final serial in [
          [2, 1, 1],
          [2, 3, 1, 2, 3],
        ]) {
          final delta = serial.length - 4;
          final bytes = [
            ...der.take(3),
            der[3] + delta,
            ...der.sublist(4, 7),
            der[7] + delta,
            ...der.sublist(8, 13),
            ...serial,
            ...der.skip(17),
          ];
          final expected = base64Encode(bytes);
          expect(expected.endsWith(serial.length == 3 ? '=' : '=='), isTrue);
          final encodedResult = converter.convertBytes(
            bytes,
            target: CertificateOutputRepresentation.base64,
          );
          expect(encodedResult.text, expected);
          expect(base64Decode(encodedResult.text!), orderedEquals(bytes));
          final pemResult = converter.convertBytes(
            bytes,
            target: CertificateOutputRepresentation.pem,
          );
          final lines = pemResult.text!.split('\n');
          expect(lines.first, '-----BEGIN CERTIFICATE-----');
          expect(lines[lines.length - 2], '-----END CERTIFICATE-----');
          expect(lines.last, isEmpty);
          expect(
            lines
                .sublist(1, lines.length - 3)
                .every((line) => line.length == 64),
            isTrue,
          );
          expect(lines.sublist(1, lines.length - 2).join(), expected);
        }
      },
    );

    test('GivenInvalidText_WhenConverted_ThenSafeValidationFailureReturns', () {
      for (final (input, source, reason) in [
        ('', CertificateInputRepresentation.auto, 'malformed-certificate'),
        (
          'secret-source-path',
          CertificateInputRepresentation.auto,
          'malformed-certificate',
        ),
        (
          '$pem$pem',
          CertificateInputRepresentation.pem,
          'multiple-certificates',
        ),
        (pem, CertificateInputRepresentation.base64, 'malformed-certificate'),
        (
          encoded,
          CertificateInputRepresentation.pem,
          'unsupported-representation',
        ),
        (
          encoded,
          CertificateInputRepresentation.der,
          'unsupported-representation',
        ),
        (
          pem.replaceAll('CERTIFICATE', 'PRIVATE KEY'),
          CertificateInputRepresentation.pem,
          'unsupported-representation',
        ),
      ]) {
        for (final target in CertificateOutputRepresentation.values) {
          expect(
            () => converter.convertText(input, source: source, target: target),
            _invalid(reason),
          );
        }
      }
      try {
        converter.convertText(
          'secret-source-path',
          target: CertificateOutputRepresentation.pem,
        );
        fail('must reject malformed input');
      } on CertificateConversionException catch (error) {
        expect(error.toString(), isNot(contains('secret-source-path')));
      }
    });

    test(
      'GivenMalformedOrNestedSchemaDer_WhenConverted_ThenNoOutputReturns',
      () {
        for (final bytes in [
          <int>[], [48, 0], [...der, 0], der.sublist(0, der.length - 1),
          // The explicit version must contain an INTEGER, not ENUMERATED.
          [...der.take(10), 10, ...der.skip(11)],
        ]) {
          for (final target in CertificateOutputRepresentation.values) {
            CertificateConversionResult? output;
            expect(
              () => output = converter.convertBytes(
                bytes,
                source: CertificateInputRepresentation.der,
                target: target,
              ),
              _invalid('malformed-certificate'),
            );
            expect(output, isNull);
          }
        }
      },
    );

    test('GivenExplicitByteMismatch_WhenConverted_ThenValidationReturns', () {
      for (final (bytes, source, reason) in [
        (der, CertificateInputRepresentation.pem, 'unsupported-representation'),
        (der, CertificateInputRepresentation.base64, 'malformed-certificate'),
        (
          ascii.encode(pem),
          CertificateInputRepresentation.der,
          'malformed-certificate',
        ),
        (
          ascii.encode(encoded),
          CertificateInputRepresentation.der,
          'malformed-certificate',
        ),
        (
          ascii.encode('$pem$pem'),
          CertificateInputRepresentation.pem,
          'multiple-certificates',
        ),
      ]) {
        expect(
          () => converter.convertBytes(
            bytes,
            source: source,
            target: CertificateOutputRepresentation.pem,
          ),
          _invalid(reason),
        );
      }
    });

    test('GivenOutOfRangeBytes_WhenConverted_ThenValidationPrecedesBudget', () {
      const bounded = CertificateConverter(
        inspector: CertificateInspector(maxInputBytes: 0),
      );
      for (final byte in [-1, 256]) {
        expect(
          () => bounded.convertBytes([
            byte,
          ], target: CertificateOutputRepresentation.der),
          _invalid('byte-range'),
        );
      }
    });

    test('GivenExactInputAndDecodedBudgets_WhenConverted_ThenBoundariesAreInclusive', () {
      for (final (source, bytes) in [
        (CertificateInputRepresentation.pem, ascii.encode(pem)),
        (CertificateInputRepresentation.der, der),
        (CertificateInputRepresentation.base64, ascii.encode(encoded)),
      ]) {
        final bounded = CertificateConverter(
          inspector: CertificateInspector(
            maxInputBytes: bytes.length,
            maxDecodedBytes: der.length,
          ),
        );
        expect(
          bounded
              .convertBytes(
                bytes,
                source: source,
                target: CertificateOutputRepresentation.der,
              )
              .bytes,
          orderedEquals(der),
        );
        final inputLimited = CertificateConverter(
          inspector: CertificateInspector(maxInputBytes: bytes.length - 1),
        );
        expect(
          () => inputLimited.convertBytes(
            bytes,
            source: source,
            target: CertificateOutputRepresentation.der,
          ),
          _resource('input', 'input-limit'),
        );
        final decodedLimited = CertificateConverter(
          inspector: CertificateInspector(maxDecodedBytes: der.length - 1),
        );
        expect(
          () => decodedLimited.convertBytes(
            bytes,
            source: source,
            target: CertificateOutputRepresentation.der,
          ),
          _resource('input', 'decoded-limit'),
        );
        if (source != CertificateInputRepresentation.der) {
          final text = ascii.decode(bytes);
          expect(
            bounded
                .convertText(
                  text,
                  source: source,
                  target: CertificateOutputRepresentation.der,
                )
                .bytes,
            orderedEquals(der),
          );
          expect(
            () => inputLimited.convertText(
              text,
              source: source,
              target: CertificateOutputRepresentation.der,
            ),
            _resource('input', 'input-limit'),
          );
          expect(
            () => decodedLimited.convertText(
              text,
              source: source,
              target: CertificateOutputRepresentation.der,
            ),
            _resource('input', 'decoded-limit'),
          );
        }
      }
      expect(
        () => const CertificateConverter(
          inspector: CertificateInspector(maxInputBytes: 1),
        ).convertText('é', target: CertificateOutputRepresentation.pem),
        _resource('input', 'input-limit'),
      );
    });

    test(
      'GivenExactOutputBudgets_WhenConverted_ThenEachTargetBoundaryIsInclusive',
      () {
        for (final (target, length) in [
          (CertificateOutputRepresentation.der, 534),
          (CertificateOutputRepresentation.base64, 712),
          (CertificateOutputRepresentation.pem, 778),
        ]) {
          expect(
            CertificateConverter(maxOutputBytes: length)
                .convertBytes(der, target: target)
                .outputByteCount,
            length,
          );
          CertificateConversionResult? output;
          expect(
            () =>
                output = CertificateConverter(maxOutputBytes: length - 1)
                    .convertBytes(der, target: target),
            _resource('output', 'output-limit'),
          );
          expect(output, isNull);
        }
      },
    );

    test(
      'GivenExhaustedSource_WhenConverted_ThenInputAllocationFailureReturns',
      () {
        for (final target in CertificateOutputRepresentation.values) {
          expect(
            () => converter.convertBytes(_ExhaustedBytes(), target: target),
            _resource('input', 'allocation-limit'),
          );
        }
      },
    );

    test(
      'GivenExhaustedEncoder_WhenConverted_ThenOutputAllocationFailureReturns',
      () {
        final exhausted = CertificateConverter.forTesting(
          allocateOutput: (_) => throw OutOfMemoryError(),
        );
        for (final target in [
          CertificateOutputRepresentation.pem,
          CertificateOutputRepresentation.base64,
        ]) {
          CertificateConversionResult? output;
          expect(
            () => output = exhausted.convertBytes(der, target: target),
            _resource('output', 'allocation-limit'),
          );
          expect(output, isNull);
        }
        // DER reuses the parsed list and needs no encoding allocation.
        expect(
          exhausted
              .convertBytes(der, target: CertificateOutputRepresentation.der)
              .bytes,
          orderedEquals(der),
        );
      },
    );

    test('GivenExhaustedTextView_WhenMaterialized_ThenOutputAllocationFailureReturns', () {
      final exhausted = CertificateConverter.forTesting(
        decodeText: (_) => throw OutOfMemoryError(),
      );
      for (final target in [
        CertificateOutputRepresentation.pem,
        CertificateOutputRepresentation.base64,
      ]) {
        final result = exhausted.convertBytes(der, target: target);
        expect(
          result.bytes,
          orderedEquals(
            ascii.encode(
              target == CertificateOutputRepresentation.pem ? pem : encoded,
            ),
          ),
        );
        expect(() => result.text, _resource('output', 'allocation-limit'));
      }
      expect(
        exhausted
            .convertBytes(der, target: CertificateOutputRepresentation.der)
            .text,
        isNull,
      );
    });

    test('GivenTextViewRequests_WhenRepeated_ThenViewsAreTransient', () {
      var materializations = 0;
      final uncached = CertificateConverter.forTesting(
        decodeText: (bytes) {
          materializations++;
          return ascii.decode(bytes);
        },
      );
      final result = uncached.convertBytes(
        der,
        target: CertificateOutputRepresentation.base64,
      );
      expect(materializations, 0);
      expect(result.text, encoded);
      expect(result.text, encoded);
      expect(materializations, 2);
      expect(result.bytes, isA<Uint8List>());
    });
  });
}

void _expectOutput(
  CertificateConversionResult result,
  CertificateInputRepresentation source,
  CertificateOutputRepresentation target,
  int count,
  String pem,
  String encoded,
  List<int> der,
) {
  expect(result.sourceRepresentation, source);
  expect(result.targetRepresentation, target);
  expect(result.inputByteCount, count);
  expect(result.derByteCount, 534);
  final expected = switch (target) {
    CertificateOutputRepresentation.pem => ascii.encode(pem),
    CertificateOutputRepresentation.base64 => ascii.encode(encoded),
    CertificateOutputRepresentation.der => der,
  };
  expect(result.bytes, orderedEquals(expected));
  expect(result.outputByteCount, expected.length);
  expect(result.text, switch (target) {
    CertificateOutputRepresentation.pem => pem,
    CertificateOutputRepresentation.base64 => encoded,
    CertificateOutputRepresentation.der => null,
  });
  expect(() => result.bytes[0] = 0, throwsUnsupportedError);
}

Matcher _invalid(String reason) => throwsA(
  isA<CertificateConversionException>()
      .having((e) => e.code, 'code', 'certificate-convert.invalid-input')
      .having((e) => e.field, 'field', 'input')
      .having((e) => e.reason, 'reason', reason),
);

Matcher _resource(String field, String reason) => throwsA(
  isA<CertificateConversionResourceException>()
      .having((e) => e.code, 'code', 'certificate-convert.resource-limit')
      .having((e) => e.field, 'field', field)
      .having((e) => e.reason, 'reason', reason),
);

final class _ExhaustedBytes extends ListBase<int> {
  @override
  int get length => throw OutOfMemoryError();
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  int operator [](int index) => throw OutOfMemoryError();
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('immutable');
}
