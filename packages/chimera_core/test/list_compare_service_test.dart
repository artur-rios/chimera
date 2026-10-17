import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenListsAndOptions_WhenCompareServiceExecutes_ThenStableJsonReturns',
    () async {
      final result = await const ListCompareService().execute(
        const ListCompareOperationRequest(
          left: ' Alpha \nleft\nalpha',
          right: 'alpha\nright\nALPHA',
          caseMode: 'insensitive',
          whitespaceMode: 'trim',
          duplicateMode: 'distinct',
        ),
      );

      result.fold(
        onSuccess: (value) {
          expect(value.leftOnly, ['left']);
          expect(value.rightOnly, ['right']);
          expect(value.intersection, [' Alpha ']);
          expect(value.equal, isFalse);
          expect(value.toJson(), <String, Object?>{
            'leftOnly': ['left'],
            'rightOnly': ['right'],
            'intersection': [' Alpha '],
            'equal': false,
            'options': <String, Object?>{
              'case': 'insensitive',
              'whitespace': 'trim',
              'duplicates': 'distinct',
            },
          });
        },
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test('GivenInvalidOption_WhenCompareServiceExecutes_ThenRedactedValidationReturns', () async {
    final result = await const ListCompareService().execute(
      const ListCompareOperationRequest(
        left: 'left-secret',
        right: 'right-secret',
        duplicateMode: 'unsupported-secret',
      ),
    );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'list-compare.invalid-option');
        expect(failure.messageKey, 'error.listCompare.validation');
        expect(failure.details, <String, Object?>{
          'field': 'duplicateMode',
          'reason': 'unsupported-option',
        });
        final safe = failure.details.toString();
        expect(safe, isNot(contains('left-secret')));
        expect(safe, isNot(contains('right-secret')));
        expect(safe, isNot(contains('unsupported-secret')));
      },
    );
  });

  test(
    'GivenResourceLimit_WhenCompareServiceExecutes_ThenTypedResourceReturns',
    () async {
      final result = await const ListCompareService(
        comparator: ListComparator(maxResultItems: 1),
      ).execute(const ListCompareOperationRequest(left: 'one\ntwo', right: ''));

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'list-compare.resource-limit');
          expect(failure.messageKey, 'error.listCompare.resource');
          expect(failure.details, <String, Object?>{
            'field': 'result',
            'reason': 'result-limit',
          });
        },
      );
    },
  );
}
