import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenDefaults_WhenExecuted_ThenStableJsonWithoutRetainedRequest',
    () async {
      final result = await PasswordService(
        generator: PasswordGenerator.forTesting(randomInt: (_) => 0),
      ).execute(const PasswordOperationRequest());

      final output = (result as ChimeraSuccess<PasswordOutput>).value;
      expect(output.toJson(), {
        'length': 16,
        'characterClasses': ['lowercase', 'uppercase', 'digits', 'symbols'],
        'password': output.password,
      });
      expect(output.password, hasLength(16));
    },
  );

  for (final length in [
    '',
    '0',
    '-1',
    '+4',
    ' 4',
    '4.0',
    '1e2',
    '4\n',
    '999999999999999999999999999999999',
  ]) {
    test(
      'GivenInvalidLength${length}_WhenExecuted_ThenTypedValidation',
      () async {
        var draws = 0;
        final result = await PasswordService(
          generator: PasswordGenerator.forTesting(
            randomInt: (_) {
              draws++;
              return 0;
            },
          ),
        ).execute(PasswordOperationRequest(length: length));

        final failure = result as ChimeraFailure<PasswordOutput>;
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'password.invalid-length');
        expect(failure.details, {
          'field': 'length',
          'reason': 'positive-decimal-integer-required',
        });
        expect(draws, 0);
      },
    );
  }

  test(
    'GivenImpossibleClassSelection_WhenExecuted_ThenTypedValidation',
    () async {
      final result =
          await PasswordService(
            generator: PasswordGenerator.forTesting(randomInt: (_) => 0),
          ).execute(
            const PasswordOperationRequest(
              length: '3',
              lowercase: true,
              uppercase: true,
              digits: true,
              symbols: true,
            ),
          );

      final failure = result as ChimeraFailure<PasswordOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, 'password.impossible-constraints');
      expect(failure.details.toString(), isNot(contains('password')));
    },
  );

  test(
    'GivenEntropyFailure_WhenExecuted_ThenRedactedProcessingFailure',
    () async {
      final result = await PasswordService(
        generator: PasswordGenerator.forTesting(
          randomInt: (_) => throw StateError('PRIVATE PASSWORD MATERIAL'),
        ),
      ).execute(const PasswordOperationRequest());

      final failure = result as ChimeraFailure<PasswordOutput>;
      expect(failure.kind, FailureKind.processing);
      expect(failure.code, 'password.random-unavailable');
      expect(failure.messageKey, 'error.password.processing');
      expect(failure.toString(), isNot(contains('PRIVATE')));
    },
  );
}
