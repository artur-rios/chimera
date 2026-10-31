import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenDefaults_WhenExecuted_ThenStableLabeledJsonReturns', () async {
    final result = await CardService(generator: _generator())
        .execute(const CardOperationRequest());

    final output = (result as ChimeraSuccess<CardOutput>).value;
    expect(output.toJson(), {
      'network': 'visa',
      'count': 1,
      'synthetic': true,
      'label': 'synthetic-test-data',
      'values': ['4242424242424242'],
    });
  });

  for (final entry in <String, CardOperationRequest>{
    'Network': const CardOperationRequest(network: 'diners-club'),
    'EmptyCount': const CardOperationRequest(count: ''),
    'ZeroCount': const CardOperationRequest(count: '0'),
    'SignedCount': const CardOperationRequest(count: '+1'),
    'WhitespaceCount': const CardOperationRequest(count: ' 1'),
    'DecimalCount': const CardOperationRequest(count: '1.0'),
  }.entries) {
    test('GivenInvalid${entry.key}_WhenExecuted_ThenTypedValidation', () async {
      var candidateCalls = 0;
      final result = await CardService(
        generator: CardGenerator.forTesting(
          candidate: (_) {
            candidateCalls++;
            return '4242424242424242';
          },
        ),
      ).execute(entry.value);

      final failure = result as ChimeraFailure<CardOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, startsWith('card.invalid-'));
      expect(failure.messageKey, 'error.card.validation');
      expect(candidateCalls, 0);
    });
  }

  for (final entry in <String, String>{
    'visa': '4242424242424242',
    'mastercard': '5555555555554444',
    'amex': '378282246310005',
    'discover': '6011111111111117',
  }.entries) {
    test(
      'Given${entry.key}_WhenExecuted_ThenRequestedNetworkReturns',
      () async {
        final result = await CardService(
          generator: CardGenerator.forTesting(candidate: (_) => entry.value),
        ).execute(CardOperationRequest(network: entry.key, count: '2'));

        final output = (result as ChimeraSuccess<CardOutput>).value;
        expect(output.network, entry.key);
        expect(output.values, [entry.value, entry.value]);
        expect(output.synthetic, isTrue);
      },
    );
  }

  test(
    'GivenCountAboveArbitraryCeiling_WhenExecuted_ThenExactBatchReturns',
    () async {
      final result = await CardService(generator: _generator())
          .execute(const CardOperationRequest(count: '1001'));

      final output = (result as ChimeraSuccess<CardOutput>).value;
      expect(output.count, 1001);
    },
  );

  test(
    'GivenCandidateFailure_WhenExecuted_ThenRedactedProcessingFailure',
    () async {
      final result = await CardService(
        generator: CardGenerator.forTesting(
          candidate: (_) => throw StateError('PRIVATE PAN'),
        ),
      ).execute(const CardOperationRequest());

      final failure = result as ChimeraFailure<CardOutput>;
      expect(failure.kind, FailureKind.processing);
      expect(failure.code, 'card.source-unavailable');
      expect(failure.messageKey, 'error.card.processing');
      expect(failure.toString(), isNot(contains('PRIVATE')));
    },
  );

  test('GivenResourceFailure_WhenExecuted_ThenTypedResourceFailure', () async {
    final result = await CardService(
      generator: CardGenerator.forTesting(
        candidate: (_) => '4242424242424242',
        allocate: (_) => throw OutOfMemoryError(),
      ),
    ).execute(const CardOperationRequest());

    final failure = result as ChimeraFailure<CardOutput>;
    expect(failure.kind, FailureKind.resource);
    expect(failure.code, 'card.resource-limit');
    expect(failure.messageKey, 'error.card.resource');
  });
}

CardGenerator _generator() =>
    CardGenerator.forTesting(candidate: (_) => '4242424242424242');
