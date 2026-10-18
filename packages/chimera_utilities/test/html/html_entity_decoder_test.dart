import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('HtmlEntityDecoder known answers', () {
    const decoder = HtmlEntityDecoder();

    const namedReferences = <String, String>{
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
    };
    for (final entry in namedReferences.entries) {
      test(
        'Given${entry.key}WhenTextDecodesThenExactNamedCharacterReturns',
        () {
          final result = decoder.decodeText(
            HtmlEntityDecodeRequest(input: entry.key),
          );

          expect(result.decoded, entry.value);
        },
      );
    }

    const numericReferences = <String, String>{
      '&#39;': "'",
      '&#233;': 'é',
      '&#xE9;': 'é',
      '&#Xe9;': 'é',
      '&#128512;': '😀',
      '&#x1F600;': '😀',
    };
    for (final entry in numericReferences.entries) {
      test('Given${entry.key}WhenTextDecodesThenExactNumericScalarReturns', () {
        final result = decoder.decodeText(
          HtmlEntityDecodeRequest(input: entry.key),
        );

        expect(result.decoded, entry.value);
      });
    }

    test('GivenNestedEntityTextWhenDecodedThenItDecodesExactlyOnce', () {
      final result = decoder.decodeText(
        const HtmlEntityDecodeRequest(input: '&amp;lt;'),
      );

      expect(result.decoded, '&lt;');
    });

    const preservedText = <String>[
      '',
      'Plain ASCII 123 \t',
      'ação 東京 e\u0301 😀 𐐷',
      '\u0000a\r\nb\n ',
      '\uFEFFleading BOM',
    ];
    for (var index = 0; index < preservedText.length; index += 1) {
      test('GivenLiteralText${index}WhenDecodedThenTextIsPreserved', () {
        final result = decoder.decodeText(
          HtmlEntityDecodeRequest(input: preservedText[index]),
        );

        expect(result.decoded, preservedText[index]);
      });
    }

    test('GivenUtf8WithBomControlsAndEntitiesWhenDecodedThenAllAreExact', () {
      final result = decoder.decodeUtf8(<int>[
        0xef,
        0xbb,
        0xbf,
        0x00,
        0x0d,
        0x0a,
        0xc3,
        0xa7,
        0xf0,
        0x9f,
        0x98,
        0x80,
        0x26,
        0x6c,
        0x74,
        0x3b,
      ]);

      expect(result.decoded, '\uFEFF\u0000\r\nç😀<');
    });

    test('GivenRepeatedCallsWhenSourcesChangeThenResultsAreIndependent', () {
      final first = decoder.decodeText(
        const HtmlEntityDecodeRequest(input: '&lt;first&gt;'),
      );
      final second = decoder.decodeUtf8(<int>[0x26, 0x61, 0x6d, 0x70, 0x3b]);
      final third = decoder.decodeText(
        const HtmlEntityDecodeRequest(input: '&lt;first&gt;'),
      );

      expect(first.decoded, '<first>');
      expect(second.decoded, '&');
      expect(third.decoded, '<first>');
    });
  });

  group('HtmlEntityDecoder validation', () {
    const decoder = HtmlEntityDecoder();

    const malformedText = <({String input, String reason, int offset})>[
      (input: 'x&bogus;', reason: 'unknown-entity', offset: 1),
      (input: 'x&amp', reason: 'unterminated-entity', offset: 1),
      (input: '&#;', reason: 'invalid-number', offset: 0),
      (input: '&#x;', reason: 'invalid-number', offset: 0),
      (input: '&#+65;', reason: 'invalid-number', offset: 0),
      (input: '&#-1;', reason: 'invalid-number', offset: 0),
      (input: '&#x+41;', reason: 'invalid-number', offset: 0),
      (input: '&#x-1;', reason: 'invalid-number', offset: 0),
      (input: '&#12z;', reason: 'invalid-number', offset: 0),
      (input: '&#xg;', reason: 'invalid-number', offset: 0),
      (input: '&#x110000;', reason: 'out-of-range', offset: 0),
      (
        input: '&#999999999999999999999999999999;',
        reason: 'out-of-range',
        offset: 0,
      ),
      (input: '&#55296;', reason: 'surrogate-scalar', offset: 0),
    ];
    for (var index = 0; index < malformedText.length; index += 1) {
      test(
        'GivenMalformedEntity${index}WhenDecodedThenTypedFailureReturns',
        () {
          final testCase = malformedText[index];

          expect(
            () => decoder.decodeText(
              HtmlEntityDecodeRequest(input: testCase.input),
            ),
            _failure(
              kind: HtmlEntityDecodeFailureKind.validation,
              code: 'html-decode.malformed-input',
              field: 'input',
              reason: testCase.reason,
              offset: testCase.offset,
            ),
          );
        },
      );
    }

    test('GivenLiteralSurrogatesWhenDecodedThenExactOffsetsReturn', () {
      for (final testCase in <({String input, int offset})>[
        (input: String.fromCharCode(0xd800), offset: 0),
        (input: String.fromCharCode(0xdc00), offset: 0),
        (input: 'a${String.fromCharCode(0xd800)}b', offset: 1),
        (input: 'a${String.fromCharCode(0xdc00)}b', offset: 1),
      ]) {
        expect(
          () => decoder.decodeText(
            HtmlEntityDecodeRequest(input: testCase.input),
          ),
          _failure(
            kind: HtmlEntityDecodeFailureKind.validation,
            code: 'html-decode.malformed-input',
            field: 'input',
            reason: 'surrogate-scalar',
            offset: testCase.offset,
          ),
        );
      }
    });

    const malformedUtf8 = <({List<int> input, int offset})>[
      (input: <int>[0xc3, 0x28], offset: 0),
      (input: <int>[0x61, 0xc0, 0xaf], offset: 1),
      (input: <int>[0xf0, 0x9f, 0x98], offset: 0),
      (input: <int>[0x61, 0x80], offset: 1),
      (input: <int>[0xed, 0xa0, 0x80], offset: 0),
      (input: <int>[0xf4, 0x90, 0x80, 0x80], offset: 0),
      (input: <int>[0x61, -1], offset: 1),
      (input: <int>[0x61, 256], offset: 1),
    ];
    for (var index = 0; index < malformedUtf8.length; index += 1) {
      test('GivenMalformedUtf8${index}WhenDecodedThenByteOffsetReturns', () {
        final testCase = malformedUtf8[index];

        expect(
          () => decoder.decodeUtf8(testCase.input),
          _failure(
            kind: HtmlEntityDecodeFailureKind.validation,
            code: 'html-decode.malformed-input',
            field: 'input',
            reason: 'invalid-utf8',
            offset: testCase.offset,
          ),
        );
      });
    }

    test('GivenPrivateSourceWhenValidationFailsThenErrorIsRedacted', () {
      try {
        decoder.decodeText(
          const HtmlEntityDecodeRequest(input: 'private-source-&marker;'),
        );
        fail('Expected a typed validation failure');
      } on HtmlEntityDecodeException catch (error) {
        final diagnostics =
            '${error.kind} ${error.code} ${error.field} '
            '${error.reason} ${error.offset} $error';
        expect(diagnostics, isNot(contains('private-source')));
        expect(diagnostics, isNot(contains('marker')));
      }
    });
  });

  group('HtmlEntityDecoder resource boundaries', () {
    test('GivenInputBudgetWhenAtBoundaryThenOnlyOverflowFails', () {
      const decoder = HtmlEntityDecoder(maxInputCharacters: 2);

      expect(
        decoder.decodeText(const HtmlEntityDecodeRequest(input: '😀')).decoded,
        '😀',
      );
      expect(
        () => decoder.decodeText(const HtmlEntityDecodeRequest(input: '😀x')),
        _failure(
          kind: HtmlEntityDecodeFailureKind.resource,
          code: 'html-decode.resource-limit',
          field: 'input',
          reason: 'input-limit',
        ),
      );
    });

    test('GivenOutputBudgetWhenAtBoundaryThenOnlyOverflowFails', () {
      const decoder = HtmlEntityDecoder(maxOutputCharacters: 1);

      expect(
        decoder
            .decodeText(const HtmlEntityDecodeRequest(input: '&amp;'))
            .decoded,
        '&',
      );
      expect(
        () =>
            decoder.decodeText(const HtmlEntityDecodeRequest(input: '&amp;x')),
        _failure(
          kind: HtmlEntityDecodeFailureKind.resource,
          code: 'html-decode.resource-limit',
          field: 'decoded',
          reason: 'output-limit',
        ),
      );
      expect(
        () => decoder.decodeText(
          const HtmlEntityDecodeRequest(input: '&#128512;'),
        ),
        _failure(
          kind: HtmlEntityDecodeFailureKind.resource,
          code: 'html-decode.resource-limit',
          field: 'decoded',
          reason: 'output-limit',
        ),
      );
    });

    test('GivenZeroBudgetsWhenInputIsEmptyThenEmptyOutputSucceeds', () {
      const decoder = HtmlEntityDecoder(
        maxInputCharacters: 0,
        maxOutputCharacters: 0,
      );

      expect(
        decoder.decodeText(const HtmlEntityDecodeRequest(input: '')).decoded,
        '',
      );
      expect(decoder.decodeUtf8(<int>[]).decoded, '');
    });

    test('GivenConversionOutOfMemoryWhenDecodedThenResourceFailureReturns', () {
      final decoder = HtmlEntityDecoder.forTesting(
        convert: (_) => throw OutOfMemoryError(),
      );

      for (final decode in <void Function()>[
        () => decoder.decodeText(
          const HtmlEntityDecodeRequest(input: 'private-source'),
        ),
        () => decoder.decodeUtf8(<int>[0x61]),
      ]) {
        expect(
          decode,
          _failure(
            kind: HtmlEntityDecodeFailureKind.resource,
            code: 'html-decode.resource-limit',
            field: 'decoded',
            reason: 'allocation-limit',
          ),
        );
      }
    });

    test('GivenNegativeBudgetsWhenConstructedThenAssertionsRejectThem', () {
      expect(
        () => HtmlEntityDecoder(maxInputCharacters: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HtmlEntityDecoder(maxOutputCharacters: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HtmlEntityDecoder.forTesting(maxInputCharacters: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => HtmlEntityDecoder.forTesting(maxOutputCharacters: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

Matcher _failure({
  required HtmlEntityDecodeFailureKind kind,
  required String code,
  required String field,
  required String reason,
  int? offset,
}) => throwsA(
  isA<HtmlEntityDecodeException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason)
      .having((error) => error.offset, 'offset', offset),
);
