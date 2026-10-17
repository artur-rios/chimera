import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('Base64ByteEncoder', () {
    const encoder = Base64ByteEncoder();

    test('GivenRfc4648Vectors_WhenBytesEncode_ThenCanonicalBase64Returns', () {
      final cases = <List<int>, String>{
        <int>[]: '',
        <int>[0x66]: 'Zg==',
        <int>[0x66, 0x6F]: 'Zm8=',
        <int>[0x66, 0x6F, 0x6F]: 'Zm9v',
        <int>[0x66, 0x6F, 0x6F, 0x62]: 'Zm9vYg==',
        <int>[0x66, 0x6F, 0x6F, 0x62, 0x61]: 'Zm9vYmE=',
        <int>[0x66, 0x6F, 0x6F, 0x62, 0x61, 0x72]: 'Zm9vYmFy',
      };

      for (final entry in cases.entries) {
        final result = encoder.encodeBytes(entry.key);

        expect(result.encoded, entry.value, reason: '${entry.key}');
        expect(result.inputByteCount, entry.key.length, reason: '${entry.key}');
        expect(
          result.outputCharacterCount,
          entry.value.length,
          reason: '${entry.key}',
        );
      }
    });

    test('GivenArbitraryBinaryBytes_WhenEncoded_ThenEveryByteIsPreserved', () {
      final result = encoder.encodeBytes(<int>[0x00, 0xFF, 0x10, 0x20]);

      expect(result.encoded, 'AP8QIA==');
      expect(result.inputByteCount, 4);
      expect(result.outputCharacterCount, 8);
    });

    test(
      'GivenUnicodeScalarText_WhenEncoded_ThenExactUtf8BytesDetermineOutput',
      () {
        final cases = <String, String>{
          '😀': '8J+YgA==',
          'é': 'w6k=',
          'e\u0301': 'ZcyB',
          '\uFEFFA': '77u/QQ==',
          'a\r\n ': 'YQ0KIA==',
        };

        for (final entry in cases.entries) {
          final result = encoder.encodeText(entry.key);

          expect(result.encoded, entry.value, reason: '${entry.key.runes}');
          expect(
            result.outputCharacterCount,
            entry.value.length,
            reason: '${entry.key.runes}',
          );
        }
      },
    );

    test('GivenStrictUtf8Bytes_WhenEncoded_ThenBytesAreNotNormalized', () {
      final result = encoder.encodeUtf8(<int>[
        0xEF,
        0xBB,
        0xBF,
        0x61,
        0x0D,
        0x0A,
        0x20,
      ]);

      expect(result.encoded, '77u/YQ0KIA==');
      expect(result.inputByteCount, 7);
      expect(result.outputCharacterCount, 12);
    });

    test('GivenOutOfRangeMembers_WhenBytesEncode_ThenValidationFails', () {
      for (final invalid in <int>[-1, 256]) {
        expect(
          () => encoder.encodeBytes(<int>[0, invalid, 255]),
          _base64Failure(
            kind: Base64EncodeFailureKind.validation,
            code: 'base64-encode.invalid-byte',
            field: 'input',
            reason: 'byte-range',
          ),
          reason: 'byte $invalid',
        );
      }
    });

    test('GivenIsolatedSurrogate_WhenTextEncodes_ThenValidationFails', () {
      for (final malformed in <String>[
        String.fromCharCode(0xD800),
        String.fromCharCode(0xDC00),
        'a${String.fromCharCode(0xD800)}b',
      ]) {
        expect(
          () => encoder.encodeText(malformed),
          _base64Failure(
            kind: Base64EncodeFailureKind.validation,
            code: 'base64-encode.invalid-text',
            field: 'input',
            reason: 'invalid-unicode',
          ),
        );
      }
    });

    test('GivenMalformedUtf8_WhenUtf8Encodes_ThenValidationFails', () {
      expect(
        () => encoder.encodeUtf8(<int>[0xC3, 0x28]),
        _base64Failure(
          kind: Base64EncodeFailureKind.validation,
          code: 'base64-encode.invalid-text',
          field: 'input',
          reason: 'invalid-utf8',
        ),
      );
    });

    test('GivenInputBudget_WhenAtBoundary_ThenOnlyOversizedInputFails', () {
      final exact = const Base64ByteEncoder(maxInputBytes: 3)
          .encodeBytes(<int>[0x66, 0x6F, 0x6F]);
      expect(exact.encoded, 'Zm9v');

      expect(
        () =>
            const Base64ByteEncoder(maxInputBytes: 2)
                .encodeBytes(<int>[0x66, 0x6F, 0x6F]),
        _base64Failure(
          kind: Base64EncodeFailureKind.resource,
          code: 'base64-encode.resource-limit',
          field: 'input',
          reason: 'byte-limit',
        ),
      );
    });

    test('GivenUtf8TextBudget_WhenAtBoundary_ThenUtf8ByteCountIsUsed', () {
      final exact = const Base64ByteEncoder(maxInputBytes: 4).encodeText('😀');
      expect(exact.encoded, '8J+YgA==');
      expect(exact.inputByteCount, 4);

      expect(
        () => const Base64ByteEncoder(maxInputBytes: 3).encodeText('😀'),
        _base64Failure(
          kind: Base64EncodeFailureKind.resource,
          code: 'base64-encode.resource-limit',
          field: 'input',
          reason: 'byte-limit',
        ),
      );
    });

    test('GivenOutputBudget_WhenAtBoundary_ThenNoPartialOutputReturns', () {
      final exact = const Base64ByteEncoder(maxOutputCharacters: 4)
          .encodeBytes(<int>[0x66, 0x6F, 0x6F]);
      expect(exact.encoded, 'Zm9v');

      expect(
        () =>
            const Base64ByteEncoder(maxOutputCharacters: 3)
                .encodeBytes(<int>[0x66, 0x6F, 0x6F]),
        _base64Failure(
          kind: Base64EncodeFailureKind.resource,
          code: 'base64-encode.resource-limit',
          field: 'output',
          reason: 'character-limit',
        ),
      );

      final empty = const Base64ByteEncoder(
        maxInputBytes: 0,
        maxOutputCharacters: 0,
      ).encodeBytes(<int>[]);
      expect(empty.encoded, isEmpty);
    });
  });
}

Matcher _base64Failure({
  required Base64EncodeFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<Base64EncodeException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
