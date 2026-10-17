import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenSupportedGranularity_WhenCompareServiceExecutes_ThenStableJsonReturns', () async {
    final result = await const TextCompareService().execute(
      const TextCompareOperationRequest(
        left: 'Hello world',
        right: 'Hello brave world',
        granularity: 'word',
      ),
    );

    result.fold(
      onSuccess: (value) {
        expect(value.granularity, 'word');
        expect(value.summary.added, 2);
        expect(value.toJson(), <String, Object?>{
          'granularity': 'word',
          'spans': <Map<String, Object?>>[
            <String, Object?>{
              'kind': 'unchanged',
              'text': 'Hello ',
              'tokenCount': 2,
            },
            <String, Object?>{
              'kind': 'added',
              'text': 'brave ',
              'tokenCount': 2,
            },
            <String, Object?>{
              'kind': 'unchanged',
              'text': 'world',
              'tokenCount': 1,
            },
          ],
          'summary': <String, Object?>{
            'added': 2,
            'removed': 0,
            'unchanged': 3,
          },
        });
      },
      onFailure: (failure) => fail(failure.code),
    );
  });

  test('GivenInvalidGranularity_WhenCompareServiceExecutes_ThenRedactedValidationReturns', () async {
    final result = await const TextCompareService().execute(
      const TextCompareOperationRequest(
        left: 'sensitive-left',
        right: 'sensitive-right',
        granularity: 'sentence',
      ),
    );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'text-compare.invalid-granularity');
        expect(failure.messageKey, 'error.textCompare.validation');
        expect(failure.details, <String, Object?>{
          'field': 'granularity',
          'reason': 'unsupported-granularity',
        });
        expect(failure.details.toString(), isNot(contains('sensitive')));
      },
    );
  });

  test(
    'GivenResourceBudget_WhenCompareServiceExecutes_ThenNoPartialSpansReturn',
    () async {
      final result =
          await const TextCompareService(
            comparer: TextComparer(maxWorkUnits: 0),
          ).execute(
            const TextCompareOperationRequest(
              left: 'sensitive-left',
              right: 'sensitive-right',
              granularity: 'character',
            ),
          );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'text-compare.resource-limit');
          expect(failure.messageKey, 'error.textCompare.resource');
          expect(failure.details, <String, Object?>{
            'field': 'work',
            'reason': 'work-limit',
          });
          expect(failure.details.keys, isNot(contains('spans')));
          expect(failure.details.toString(), isNot(contains('sensitive')));
        },
      );
    },
  );
}
