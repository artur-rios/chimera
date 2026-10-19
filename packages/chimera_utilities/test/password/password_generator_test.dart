import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenDefaults_WhenGenerated_ThenEveryRequestedClassIsPresent', () {
    final generator = PasswordGenerator.forTesting(randomInt: (_) => 0);

    final result = generator.generate(const PasswordRequest());

    expect(result.password, hasLength(16));
    expect(result.password, matches(RegExp('[a-z]')));
    expect(result.password, matches(RegExp('[A-Z]')));
    expect(result.password, matches(RegExp('[0-9]')));
    expect(result.password, matches(RegExp(r'[!@#$%^&*()\-_=+\[\]{}:,.?]')));
    expect(result.characterClasses, [
      'lowercase',
      'uppercase',
      'digits',
      'symbols',
    ]);
  });

  for (final entry in <String, PasswordRequest>{
    'lowercase': const PasswordRequest(
      length: 8,
      uppercase: false,
      digits: false,
      symbols: false,
    ),
    'uppercase': const PasswordRequest(
      length: 8,
      lowercase: false,
      digits: false,
      symbols: false,
    ),
    'digits': const PasswordRequest(
      length: 8,
      lowercase: false,
      uppercase: false,
      symbols: false,
    ),
    'symbols': const PasswordRequest(
      length: 8,
      lowercase: false,
      uppercase: false,
      digits: false,
    ),
  }.entries) {
    test('GivenOnly${entry.key}_WhenGenerated_ThenUsesOnlyThatClass', () {
      final result = PasswordGenerator.forTesting(randomInt: (_) => 0)
          .generate(entry.value);

      final allowed = switch (entry.key) {
        'lowercase' => RegExp(r'^[a-z]+$'),
        'uppercase' => RegExp(r'^[A-Z]+$'),
        'digits' => RegExp(r'^[0-9]+$'),
        _ => RegExp(r'^[!@#$%^&*()\-_=+\[\]{}:,.?]+$'),
      };
      expect(result.password, matches(allowed));
      expect(result.characterClasses, [entry.key]);
    });
  }

  test('GivenMinimumFeasibleLength_WhenGenerated_ThenEachClassAppearsOnce', () {
    var call = 0;
    final generator = PasswordGenerator.forTesting(
      randomInt: (upperBound) => call++ % upperBound,
    );

    final result = generator.generate(const PasswordRequest(length: 4));

    expect(result.password, hasLength(4));
    expect(result.password, matches(RegExp('[a-z]')));
    expect(result.password, matches(RegExp('[A-Z]')));
    expect(result.password, matches(RegExp('[0-9]')));
    expect(result.password, matches(RegExp(r'[!@#$%^&*()\-_=+\[\]{}:,.?]')));
  });

  test(
    'GivenDeterministicEntropy_WhenGenerated_ThenSelectionAndShuffleAreStable',
    () {
      final draws = <int>[1, 2, 3, 4, 5, 6, 1, 0, 2, 1, 0];
      var index = 0;
      final generator = PasswordGenerator.forTesting(
        randomInt: (upperBound) => draws[index++ % draws.length] % upperBound,
      );

      final first = generator.generate(const PasswordRequest(length: 7));
      index = 0;
      final second = generator.generate(const PasswordRequest(length: 7));

      expect(second.password, first.password);
      expect(index, greaterThan(7));
    },
  );

  for (final entry in <String, PasswordRequest>{
    'ZeroLength': const PasswordRequest(length: 0),
    'NegativeLength': const PasswordRequest(length: -1),
    'NoCharacterClasses': const PasswordRequest(
      lowercase: false,
      uppercase: false,
      digits: false,
      symbols: false,
    ),
    'LengthBelowClassCount': const PasswordRequest(length: 3),
  }.entries) {
    test('Given${entry.key}_WhenGenerated_ThenValidationPrecedesEntropy', () {
      var draws = 0;
      final generator = PasswordGenerator.forTesting(
        randomInt: (_) {
          draws++;
          return 0;
        },
      );

      expect(
        () => generator.generate(entry.value),
        throwsA(
          isA<PasswordException>().having(
            (error) => error.kind,
            'kind',
            PasswordFailureKind.validation,
          ),
        ),
      );
      expect(draws, 0);
    });
  }

  test('GivenEntropyFailure_WhenGenerated_ThenRedactedProcessingFailure', () {
    final generator = PasswordGenerator.forTesting(
      randomInt: (_) => throw StateError('PRIVATE PASSWORD MATERIAL'),
    );

    expect(
      () => generator.generate(const PasswordRequest()),
      throwsA(
        isA<PasswordException>()
            .having(
              (error) => error.kind,
              'kind',
              PasswordFailureKind.processing,
            )
            .having(
              (error) => error.code,
              'code',
              'password.random-unavailable',
            )
            .having(
              (error) => error.toString(),
              'diagnostic',
              isNot(contains('PRIVATE')),
            ),
      ),
    );
  });

  for (final value in [-1, 999]) {
    test(
      'GivenOutOfRangeEntropy${value}_WhenGenerated_ThenProcessingFailure',
      () {
        final generator = PasswordGenerator.forTesting(randomInt: (_) => value);

        expect(
          () => generator.generate(const PasswordRequest()),
          throwsA(
            isA<PasswordException>().having(
              (error) => error.kind,
              'kind',
              PasswordFailureKind.processing,
            ),
          ),
        );
      },
    );
  }
}
