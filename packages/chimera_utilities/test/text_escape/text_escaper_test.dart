import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('TextEscaper', () {
    const escaper = TextEscaper();

    test('GivenJsonMode_WhenEscaped_ThenJsonStringContentsAreCanonical', () {
      final input = String.fromCharCodes(<int>[
        0x41,
        0x22,
        0x5C,
        0x08,
        0x0C,
        0x0A,
        0x0D,
        0x09,
        0x01,
        0xE9,
      ]);

      final result = escaper.escape(
        TextEscapeRequest(input: input, mode: 'json'),
      );

      expect(result.escaped, r'A\"\\\b\f\n\r\t\u0001é');
      expect(result.mode, 'json');
    });

    test('GivenUnicodeMode_WhenEscaped_ThenEveryUtf16UnitUsesUppercaseHex', () {
      final result = escaper.escape(
        const TextEscapeRequest(input: 'Aé😀', mode: 'unicode'),
      );

      expect(result.escaped, r'\u0041\u00E9\uD83D\uDE00');
      expect(result.mode, 'unicode');
    });

    test('GivenCMode_WhenEscaped_ThenConventionalCSequencesAreUsed', () {
      final cases = <String, String>{
        '\\': r'\\',
        "'": r"\'",
        '"': r'\"',
        '\u0007': r'\a',
        '\b': r'\b',
        '\f': r'\f',
        '\n': r'\n',
        '\r': r'\r',
        '\t': r'\t',
        '\u000B': r'\v',
        '\u0000': r'\000',
        '\u0001': r'\001',
        '\u007F': r'\177',
        'Aé': 'Aé',
      };

      for (final entry in cases.entries) {
        final result = escaper.escape(
          TextEscapeRequest(input: entry.key, mode: 'c'),
        );
        expect(result.escaped, entry.value, reason: 'input ${entry.key.runes}');
      }
    });

    test(
      'GivenControlBeforeDigitOrHex_WhenCModeEscapes_ThenTokensRemainDistinct',
      () {
        final result = escaper.escape(
          TextEscapeRequest(
            input: String.fromCharCodes(<int>[0x00, 0x37, 0x01, 0x41]),
            mode: 'c',
          ),
        );

        expect(result.escaped, r'\0007\001A');
      },
    );

    test('GivenHtmlMode_WhenEscaped_ThenFiveSpecialCharactersUseEntities', () {
      final result = escaper.escape(
        const TextEscapeRequest(input: '&<>"\'é', mode: 'html'),
      );

      expect(result.escaped, '&amp;&lt;&gt;&quot;&#39;é');
      expect(result.mode, 'html');
    });

    test('GivenUrlMode_WhenEscaped_ThenUtf8ComponentBytesUseRfc3986', () {
      final result = escaper.escape(
        const TextEscapeRequest(input: 'A z/é😀~!*\'()', mode: 'url'),
      );

      expect(result.escaped, 'A%20z%2F%C3%A9%F0%9F%98%80~%21%2A%27%28%29');
      expect(result.mode, 'url');
    });

    test('GivenEmptyInput_WhenEscapedInEveryMode_ThenEmptyOutputIsValid', () {
      for (final mode in TextEscaper.supportedModes) {
        final result = escaper.escape(TextEscapeRequest(input: '', mode: mode));

        expect(result.escaped, isEmpty, reason: mode);
        expect(result.mode, mode, reason: mode);
      }
    });

    test(
      'GivenUnsupportedMode_WhenEscaped_ThenTypedValidationFailureReturns',
      () {
        for (final mode in <String>['', 'JSON', 'c-style', 'unknown']) {
          expect(
            () =>
                escaper.escape(TextEscapeRequest(input: 'secret', mode: mode)),
            _textEscapeFailure(
              kind: TextEscapeFailureKind.validation,
              code: 'text-escape.invalid-mode',
              field: 'mode',
              reason: 'unsupported-mode',
            ),
            reason: mode,
          );
        }
      },
    );

    test('GivenInputBudget_WhenExceeded_ThenTypedResourceFailureReturns', () {
      final exact = const TextEscaper(maxInputCharacters: 2)
          .escape(const TextEscapeRequest(input: '😀', mode: 'html'));
      expect(exact.escaped, '😀');

      expect(
        () =>
            const TextEscaper(maxInputCharacters: 1)
                .escape(const TextEscapeRequest(input: '😀', mode: 'html')),
        _textEscapeFailure(
          kind: TextEscapeFailureKind.resource,
          code: 'text-escape.resource-limit',
          field: 'input',
          reason: 'input-limit',
        ),
      );
    });

    test('GivenOutputBudget_WhenExceeded_ThenNoPartialOutputIsReturned', () {
      final exact = const TextEscaper(maxOutputCharacters: 5)
          .escape(const TextEscapeRequest(input: '&', mode: 'html'));
      expect(exact.escaped, '&amp;');

      expect(
        () =>
            const TextEscaper(maxOutputCharacters: 4)
                .escape(const TextEscapeRequest(input: '&', mode: 'html')),
        _textEscapeFailure(
          kind: TextEscapeFailureKind.resource,
          code: 'text-escape.resource-limit',
          field: 'escaped',
          reason: 'output-limit',
        ),
      );
      expect(
        () =>
            const TextEscaper(maxOutputCharacters: 0)
                .escape(const TextEscapeRequest(input: 'A', mode: 'json')),
        _textEscapeFailure(
          kind: TextEscapeFailureKind.resource,
          code: 'text-escape.resource-limit',
          field: 'escaped',
          reason: 'output-limit',
        ),
      );
    });
  });
}

Matcher _textEscapeFailure({
  required TextEscapeFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<TextEscapeException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
