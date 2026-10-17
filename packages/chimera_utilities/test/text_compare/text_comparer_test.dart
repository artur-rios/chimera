import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('TextComparer', () {
    const comparer = TextComparer();

    test('GivenMixedLineBoundaries_WhenComparedByLine_ThenLogicalLinesAndTerminalBoundaryAreStable', () {
      final result = comparer.compare(
        left: 'alpha\r\nbeta\r',
        right: 'alpha\nBETA\n',
        granularity: 'line',
      );

      expect(result.granularity, TextCompareGranularity.line);
      expect(
        result.spans,
        _spans(<(TextDiffKind, String, int)>[
          (TextDiffKind.unchanged, 'alpha\n', 1),
          (TextDiffKind.removed, 'beta\n', 1),
          (TextDiffKind.added, 'BETA\n', 1),
        ]),
      );
      expect(result.summary.added, 1);
      expect(result.summary.removed, 1);
      expect(result.summary.unchanged, 1);
    });

    test('GivenTerminalBoundaryDifference_WhenComparedByLine_ThenBoundaryRemainsObservable', () {
      final result = comparer.compare(
        left: 'alpha\n',
        right: 'alpha',
        granularity: 'line',
      );

      expect(
        result.spans,
        _spans(<(TextDiffKind, String, int)>[
          (TextDiffKind.removed, 'alpha\n', 1),
          (TextDiffKind.added, 'alpha', 1),
        ]),
      );
    });

    test('GivenInsertedWords_WhenComparedByWord_ThenWhitespaceAndOrderedSpansArePreserved', () {
      final result = comparer.compare(
        left: 'Hello world',
        right: 'Hello brave world',
        granularity: 'word',
      );

      expect(
        result.spans,
        _spans(<(TextDiffKind, String, int)>[
          (TextDiffKind.unchanged, 'Hello ', 2),
          (TextDiffKind.added, 'brave ', 2),
          (TextDiffKind.unchanged, 'world', 1),
        ]),
      );
      expect(result.summary.added, 2);
      expect(result.summary.removed, 0);
      expect(result.summary.unchanged, 3);
    });

    test('GivenUnicodeWhitespaceAndExcludedFormats_WhenComparedByWord_ThenOnlyWhiteSpaceGroups', () {
      final equal = comparer.compare(
        left: 'a\u00A0\u2003b',
        right: 'a\u00A0\u2003b',
        granularity: 'word',
      );
      final changed = comparer.compare(
        left: 'a\u200Bb',
        right: 'a\uFEFFb',
        granularity: 'word',
      );

      expect(
        equal.spans,
        _spans(<(TextDiffKind, String, int)>[
          (TextDiffKind.unchanged, 'a\u00A0\u2003b', 3),
        ]),
      );
      expect(
        changed.spans,
        _spans(<(TextDiffKind, String, int)>[
          (TextDiffKind.removed, 'a\u200Bb', 1),
          (TextDiffKind.added, 'a\uFEFFb', 1),
        ]),
      );
    });

    test('GivenCombiningAndEmojiSequences_WhenComparedByCharacter_ThenGraphemesStayWhole', () {
      final result = comparer.compare(
        left: 'A👨‍👩‍👧‍👦é',
        right: 'A👨‍👩‍👧‍👦é',
        granularity: 'character',
      );

      expect(
        result.spans,
        _spans(<(TextDiffKind, String, int)>[
          (TextDiffKind.unchanged, 'A👨‍👩‍👧‍👦', 2),
          (TextDiffKind.removed, 'é', 1),
          (TextDiffKind.added, 'é', 1),
        ]),
      );
    });

    test(
      'GivenEqualOrEmptyInputs_WhenCompared_ThenStableMinimalResultsReturn',
      () {
        final equal = comparer.compare(
          left: 'same',
          right: 'same',
          granularity: 'character',
        );
        final empty = comparer.compare(
          left: '',
          right: '',
          granularity: 'line',
        );

        expect(
          equal.spans,
          _spans(<(TextDiffKind, String, int)>[
            (TextDiffKind.unchanged, 'same', 4),
          ]),
        );
        expect(equal.summary.unchanged, 4);
        expect(empty.spans, isEmpty);
        expect(empty.summary.added, 0);
        expect(empty.summary.removed, 0);
        expect(empty.summary.unchanged, 0);
      },
    );

    test(
      'GivenGranularitySlugs_WhenParsed_ThenOnlyExactSupportedValuesSucceed',
      () {
        expect(
          TextCompareGranularity.values.map((value) => value.slug),
          <String>['line', 'word', 'character'],
        );
        expect(
          parseTextCompareGranularity('word'),
          TextCompareGranularity.word,
        );
        expect(
          () => parseTextCompareGranularity('WORD'),
          _failure(
            kind: TextCompareFailureKind.validation,
            code: 'text-compare.invalid-granularity',
            field: 'granularity',
            reason: 'unsupported-granularity',
          ),
        );
      },
    );

    test(
      'GivenInvalidGranularityAndOversizeInput_WhenCompared_ThenValidationWins',
      () {
        expect(
          () => const TextComparer(maxInputCodeUnits: 0).compare(
            left: 'sensitive',
            right: 'content',
            granularity: 'sentence',
          ),
          _failure(
            kind: TextCompareFailureKind.validation,
            code: 'text-compare.invalid-granularity',
            field: 'granularity',
            reason: 'unsupported-granularity',
          ),
        );
      },
    );

    test(
      'GivenInputBudget_WhenAtAndOverBoundary_ThenTypedResourceFailureIsStable',
      () {
        expect(
          const TextComparer(maxInputCodeUnits: 2)
              .compare(left: 'a', right: 'b', granularity: 'character')
              .spans,
          isNotEmpty,
        );
        expect(
          () =>
              const TextComparer(maxInputCodeUnits: 1)
                  .compare(left: 'a', right: 'b', granularity: 'character'),
          _resource(field: 'input', reason: 'character-limit'),
        );
      },
    );

    test(
      'GivenTokenBudget_WhenAtAndOverBoundary_ThenTypedResourceFailureIsStable',
      () {
        expect(
          const TextComparer(maxTokenCount: 3)
              .compare(left: 'a b', right: '', granularity: 'word')
              .summary
              .removed,
          3,
        );
        expect(
          () =>
              const TextComparer(maxTokenCount: 2)
                  .compare(left: 'a b', right: '', granularity: 'word'),
          _resource(field: 'tokens', reason: 'token-limit'),
        );
      },
    );

    test('GivenSymbolBudget_WhenAtAndOverBoundary_ThenTypedResourceFailureIsStable', () {
      expect(
        const TextComparer(maxDistinctTokens: 4)
            .compare(left: 'a b', right: 'c', granularity: 'word')
            .spans,
        isNotEmpty,
      );
      expect(
        () =>
            const TextComparer(maxDistinctTokens: 3)
                .compare(left: 'a b', right: 'c', granularity: 'word'),
        _resource(field: 'symbols', reason: 'symbol-limit'),
      );
    });

    test(
      'GivenWorkBudget_WhenAtAndOverBoundary_ThenTypedResourceFailureIsStable',
      () {
        expect(
          const TextComparer(maxWorkUnits: 4)
              .compare(left: 'ab', right: 'cd', granularity: 'character')
              .spans,
          isNotEmpty,
        );
        expect(
          () =>
              const TextComparer(maxWorkUnits: 3)
                  .compare(left: 'ab', right: 'cd', granularity: 'character'),
          _resource(field: 'work', reason: 'work-limit'),
        );
      },
    );

    test(
      'GivenSpanBudget_WhenAtAndOverBoundary_ThenNoPartialResultEscapes',
      () {
        expect(
          const TextComparer(maxResultSpans: 2)
              .compare(left: 'ab', right: 'cd', granularity: 'character')
              .spans,
          hasLength(2),
        );
        expect(
          () =>
              const TextComparer(maxResultSpans: 1)
                  .compare(left: 'ab', right: 'cd', granularity: 'character'),
          _resource(field: 'result', reason: 'span-limit'),
        );
      },
    );
  });
}

Matcher _spans(List<(TextDiffKind, String, int)> expected) => orderedEquals(
  expected.map(
    (value) => isA<TextDiffSpan>()
        .having((span) => span.kind, 'kind', value.$1)
        .having((span) => span.text, 'text', value.$2)
        .having((span) => span.tokenCount, 'tokenCount', value.$3),
  ),
);

Matcher _resource({required String field, required String reason}) => _failure(
  kind: TextCompareFailureKind.resource,
  code: 'text-compare.resource-limit',
  field: field,
  reason: reason,
);

Matcher _failure({
  required TextCompareFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<TextCompareException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
