import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final fixtures = Directory('../../tests/fixtures/certificates');
  final pem = File('${fixtures.path}/certificate.pem').readAsStringSync();
  final encoded = File('${fixtures.path}/certificate.base64')
      .readAsStringSync();
  final der = File('${fixtures.path}/certificate.der').readAsBytesSync();
  final manifest = jsonDecode(
    File('${fixtures.path}/manifest.json').readAsStringSync(),
  ) as Map<String, Object?>;
  const inspector = CertificateInspector();

  group('CertificateInspector', () {
    test(
      'GivenExtraCertificateField_WhenInspected_ThenStructureIsRejected',
      () {
        final bytes = [...der, 5, 0]..[3] = der[3] + 2;
        expect(
          () => inspector.inspectBytes(bytes),
          _invalid('malformed-certificate'),
        );
      },
    );

    test(
      'GivenCertificatePaddingBits_WhenNonzero_ThenCanonicalBase64IsRequired',
      () {
        final bytes = [...der, 0]..[3] = der[3] + 1;
        // Signature BIT STRING starts 132 bytes before the fixture end.
        bytes[der.length - 130]++;
        final valid = base64Encode(bytes);
        expect(inspector.inspectText(valid).serialNumberHex, '01AB');
        expect(valid.endsWith('AA=='), isTrue);
        final invalid = '${valid.substring(0, valid.length - 3)}B==';
        expect(
          () => inspector.inspectText(invalid),
          _invalid('malformed-certificate'),
        );
      },
    );
    test('GivenLongSerial_WhenInspected_ThenOriginalUnsignedHexIsExact', () {
      final bytes = _replaceSerial(der, [
        2,
        17,
        0,
        0x80,
        0x12,
        0x34,
        0x56,
        0x78,
        0x9A,
        0xBC,
        0xDE,
        0xF0,
        0x12,
        0x34,
        0x56,
        0x78,
        0x9A,
        0xBC,
        0xDF,
      ]);
      expect(
        inspector.inspectBytes(bytes).serialNumberHex,
        '80123456789ABCDEF0123456789ABCDF',
      );
      expect(
        inspector.inspectText(base64Encode(bytes)).serialNumberHex,
        '80123456789ABCDEF0123456789ABCDF',
      );
    });

    test('GivenNestedInvalidFraming_WhenInspected_ThenInputIsRejected', () {
      for (final serial in <List<int>>[
        [2, 0x81, 2, 1, 0xAB],
        [2, 0x82, 0, 2, 1, 0xAB],
        [2, 0x80, 1, 0xAB, 0, 0],
        [2, 3, 1, 0xAB],
        [2, 2, 1, 0xAB, 0],
      ]) {
        expect(
          () => inspector.inspectBytes(_replaceSerial(der, serial)),
          _invalid('malformed-certificate'),
        );
      }
      final brokenVersion = List<int>.of(der)..[9] = 4;
      expect(
        () => inspector.inspectBytes(brokenVersion),
        _invalid('malformed-certificate'),
      );
    });
    test(
      'GivenFixtureForms_WhenExplicitlyInspected_ThenExactMetadataReturns',
      () {
        final cases = <(CertificateInspectionResult, String, int)>[
          (
            inspector.inspectText(
              pem,
              representation: CertificateInputRepresentation.pem,
            ),
            'pem',
            778,
          ),
          (
            inspector.inspectText(
              encoded,
              representation: CertificateInputRepresentation.base64,
            ),
            'base64',
            713,
          ),
          (
            inspector.inspectBytes(
              der,
              representation: CertificateInputRepresentation.der,
            ),
            'der',
            534,
          ),
        ];
        for (final (result, representation, count) in cases) {
          expect(result.representation.name, representation);
          expect(result.inputByteCount, count);
          expect(_metadata(result), _expectedMetadata(manifest));
          expect(result.notBefore.isUtc, isTrue);
          expect(result.notAfter.isUtc, isTrue);
        }
        expect(
          der
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join()
              .toUpperCase(),
          manifest['derHex'],
        );
      },
    );

    test('GivenFixtureForms_WhenAutoDetected_ThenEntryPointsAgree', () {
      for (final (source, representation) in [
        (pem, 'pem'),
        (encoded, 'base64'),
      ]) {
        final text = inspector.inspectText(source);
        final bytes = inspector.inspectBytes(utf8.encode(source));
        expect(text.representation.name, representation);
        expect(bytes.representation.name, representation);
        expect(_metadata(text), _expectedMetadata(manifest));
        expect(_metadata(bytes), _metadata(text));
      }
      expect(
        inspector.inspectBytes(der).representation,
        CertificateInputRepresentation.der,
      );
    });

    test('GivenAsciiWhitespace_WhenInspected_ThenWrappingIsAccepted', () {
      expect(
        _metadata(inspector.inspectText(' \t\r\n$pem\t\n')),
        _expectedMetadata(manifest),
      );
      expect(
        _metadata(
          inspector.inspectText(encoded.replaceAll('A', 'A \t\r\n\v\f')),
        ),
        _expectedMetadata(manifest),
      );
    });

    test('GivenResult_WhenCollectionsAreChanged_ThenMetadataIsImmutable', () {
      final result = inspector.inspectBytes(der);
      expect(() => result.subject.clear(), throwsUnsupportedError);
      expect(() => result.issuer.clear(), throwsUnsupportedError);
      expect(() => result.extensions.clear(), throwsUnsupportedError);
      expect(result.subject.last.name, isNull);
      expect(result.extensions.last.name, isNull);
      expect(result.extensions.last.critical, isFalse);
    });

    test('GivenExplicitMismatches_WhenInspected_ThenNoFallbackOccurs', () {
      expect(
        () => inspector.inspectText(
          pem,
          representation: CertificateInputRepresentation.der,
        ),
        _invalid('unsupported-representation'),
      );
      expect(
        () => inspector.inspectText(
          encoded,
          representation: CertificateInputRepresentation.pem,
        ),
        _invalid('unsupported-representation'),
      );
      expect(
        () => inspector.inspectText(
          pem,
          representation: CertificateInputRepresentation.base64,
        ),
        _invalid('malformed-certificate'),
      );
      expect(
        () => inspector.inspectBytes(
          der,
          representation: CertificateInputRepresentation.pem,
        ),
        _invalid('unsupported-representation'),
      );
      expect(
        () => inspector.inspectBytes(
          utf8.encode(pem),
          representation: CertificateInputRepresentation.der,
        ),
        _invalid('malformed-certificate'),
      );
    });

    test('GivenUnsupportedPemObjects_WhenInspected_ThenSafeFailureReturns', () {
      for (final label in [
        'PRIVATE KEY',
        'RSA PRIVATE KEY',
        'CERTIFICATE REQUEST',
      ]) {
        final other = '-----BEGIN $label-----\nAA==\n-----END $label-----';
        expect(
          () => inspector.inspectText(
            other,
            representation: CertificateInputRepresentation.pem,
          ),
          _invalid('unsupported-representation'),
        );
        expect(
          () => inspector.inspectText('$pem$other'),
          _invalid('unsupported-representation'),
        );
      }
      expect(
        () => inspector.inspectText('$pem$pem'),
        _invalid('multiple-certificates'),
      );
      expect(
        () => inspector.inspectText(
          'unrelated$pem',
          representation: CertificateInputRepresentation.pem,
        ),
        _invalid('unsupported-representation'),
      );
      expect(
        () => inspector.inspectText(
          pem.replaceFirst('END CERTIFICATE', 'END PRIVATE KEY'),
        ),
        _invalid('unsupported-representation'),
      );
    });

    test('GivenMalformedInput_WhenInspected_ThenSafeFailureReturns', () {
      for (final source in [
        '',
        ' \t\n',
        'A',
        'AA==',
        'Zg=',
        'Zh==',
        'Zm9=',
        'Zg-_',
        'é===',
        '\u00a0$encoded',
        '$encoded=',
      ]) {
        expect(
          () => inspector.inspectText(source),
          _invalid('malformed-certificate'),
          reason: source,
        );
      }
      for (final bytes in <List<int>>[
        [],
        [0, 1, 2],
        der.sublist(0, der.length - 1),
        [...der, 0],
        [...der, ...der],
        [48, 128, ...der.sublist(4), 0, 0],
        [48, 131, 0, der[2], der[3], ...der.sublist(4)],
      ]) {
        expect(
          () => inspector.inspectBytes(
            bytes,
            representation: CertificateInputRepresentation.der,
          ),
          _invalid('malformed-certificate'),
        );
      }
      final badPadBits = encoded.trimRight().replaceRange(
        encoded.trimRight().length - 1,
        encoded.trimRight().length,
        '=',
      );
      expect(
        () => inspector.inspectText(badPadBits),
        _invalid('malformed-certificate'),
      );
    });

    test('GivenOutOfRangeBytes_WhenInspected_ThenValidationPrecedesBudget', () {
      for (final byte in [-1, 256]) {
        expect(
          () =>
              const CertificateInspector(maxInputBytes: 0).inspectBytes([byte]),
          _invalid('byte-range'),
        );
      }
    });

    test(
      'GivenResourceBudgets_WhenBoundaryExceeded_ThenExactReasonReturns',
      () {
        expect(
          const CertificateInspector(
            maxInputBytes: 778,
            maxDecodedBytes: 534,
          ).inspectText(pem).derByteCount,
          534,
        );
        expect(
          () => const CertificateInspector(maxInputBytes: 777).inspectText(pem),
          _resource('input-limit'),
        );
        expect(
          () =>
              const CertificateInspector(maxInputBytes: 533).inspectBytes(der),
          _resource('input-limit'),
        );
        expect(
          () => const CertificateInspector(maxInputBytes: 1).inspectText('é'),
          _resource('input-limit'),
        );
        expect(
          () =>
              const CertificateInspector(maxDecodedBytes: 533).inspectText(pem),
          _resource('decoded-limit'),
        );
        expect(
          () =>
              const CertificateInspector(maxDecodedBytes: 533)
                  .inspectText(encoded),
          _resource('decoded-limit'),
        );
        expect(
          () =>
              const CertificateInspector(maxDecodedBytes: 533)
                  .inspectBytes(der),
          _resource('decoded-limit'),
        );
      },
    );

    test('GivenAllocationExhaustion_WhenReadingPublicBytes_ThenSafeResourceFailureReturns', () {
      expect(
        () => inspector.inspectBytes(_ExhaustedBytes()),
        _resource('allocation-limit'),
      );
    });
  });
}

// Fixture offsets: outer SEQUENCE header 0..3, TBS header 4..7,
// explicit version 8..12, serial INTEGER 13..16. Literal replacement
// vectors are independent of the production ASN.1 implementation.
List<int> _replaceSerial(List<int> der, List<int> serial) {
  final delta = serial.length - 4;
  return [
    ...der.take(3),
    der[3] + delta,
    ...der.sublist(4, 7),
    der[7] + delta,
    ...der.sublist(8, 13),
    ...serial,
    ...der.skip(17),
  ];
}

Map<String, Object?> _metadata(CertificateInspectionResult r) => {
  'version': r.version,
  'serialNumberHex': r.serialNumberHex,
  'subject': [
    for (final a in r.subject) {'oid': a.oid, 'name': a.name, 'value': a.value},
  ],
  'issuer': [
    for (final a in r.issuer) {'oid': a.oid, 'name': a.name, 'value': a.value},
  ],
  'notBefore': r.notBefore.toIso8601String(),
  'notAfter': r.notAfter.toIso8601String(),
  'signatureAlgorithm': {
    'oid': r.signatureAlgorithm.oid,
    'name': r.signatureAlgorithm.name,
  },
  'publicKeyAlgorithm': {
    'oid': r.publicKeyAlgorithm.oid,
    'name': r.publicKeyAlgorithm.name,
  },
  'extensions': [
    for (final e in r.extensions)
      {'oid': e.oid, 'name': e.name, 'critical': e.critical},
  ],
  'derByteCount': r.derByteCount,
};

Map<String, Object?> _expectedMetadata(Map<String, Object?> manifest) => {
  for (final key in [
    'version',
    'serialNumberHex',
    'subject',
    'issuer',
    'notBefore',
    'notAfter',
    'signatureAlgorithm',
    'publicKeyAlgorithm',
    'extensions',
    'derByteCount',
  ])
    key: manifest[key],
};

Matcher _invalid(String reason) => throwsA(
  isA<CertificateInspectionException>()
      .having((e) => e.code, 'code', 'certificate-inspect.invalid-input')
      .having((e) => e.field, 'field', 'input')
      .having((e) => e.reason, 'reason', reason),
);

Matcher _resource(String reason) => throwsA(
  isA<CertificateInspectionResourceException>()
      .having((e) => e.code, 'code', 'certificate-inspect.resource-limit')
      .having((e) => e.field, 'field', 'input')
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
