import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenSupportedMode_WhenTransformServiceExecutes_ThenStableJsonReturns',
    () async {
      final result = await const TextTransformService().execute(
        const TextTransformOperationRequest(
          input: 'b\r\na\rb\n',
          mode: 'deduplicate-lines',
        ),
      );

      result.fold(
        onSuccess: (value) {
          expect(value.mode, 'deduplicate-lines');
          expect(value.output, 'b\na\n');
          expect(value.toJson(), <String, Object?>{
            'mode': 'deduplicate-lines',
            'output': 'b\na\n',
          });
        },
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test('GivenInvalidMode_WhenTransformServiceExecutes_ThenRedactedValidationReturns', () async {
    final result = await const TextTransformService().execute(
      const TextTransformOperationRequest(
        input: 'sensitive-input',
        mode: 'title-case',
      ),
    );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'text-transform.invalid-mode');
        expect(failure.messageKey, 'error.textTransform.validation');
        expect(failure.details, <String, Object?>{
          'field': 'mode',
          'reason': 'unsupported-mode',
        });
        expect(failure.details.toString(), isNot(contains('sensitive-input')));
      },
    );
  });

  test(
    'GivenOutputBudget_WhenTransformServiceExecutes_ThenNoPartialOutputReturns',
    () async {
      final result =
          await const TextTransformService(
            transformer: TextTransformer(maxOutputCodeUnits: 1),
          ).execute(
            const TextTransformOperationRequest(input: 'ß', mode: 'uppercase'),
          );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'text-transform.resource-limit');
          expect(failure.messageKey, 'error.textTransform.resource');
          expect(failure.details, <String, Object?>{
            'field': 'output',
            'reason': 'character-limit',
          });
          expect(failure.details.keys, isNot(contains('output')));
        },
      );
    },
  );
}
