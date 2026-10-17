import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('Base64ByteDecoder', () {
    const decoder = Base64ByteDecoder();

    test('GivenRfc4648Vectors_WhenBinaryDecoded_ThenExactBytesReturn', () {
      final cases = <String, List<int>>{
        '': <int>[],
        'Zg==': <int>[0x66],
        'Zm8=': <int>[0x66, 0x6F],
        'Zm9v': <int>[0x66, 0x6F, 0x6F],
        'Zm9vYg==': <int>[0x66, 0x6F, 0x6F, 0x62],
        'Zm9vYmE=': <int>[0x66, 0x6F, 0x6F, 0x62, 0x61],
        'Zm9vYmFy': <int>[0x66, 0x6F, 0x6F, 0x62, 0x61, 0x72],
      };

      for (final entry in cases.entries) {
        final result = decoder.decodeString(
          entry.key,
          mode: Base64DecodeMode.binary,
        );

        expect(result.bytes, entry.value, reason: entry.key);
        expect(result.text, isNull, reason: entry.key);
        expect(result.inputCharacterCount, entry.key.length, reason: entry.key);
        expect(result.outputByteCount, entry.value.length, reason: entry.key);
      }
    });

    test('GivenArbitraryBinary_WhenBinaryDecoded_ThenEveryByteIsPreserved', () {
      final result = decoder.decodeString(
        'AP8QIA==',
        mode: Base64DecodeMode.binary,
      );

      expect(result.bytes, <int>[0x00, 0xFF, 0x10, 0x20]);
      expect(result.text, isNull);
      expect(result.inputCharacterCount, 8);
      expect(result.outputByteCount, 4);
      expect(result.imageCandidateMediaType, isNull);
    });

    test('GivenStrictUtf8Output_WhenTextDecoded_ThenExactTextReturns', () {
      final cases = <({String source, String text, List<int> bytes})>[
        (source: '', text: '', bytes: <int>[]),
        (
          source: 'SGVsbG8=',
          text: 'Hello',
          bytes: <int>[0x48, 0x65, 0x6C, 0x6C, 0x6F],
        ),
        (source: '8J+YgA==', text: '😀', bytes: <int>[0xF0, 0x9F, 0x98, 0x80]),
        (source: 'w6k=', text: 'é', bytes: <int>[0xC3, 0xA9]),
        (source: 'ZcyB', text: 'e\u0301', bytes: <int>[0x65, 0xCC, 0x81]),
        (
          source: '77u/YQ0KIA==',
          text: '\uFEFFa\r\n ',
          bytes: <int>[0xEF, 0xBB, 0xBF, 0x61, 0x0D, 0x0A, 0x20],
        ),
      ];

      for (final entry in cases) {
        final result = decoder.decodeString(
          entry.source,
          mode: Base64DecodeMode.text,
        );

        expect(result.text, entry.text, reason: entry.source);
        expect(result.bytes, entry.bytes, reason: entry.source);
        expect(
          result.inputCharacterCount,
          entry.source.length,
          reason: entry.source,
        );
      }
    });

    test('GivenUtf8SourceBytes_WhenDecoded_ThenSourceIsNotNormalized', () {
      final result = decoder.decodeUtf8(<int>[
        0x5A,
        0x67,
        0x3D,
        0x3D,
      ], mode: Base64DecodeMode.text);

      expect(result.bytes, <int>[0x66]);
      expect(result.text, 'f');
      expect(result.inputCharacterCount, 4);
      expect(result.outputByteCount, 1);
    });

    test('GivenSuccessfulDecode_WhenBytesAreExposed_ThenTheyAreImmutable', () {
      final result = decoder.decodeString(
        'Zm9v',
        mode: Base64DecodeMode.binary,
      );

      expect(() => result.bytes[0] = 0, throwsUnsupportedError);
      expect(result.bytes, <int>[0x66, 0x6F, 0x6F]);
    });

    test('GivenKnownImageSignatures_WhenDecoded_ThenCandidateTypeReturns', () {
      final cases = <String, String>{
        'iVBORw0KGgo=': 'image/png',
        '/9j/4A==': 'image/jpeg',
        'R0lGODdh': 'image/gif',
        'R0lGODlh': 'image/gif',
        'UklGRgAAAABXRUJQ': 'image/webp',
      };

      for (final entry in cases.entries) {
        final result = decoder.decodeString(
          entry.key,
          mode: Base64DecodeMode.binary,
        );

        expect(result.imageCandidateMediaType, entry.value, reason: entry.key);
      }
    });

    test('GivenUnsupportedBinary_WhenDecoded_ThenNoCandidateTypeReturns', () {
      for (final source in <String>[
        'AAEC',
        'iVBORw0K',
        '/9g=',
        'R0lGODc=',
        'UklGRgAAAABXRUJX',
      ]) {
        final result = decoder.decodeString(
          source,
          mode: Base64DecodeMode.binary,
        );

        expect(result.imageCandidateMediaType, isNull, reason: source);
      }
    });

    test('GivenMalformedBase64_WhenDecoded_ThenValidationFails', () {
      for (final source in <String>[
        'A',
        'Zg=',
        'Zg===',
        '=m9v',
        'Zm=v',
        'AA=A',
        'Zg==Zg==',
        'Z g==',
        'Zg==\n',
        'Zg-_',
        'Zg?=',
        'é===',
      ]) {
        expect(
          () => decoder.decodeString(source, mode: Base64DecodeMode.binary),
          _decodeFailure(
            kind: Base64DecodeFailureKind.validation,
            code: 'base64-decode.invalid-input',
            field: 'input',
            reason: 'malformed-base64',
          ),
          reason: source,
        );
      }
    });

    test('GivenNonZeroPaddingBits_WhenDecoded_ThenValidationFails', () {
      for (final source in <String>['Zh==', 'Zm9=']) {
        expect(
          () => decoder.decodeString(source, mode: Base64DecodeMode.binary),
          _decodeFailure(
            kind: Base64DecodeFailureKind.validation,
            code: 'base64-decode.invalid-input',
            field: 'input',
            reason: 'malformed-base64',
          ),
          reason: source,
        );
      }
    });

    test('GivenMalformedUtf8Source_WhenDecoded_ThenValidationFails', () {
      expect(
        () => decoder.decodeUtf8(<int>[
          0xC3,
          0x28,
        ], mode: Base64DecodeMode.binary),
        _decodeFailure(
          kind: Base64DecodeFailureKind.validation,
          code: 'base64-decode.invalid-input',
          field: 'input',
          reason: 'invalid-utf8',
        ),
      );
    });

    test('GivenBomPrefixedUtf8Source_WhenDecoded_ThenSourceIsNotRewritten', () {
      expect(
        () => decoder.decodeUtf8(<int>[
          0xEF,
          0xBB,
          0xBF,
          0x5A,
          0x67,
          0x3D,
          0x3D,
        ], mode: Base64DecodeMode.binary),
        _decodeFailure(
          kind: Base64DecodeFailureKind.validation,
          code: 'base64-decode.invalid-input',
          field: 'input',
          reason: 'malformed-base64',
        ),
      );
    });

    test('GivenInvalidPublicBytes_WhenDecoded_ThenValidationFails', () {
      for (final invalid in <int>[-1, 256]) {
        expect(
          () => decoder.decodeUtf8(<int>[
            0x5A,
            invalid,
          ], mode: Base64DecodeMode.binary),
          _decodeFailure(
            kind: Base64DecodeFailureKind.validation,
            code: 'base64-decode.invalid-input',
            field: 'input',
            reason: 'byte-range',
          ),
          reason: '$invalid',
        );
      }
    });

    test('GivenMalformedDecodedUtf8_WhenTextDecoded_ThenValidationFails', () {
      expect(
        () => decoder.decodeString('wyg=', mode: Base64DecodeMode.text),
        _decodeFailure(
          kind: Base64DecodeFailureKind.validation,
          code: 'base64-decode.invalid-text',
          field: 'output',
          reason: 'invalid-utf8',
        ),
      );
    });

    test('GivenInputBudget_WhenAtBoundary_ThenOnlyOversizedInputFails', () {
      final exact = const Base64ByteDecoder(maxInputCharacters: 4)
          .decodeString('Zm9v', mode: Base64DecodeMode.binary);
      expect(exact.bytes, <int>[0x66, 0x6F, 0x6F]);

      expect(
        () =>
            const Base64ByteDecoder(maxInputCharacters: 3)
                .decodeString('Zm9v', mode: Base64DecodeMode.binary),
        _decodeFailure(
          kind: Base64DecodeFailureKind.resource,
          code: 'base64-decode.resource-limit',
          field: 'input',
          reason: 'character-limit',
        ),
      );

      final empty = const Base64ByteDecoder(maxInputCharacters: 0)
          .decodeString('', mode: Base64DecodeMode.binary);
      expect(empty.bytes, isEmpty);
    });

    test('GivenOutputBudget_WhenAtBoundary_ThenPredictedSizeIsEnforced', () {
      final exact = const Base64ByteDecoder(maxOutputBytes: 3)
          .decodeString('Zm9v', mode: Base64DecodeMode.binary);
      expect(exact.bytes, <int>[0x66, 0x6F, 0x6F]);

      expect(
        () =>
            const Base64ByteDecoder(maxOutputBytes: 2)
                .decodeString('Zm9v', mode: Base64DecodeMode.binary),
        _decodeFailure(
          kind: Base64DecodeFailureKind.resource,
          code: 'base64-decode.resource-limit',
          field: 'output',
          reason: 'byte-limit',
        ),
      );

      expect(
        () =>
            const Base64ByteDecoder(maxOutputBytes: 0)
                .decodeString('Zg==', mode: Base64DecodeMode.binary),
        _decodeFailure(
          kind: Base64DecodeFailureKind.resource,
          code: 'base64-decode.resource-limit',
          field: 'output',
          reason: 'byte-limit',
        ),
      );

      final empty = const Base64ByteDecoder(maxOutputBytes: 0)
          .decodeString('', mode: Base64DecodeMode.binary);
      expect(empty.bytes, isEmpty);
    });
  });
}

Matcher _decodeFailure({
  required Base64DecodeFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<Base64DecodeException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
