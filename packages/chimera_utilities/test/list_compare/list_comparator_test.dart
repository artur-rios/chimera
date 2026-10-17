import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('ListComparator', () {
    const comparator = ListComparator();

    test(
      'GivenDifferentLists_WhenCompared_ThenStableMultisetSectionsAreReturned',
      () {
        final result = comparator.compare(
          const ListCompareRequest(
            left: 'alpha\nbeta\nalpha\nleft',
            right: 'alpha\ngamma\nalpha\nright',
          ),
        );

        expect(result.leftOnly, ['beta', 'left']);
        expect(result.rightOnly, ['gamma', 'right']);
        expect(result.intersection, ['alpha', 'alpha']);
        expect(result.equal, isFalse);
        expect(result.caseMode, 'sensitive');
        expect(result.whitespaceMode, 'preserve');
        expect(result.duplicateMode, 'preserve');
      },
    );

    test('GivenEqualLists_WhenCompared_ThenEqualityIsTrue', () {
      final result = comparator.compare(
        const ListCompareRequest(left: 'one\ntwo', right: 'one\ntwo'),
      );

      expect(result.leftOnly, isEmpty);
      expect(result.rightOnly, isEmpty);
      expect(result.intersection, ['one', 'two']);
      expect(result.equal, isTrue);
    });

    test(
      'GivenEmptyAndBlankLines_WhenCompared_ThenOnlyEmptyInputMeansNoItems',
      () {
        final empty = comparator.compare(
          const ListCompareRequest(left: '', right: ''),
        );
        expect(empty.intersection, isEmpty);

        final blanks = comparator.compare(
          const ListCompareRequest(left: '\n', right: '\n\n'),
        );
        expect(blanks.intersection, ['', '']);
        expect(blanks.leftOnly, isEmpty);
        expect(blanks.rightOnly, ['']);
      },
    );

    test('GivenMixedLineEndings_WhenCompared_ThenEveryEndingSplitsAList', () {
      final result = comparator.compare(
        const ListCompareRequest(
          left: 'one\r\ntwo\rthree\nfour',
          right: 'one\ntwo\nthree\nfour',
        ),
      );

      expect(result.intersection, ['one', 'two', 'three', 'four']);
      expect(result.equal, isTrue);
    });

    test('GivenUnicodeItems_WhenCompared_ThenOriginalValuesArePreserved', () {
      final result = comparator.compare(
        const ListCompareRequest(left: '🚀\nOlá\n漢字', right: '漢字\n🚀\nOutro'),
      );

      expect(result.intersection, ['🚀', '漢字']);
      expect(result.leftOnly, ['Olá']);
      expect(result.rightOnly, ['Outro']);
    });

    test('GivenCaseModes_WhenCompared_ThenOnlyInsensitiveFoldsCase', () {
      final sensitive = comparator.compare(
        const ListCompareRequest(left: 'Alpha', right: 'alpha'),
      );
      expect(sensitive.equal, isFalse);

      final insensitive = comparator.compare(
        const ListCompareRequest(
          left: 'Alpha\nBETA',
          right: 'alpha\nbeta',
          caseMode: 'insensitive',
        ),
      );
      expect(insensitive.intersection, ['Alpha', 'BETA']);
      expect(insensitive.equal, isTrue);
    });

    test('GivenWhitespaceModes_WhenCompared_ThenTrimUsesTrimmedKeys', () {
      final preserved = comparator.compare(
        const ListCompareRequest(left: ' alpha ', right: 'alpha'),
      );
      expect(preserved.equal, isFalse);

      final trimmed = comparator.compare(
        const ListCompareRequest(
          left: ' alpha \n\tbeta',
          right: 'alpha\nbeta ',
          whitespaceMode: 'trim',
        ),
      );
      expect(trimmed.intersection, [' alpha ', '\tbeta']);
      expect(trimmed.equal, isTrue);
    });

    test(
      'GivenPreservedDuplicates_WhenCompared_ThenOccurrencesMatchAsAMultiset',
      () {
        final result = comparator.compare(
          const ListCompareRequest(left: 'a\na\na\nb', right: 'a\na\nb\nb'),
        );

        expect(result.intersection, ['a', 'a', 'b']);
        expect(result.leftOnly, ['a']);
        expect(result.rightOnly, ['b']);
      },
    );

    test(
      'GivenDistinctDuplicates_WhenCompared_ThenFirstNormalizedOccurrenceWins',
      () {
        final result = comparator.compare(
          const ListCompareRequest(
            left: ' Alpha \nalpha\nleft\nLEFT',
            right: 'ALPHA\n right \nRIGHT',
            caseMode: 'insensitive',
            whitespaceMode: 'trim',
            duplicateMode: 'distinct',
          ),
        );

        expect(result.intersection, [' Alpha ']);
        expect(result.leftOnly, ['left']);
        expect(result.rightOnly, [' right ']);
      },
    );

    test(
      'GivenEveryOptionCombination_WhenCompared_ThenSelectedModesAreReported',
      () {
        for (final caseMode in ['sensitive', 'insensitive']) {
          for (final whitespaceMode in ['preserve', 'trim']) {
            for (final duplicateMode in ['preserve', 'distinct']) {
              final result = comparator.compare(
                ListCompareRequest(
                  left: 'A\n A ',
                  right: 'a\na',
                  caseMode: caseMode,
                  whitespaceMode: whitespaceMode,
                  duplicateMode: duplicateMode,
                ),
              );
              expect(result.caseMode, caseMode);
              expect(result.whitespaceMode, whitespaceMode);
              expect(result.duplicateMode, duplicateMode);
            }
          }
        }
      },
    );

    test(
      'GivenInvalidOptions_WhenCompared_ThenFirstTypedOptionFailureIsReturned',
      () {
        for (final entry in <String, ListCompareRequest>{
          'caseMode': const ListCompareRequest(
            left: '',
            right: '',
            caseMode: 'fold',
          ),
          'whitespaceMode': const ListCompareRequest(
            left: '',
            right: '',
            whitespaceMode: 'collapse',
          ),
          'duplicateMode': const ListCompareRequest(
            left: '',
            right: '',
            duplicateMode: 'count',
          ),
        }.entries) {
          expect(
            () => comparator.compare(entry.value),
            _listCompareFailure(
              kind: ListCompareFailureKind.validation,
              code: 'list-compare.invalid-option',
              field: entry.key,
              reason: 'unsupported-option',
            ),
          );
        }
      },
    );

    test(
      'GivenCharacterBudget_WhenAtOrBeyondBoundary_ThenOversizeInputIsRejected',
      () {
        final exact = const ListComparator(maxInputCharacters: 4)
            .compare(const ListCompareRequest(left: 'ab', right: 'cd'));
        expect(exact.leftOnly, ['ab']);

        expect(
          () =>
              const ListComparator(maxInputCharacters: 3)
                  .compare(const ListCompareRequest(left: 'ab', right: 'cd')),
          _listCompareFailure(
            kind: ListCompareFailureKind.resource,
            code: 'list-compare.resource-limit',
            field: 'input',
            reason: 'character-limit',
          ),
        );
      },
    );

    test(
      'GivenItemBudget_WhenAtOrBeyondBoundary_ThenOversizeInputIsRejected',
      () {
        final exact = const ListComparator(maxInputItems: 4)
            .compare(const ListCompareRequest(left: 'a\nb', right: 'a\nc'));
        expect(exact.intersection, ['a']);

        expect(
          () => const ListComparator(maxInputItems: 3)
              .compare(const ListCompareRequest(left: 'a\nb', right: 'a\nc')),
          _listCompareFailure(
            kind: ListCompareFailureKind.resource,
            code: 'list-compare.resource-limit',
            field: 'input',
            reason: 'item-limit',
          ),
        );
      },
    );

    test(
      'GivenResultBudget_WhenAtOrBeyondBoundary_ThenNoPartialSetsAreReturned',
      () {
        final exact = const ListComparator(maxResultItems: 3)
            .compare(const ListCompareRequest(left: 'a\nb', right: 'a\nc'));
        expect(exact.intersection, ['a']);

        expect(
          () => const ListComparator(maxResultItems: 2)
              .compare(const ListCompareRequest(left: 'a\nb', right: 'a\nc')),
          _listCompareFailure(
            kind: ListCompareFailureKind.resource,
            code: 'list-compare.resource-limit',
            field: 'result',
            reason: 'result-limit',
          ),
        );
      },
    );
  });
}

Matcher _listCompareFailure({
  required ListCompareFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<ListCompareException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
