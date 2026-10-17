import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenSupportedMode_WhenServiceExecutes_ThenStableOutputIsReturned',
    () async {
      final result = await const TextEscapeService().execute(
        const TextEscapeOperationRequest(input: 'A z/é', mode: 'url'),
      );

      result.fold(
        onSuccess: (value) {
          expect(value.escaped, 'A%20z%2F%C3%A9');
          expect(value.mode, 'url');
          expect(value.toJson(), <String, Object?>{
            'escaped': 'A%20z%2F%C3%A9',
            'mode': 'url',
          });
        },
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test(
    'GivenInvalidMode_WhenServiceExecutes_ThenSafeValidationDetailsReturn',
    () async {
      final result = await const TextEscapeService().execute(
        const TextEscapeOperationRequest(input: 'sensitive-text', mode: 'bad'),
      );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.validation);
          expect(failure.code, 'text-escape.invalid-mode');
          expect(failure.messageKey, 'error.textEscape.validation');
          expect(failure.details, <String, Object?>{
            'field': 'mode',
            'reason': 'unsupported-mode',
          });
          expect(failure.details.toString(), isNot(contains('sensitive-text')));
        },
      );
    },
  );

  test(
    'GivenOutputBudget_WhenServiceExecutes_ThenResourceFailureReturns',
    () async {
      final result = await const TextEscapeService(
        escaper: TextEscaper(maxOutputCharacters: 4),
      ).execute(const TextEscapeOperationRequest(input: '&', mode: 'html'));

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'text-escape.resource-limit');
          expect(failure.messageKey, 'error.textEscape.resource');
          expect(failure.details, <String, Object?>{
            'field': 'escaped',
            'reason': 'output-limit',
          });
        },
      );
    },
  );
}
