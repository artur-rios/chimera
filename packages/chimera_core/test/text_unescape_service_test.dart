import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenSupportedMode_WhenUnescapeServiceExecutes_ThenStableOutputReturns',
    () async {
      final result = await const TextUnescapeService().execute(
        const TextUnescapeOperationRequest(
          input: 'A%20z%2F%C3%A9',
          mode: 'url',
        ),
      );

      result.fold(
        onSuccess: (value) {
          expect(value.unescaped, 'A z/é');
          expect(value.mode, 'url');
          expect(value.toJson(), <String, Object?>{
            'unescaped': 'A z/é',
            'mode': 'url',
          });
        },
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test(
    'GivenMalformedInput_WhenUnescapeServiceExecutes_ThenSafeDetailsReturn',
    () async {
      final result = await const TextUnescapeService().execute(
        const TextUnescapeOperationRequest(input: r'sensitive\q', mode: 'json'),
      );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.validation);
          expect(failure.code, 'text-unescape.malformed-input');
          expect(failure.messageKey, 'error.textUnescape.validation');
          expect(failure.details, <String, Object?>{
            'field': 'input',
            'reason': 'unknown-escape',
            'offset': 9,
          });
          expect(failure.details.toString(), isNot(contains('sensitive')));
        },
      );
    },
  );

  test(
    'GivenOutputBudget_WhenUnescapeServiceExecutes_ThenResourceFailureReturns',
    () async {
      final result =
          await const TextUnescapeService(
            unescaper: TextUnescaper(maxOutputCharacters: 1),
          ).execute(
            const TextUnescapeOperationRequest(
              input: r'\u0041B',
              mode: 'unicode',
            ),
          );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'text-unescape.resource-limit');
          expect(failure.messageKey, 'error.textUnescape.resource');
          expect(failure.details, <String, Object?>{
            'field': 'unescaped',
            'reason': 'output-limit',
          });
        },
      );
    },
  );
}
