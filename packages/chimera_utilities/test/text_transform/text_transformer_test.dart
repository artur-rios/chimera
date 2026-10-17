import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('TextTransformMode', () {
    test('GivenSupportedSlugs_WhenParsed_ThenStableModesAreReturned', () {
      const expectations = {
        'lowercase': TextTransformMode.lowercase,
        'uppercase': TextTransformMode.uppercase,
        'normalize-whitespace': TextTransformMode.normalizeWhitespace,
        'sort-lines': TextTransformMode.sortLines,
        'deduplicate-lines': TextTransformMode.deduplicateLines,
      };

      for (final entry in expectations.entries) {
        expect(parseTextTransformMode(entry.key), entry.value);
        expect(entry.value.slug, entry.key);
      }
    });

    test('GivenUnsupportedSlug_WhenParsed_ThenTypedValidationIsReturned', () {
      expect(
        () => parseTextTransformMode('title-case'),
        _textTransformFailure(
          kind: TextTransformFailureKind.validation,
          code: 'text-transform.invalid-mode',
          field: 'mode',
          reason: 'unsupported-mode',
        ),
      );
    });
  });

  group('TextTransformer', () {
    const transformer = TextTransformer();

    test('GivenNonAsciiText_WhenLowercased_ThenUnicodeMappingIsApplied', () {
      final result = transformer.transform(input: 'ÉCOLE', mode: 'lowercase');

      expect(result.mode, TextTransformMode.lowercase);
      expect(result.output, 'école');
    });

    test('GivenExpandingMapping_WhenUppercased_ThenExpansionIsPreserved', () {
      final result = transformer.transform(input: 'straße', mode: 'uppercase');

      expect(result.mode, TextTransformMode.uppercase);
      expect(result.output, 'STRASSE');
    });

    test(
      'GivenUnicodeWhitespace_WhenNormalized_ThenOnlyWhiteSpaceSetCollapses',
      () {
        const whiteSpace =
            '\u0009\u000A\u000B\u000C\u000D\u0020\u0085\u00A0\u1680'
            '\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008'
            '\u2009\u200A\u2028\u2029\u202F\u205F\u3000';

        final result = transformer.transform(
          input: '$whiteSpace alpha$whiteSpace beta $whiteSpace',
          mode: 'normalize-whitespace',
        );

        expect(result.output, 'alpha beta');
      },
    );

    test(
      'GivenExcludedFormatCharacters_WhenNormalized_ThenTheyRemainUntouched',
      () {
        final result = transformer.transform(
          input: 'a\u200Bb\uFEFFc',
          mode: 'normalize-whitespace',
        );

        expect(result.output, 'a\u200Bb\uFEFFc');
      },
    );

    test(
      'GivenMixedLineEndings_WhenSorted_ThenUtf16OrderAndBoundaryAreStable',
      () {
        final result = transformer.transform(
          input: '\uE000\r\n\u{10000}\rb\nb\n',
          mode: 'sort-lines',
        );

        expect(result.output, 'b\nb\n\u{10000}\n\uE000\n');
      },
    );

    test(
      'GivenDuplicateLines_WhenDeduplicated_ThenFirstOccurrenceIsPreserved',
      () {
        final result = transformer.transform(
          input: 'b\r\na\rb\na\n',
          mode: 'deduplicate-lines',
        );

        expect(result.output, 'b\na\n');
      },
    );

    test('GivenEmptyInput_WhenTransformed_ThenItRemainsEmpty', () {
      for (final mode in TextTransformMode.values) {
        expect(transformer.transform(input: '', mode: mode.slug).output, '');
      }
    });

    test('GivenBlankLines_WhenDeduplicated_ThenOneBlankLineIsPreserved', () {
      final result = transformer.transform(
        input: 'a\n\na\n\n',
        mode: 'deduplicate-lines',
      );

      expect(result.output, 'a\n\n');
    });

    test('GivenInvalidMode_WhenTransformed_ThenTypedValidationIsReturned', () {
      expect(
        () => transformer.transform(input: 'text', mode: 'title-case'),
        _textTransformFailure(
          kind: TextTransformFailureKind.validation,
          code: 'text-transform.invalid-mode',
          field: 'mode',
          reason: 'unsupported-mode',
        ),
      );
    });

    test('GivenInputBudget_WhenAtBoundary_ThenTransformationSucceeds', () {
      final result = const TextTransformer(maxInputCodeUnits: 2)
          .transform(input: 'ab', mode: 'uppercase');

      expect(result.output, 'AB');
    });

    test('GivenInputOverBudget_WhenTransformed_ThenResourceFailureIsTyped', () {
      expect(
        () =>
            const TextTransformer(maxInputCodeUnits: 1)
                .transform(input: 'ab', mode: 'uppercase'),
        _textTransformFailure(
          kind: TextTransformFailureKind.resource,
          code: 'text-transform.resource-limit',
          field: 'input',
          reason: 'character-limit',
        ),
      );
    });

    test('GivenOutputBudget_WhenAtBoundary_ThenExpansionSucceeds', () {
      final result = const TextTransformer(maxOutputCodeUnits: 2)
          .transform(input: 'ß', mode: 'uppercase');

      expect(result.output, 'SS');
    });

    test('GivenOutputOverBudget_WhenExpanded_ThenResourceFailureIsTyped', () {
      expect(
        () =>
            const TextTransformer(maxOutputCodeUnits: 1)
                .transform(input: 'ß', mode: 'uppercase'),
        _textTransformFailure(
          kind: TextTransformFailureKind.resource,
          code: 'text-transform.resource-limit',
          field: 'output',
          reason: 'character-limit',
        ),
      );
    });
  });
}

Matcher _textTransformFailure({
  required TextTransformFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<TextTransformException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
