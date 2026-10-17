import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('TextUnescaper', () {
    const unescaper = TextUnescaper();

    test('GivenJsonEscapes_WhenUnescaped_ThenStringContentsAreDecoded', () {
      final result = unescaper.unescape(
        const TextUnescapeRequest(
          input: r'\"\\\/\b\f\n\r\t\u0041',
          mode: 'json',
        ),
      );

      expect(result.unescaped, '"\\/\b\f\n\r\tA');
      expect(result.mode, 'json');
    });

    test('GivenUnicodeEscapes_WhenUnescaped_ThenScalarsAreDecoded', () {
      final result = unescaper.unescape(
        const TextUnescapeRequest(input: r'A\u00E9\U0001F600', mode: 'unicode'),
      );

      expect(result.unescaped, 'Aé😀');
    });

    test('GivenCStyleEscapes_WhenUnescaped_ThenEveryFamilyIsDecoded', () {
      final result = unescaper.unescape(
        const TextUnescapeRequest(
          input: r'''\\\'\"\?\a\b\f\n\r\t\v\000\101\x42\u0043\U0001F600''',
          mode: 'c',
        ),
      );

      expect(result.unescaped, '\\\'"?\u0007\b\f\n\r\t\u000B\u0000ABC😀');
    });

    test('GivenHtmlReferences_WhenUnescaped_ThenNamedAndNumericDecode', () {
      final result = unescaper.unescape(
        const TextUnescapeRequest(
          input: '&amp;&lt;&gt;&quot;&apos;&#39;&#xE9;&#128512;',
          mode: 'html',
        ),
      );

      expect(result.unescaped, '&<>"\'\'é😀');
    });

    test('GivenUrlOctets_WhenUnescaped_ThenStrictUtf8ComponentDecodes', () {
      final result = unescaper.unescape(
        const TextUnescapeRequest(
          input: 'A%20z%2F%C3%A9%F0%9F%98%80%7E%2B+',
          mode: 'url',
        ),
      );

      expect(result.unescaped, 'A z/é😀~++');
    });

    test('GivenEscaperOutput_WhenUnescaped_ThenEveryModeRoundTrips', () {
      const escaper = TextEscaper();
      const source = 'Hello "\\\n? é😀 &/%\u0000';

      for (final mode in TextUnescaper.supportedModes) {
        final escaped = escaper.escape(
          TextEscapeRequest(input: source, mode: mode),
        );
        final decoded = unescaper.unescape(
          TextUnescapeRequest(input: escaped.escaped, mode: mode),
        );

        expect(decoded.unescaped, source, reason: mode);
      }
    });

    test('GivenEmptyInput_WhenUnescapedInEveryMode_ThenEmptyIsValid', () {
      for (final mode in TextUnescaper.supportedModes) {
        final result = unescaper.unescape(
          TextUnescapeRequest(input: '', mode: mode),
        );

        expect(result.unescaped, isEmpty, reason: mode);
      }
    });

    test('GivenMalformedJson_WhenUnescaped_ThenTypedOffsetsReturn', () {
      final cases = <String, ({String reason, int offset})>{
        r'\q': (reason: 'unknown-escape', offset: 0),
        r'\u12G4': (reason: 'invalid-hex', offset: 0),
        'a\n': (reason: 'unescaped-control', offset: 1),
      };

      for (final entry in cases.entries) {
        expect(
          () => unescaper.unescape(
            TextUnescapeRequest(input: entry.key, mode: 'json'),
          ),
          _validationFailure(entry.value.reason, entry.value.offset),
          reason: entry.key,
        );
      }
    });

    test('GivenMalformedUnicode_WhenUnescaped_ThenTypedOffsetsReturn', () {
      final cases = <String, ({String reason, int offset})>{
        r'a\u12': (reason: 'incomplete-sequence', offset: 1),
        r'\u12G4': (reason: 'invalid-hex', offset: 0),
        r'\U00110000': (reason: 'out-of-range', offset: 0),
        r'\U0000D800': (reason: 'surrogate-scalar', offset: 0),
      };

      for (final entry in cases.entries) {
        expect(
          () => unescaper.unescape(
            TextUnescapeRequest(input: entry.key, mode: 'unicode'),
          ),
          _validationFailure(entry.value.reason, entry.value.offset),
          reason: entry.key,
        );
      }
    });

    test('GivenMalformedCStyle_WhenUnescaped_ThenTypedOffsetsReturn', () {
      final cases = <String, ({String reason, int offset})>{
        'a\\': (reason: 'incomplete-sequence', offset: 1),
        r'\xG0': (reason: 'invalid-hex', offset: 0),
        r'\400': (reason: 'out-of-range', offset: 0),
        r'\U0000D800': (reason: 'surrogate-scalar', offset: 0),
      };

      for (final entry in cases.entries) {
        expect(
          () => unescaper.unescape(
            TextUnescapeRequest(input: entry.key, mode: 'c'),
          ),
          _validationFailure(entry.value.reason, entry.value.offset),
          reason: entry.key,
        );
      }
    });

    test('GivenMalformedHtml_WhenUnescaped_ThenTypedOffsetsReturn', () {
      final cases = <String, ({String reason, int offset})>{
        'x&bogus;': (reason: 'unknown-entity', offset: 1),
        'x&amp': (reason: 'unterminated-entity', offset: 1),
        '&#x110000;': (reason: 'out-of-range', offset: 0),
        '&#999999999999999999999999999999;': (
          reason: 'out-of-range',
          offset: 0,
        ),
        '&#55296;': (reason: 'surrogate-scalar', offset: 0),
      };

      for (final entry in cases.entries) {
        expect(
          () => unescaper.unescape(
            TextUnescapeRequest(input: entry.key, mode: 'html'),
          ),
          _validationFailure(entry.value.reason, entry.value.offset),
          reason: entry.key,
        );
      }
    });

    test('GivenMalformedUrl_WhenUnescaped_ThenTypedOffsetsReturn', () {
      final cases = <String, ({String reason, int offset})>{
        'abc%': (reason: 'incomplete-percent', offset: 3),
        'a%G0': (reason: 'invalid-hex', offset: 1),
        '%C3%28': (reason: 'invalid-utf8', offset: 0),
      };

      for (final entry in cases.entries) {
        expect(
          () => unescaper.unescape(
            TextUnescapeRequest(input: entry.key, mode: 'url'),
          ),
          _validationFailure(entry.value.reason, entry.value.offset),
          reason: entry.key,
        );
      }
    });

    test('GivenSignedDigits_WhenUnescaped_ThenTypedFailuresReturn', () {
      final cases = <({String input, String mode, String reason})>[
        (input: r'\u+041', mode: 'json', reason: 'invalid-hex'),
        (input: r'\u-001', mode: 'unicode', reason: 'invalid-hex'),
        (input: r'\x+1', mode: 'c', reason: 'invalid-hex'),
        (input: r'\x-1', mode: 'c', reason: 'invalid-hex'),
        (input: '&#+65;', mode: 'html', reason: 'invalid-number'),
        (input: '&#-1;', mode: 'html', reason: 'invalid-number'),
        (input: '&#x+41;', mode: 'html', reason: 'invalid-number'),
        (input: '&#x-1;', mode: 'html', reason: 'invalid-number'),
        (input: '%+1', mode: 'url', reason: 'invalid-hex'),
        (input: '%-1', mode: 'url', reason: 'invalid-hex'),
      ];

      for (final testCase in cases) {
        expect(
          () => unescaper.unescape(
            TextUnescapeRequest(input: testCase.input, mode: testCase.mode),
          ),
          _validationFailure(testCase.reason, 0),
          reason: '${testCase.mode}: ${testCase.input}',
        );
      }
    });

    test('GivenUnicodeSurrogatePairs_WhenUnescaped_ThenScalarReturns', () {
      for (final mode in const <String>['json', 'unicode', 'c']) {
        final result = unescaper.unescape(
          TextUnescapeRequest(input: r'\uD83D\uDE00', mode: mode),
        );

        expect(result.unescaped, '\u{1F600}', reason: mode);
      }
    });

    test('GivenIsolatedSurrogates_WhenUnescaped_ThenTypedFailuresReturn', () {
      for (final mode in const <String>['json', 'unicode', 'c']) {
        for (final input in const <String>[r'\uD800', r'\uDC00']) {
          expect(
            () => unescaper.unescape(
              TextUnescapeRequest(input: input, mode: mode),
            ),
            _validationFailure('surrogate-scalar', 0),
            reason: '$mode: $input',
          );
        }
      }

      final isolated = String.fromCharCode(0xD800);
      for (final mode in TextUnescaper.supportedModes) {
        expect(
          () => unescaper.unescape(
            TextUnescapeRequest(input: isolated, mode: mode),
          ),
          _validationFailure('surrogate-scalar', 0),
          reason: 'literal $mode',
        );
      }
    });

    test('GivenUnsupportedMode_WhenUnescaped_ThenTypedFailureReturns', () {
      expect(
        () => unescaper.unescape(
          const TextUnescapeRequest(input: 'secret', mode: 'JSON'),
        ),
        throwsA(
          isA<TextUnescapeException>()
              .having(
                (error) => error.kind,
                'kind',
                TextUnescapeFailureKind.validation,
              )
              .having(
                (error) => error.code,
                'code',
                'text-unescape.invalid-mode',
              )
              .having((error) => error.field, 'field', 'mode')
              .having((error) => error.reason, 'reason', 'unsupported-mode')
              .having((error) => error.offset, 'offset', isNull),
        ),
      );
    });

    test('GivenInputBudget_WhenExceeded_ThenResourceFailureReturns', () {
      final exact = const TextUnescaper(maxInputCharacters: 2)
          .unescape(const TextUnescapeRequest(input: '😀', mode: 'html'));
      expect(exact.unescaped, '😀');

      expect(
        () =>
            const TextUnescaper(maxInputCharacters: 1)
                .unescape(const TextUnescapeRequest(input: '😀', mode: 'html')),
        _resourceFailure('input', 'input-limit'),
      );
    });

    test('GivenOutputBudget_WhenExceeded_ThenNoPartialOutputReturns', () {
      final exact = const TextUnescaper(
        maxOutputCharacters: 2,
      ).unescape(const TextUnescapeRequest(input: r'\u0041B', mode: 'unicode'));
      expect(exact.unescaped, 'AB');

      expect(
        () => const TextUnescaper(maxOutputCharacters: 1).unescape(
          const TextUnescapeRequest(input: r'\u0041B', mode: 'unicode'),
        ),
        _resourceFailure('unescaped', 'output-limit'),
      );
    });
  });
}

Matcher _validationFailure(String reason, int offset) => throwsA(
  isA<TextUnescapeException>()
      .having((error) => error.kind, 'kind', TextUnescapeFailureKind.validation)
      .having((error) => error.code, 'code', 'text-unescape.malformed-input')
      .having((error) => error.field, 'field', 'input')
      .having((error) => error.reason, 'reason', reason)
      .having((error) => error.offset, 'offset', offset),
);

Matcher _resourceFailure(String field, String reason) => throwsA(
  isA<TextUnescapeException>()
      .having((error) => error.kind, 'kind', TextUnescapeFailureKind.resource)
      .having((error) => error.code, 'code', 'text-unescape.resource-limit')
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason)
      .having((error) => error.offset, 'offset', isNull),
);
