import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenArbitraryPrecisionValue_WhenServiceExecutes_ThenStableOutputIsReturned', () async {
    final result = await const NumberBaseService().execute(
      const NumberBaseOperationRequest(
        value: '184467440737095516160',
        sourceBase: 10,
        targetBase: 16,
      ),
    );

    result.fold(
      onSuccess: (value) {
        expect(value.converted, 'a0000000000000000');
        expect(value.toJson(), <String, Object?>{
          'converted': 'a0000000000000000',
          'sourceBase': 10,
          'targetBase': 16,
        });
      },
      onFailure: (failure) => fail(failure.code),
    );
  });

  test('GivenSurroundingWhitespace_WhenServiceExecutes_ThenCanonicalOutputIsReturned', () async {
    final result = await const NumberBaseService().execute(
      const NumberBaseOperationRequest(
        value: '  +00FF\n',
        sourceBase: 16,
        targetBase: 10,
      ),
    );

    result.fold(
      onSuccess: (value) => expect(value.converted, '255'),
      onFailure: (failure) => fail(failure.code),
    );
  });

  test('GivenInvalidDigit_WhenServiceExecutes_ThenSafeValidationDetailsAreReturned', () async {
    final result = await const NumberBaseService().execute(
      const NumberBaseOperationRequest(
        value: 'secret-Z',
        sourceBase: 10,
        targetBase: 2,
      ),
    );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'number-base.invalid-value');
        expect(failure.messageKey, 'error.numberBase.validation');
        expect(failure.details, <String, Object?>{
          'field': 'value',
          'reason': 'invalid-digit',
        });
        expect(failure.details.toString(), isNot(contains('secret')));
      },
    );
  });

  test('GivenOutputExpansionExceedsBudget_WhenServiceExecutes_ThenResourceFailureIsReturned', () async {
    final result =
        await const NumberBaseService(
          converter: NumberBaseConverter(maxOutputCharacters: 3),
        ).execute(
          const NumberBaseOperationRequest(
            value: 'zz',
            sourceBase: 36,
            targetBase: 2,
          ),
        );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.resource);
        expect(failure.code, 'number-base.resource-limit');
        expect(failure.messageKey, 'error.numberBase.resource');
        expect(failure.details, <String, Object?>{
          'field': 'converted',
          'reason': 'output-limit',
        });
      },
    );
  });
}
