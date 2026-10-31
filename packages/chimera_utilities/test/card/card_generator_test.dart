import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const expectedCatalogue = <CardNetwork, Set<String>>{
    CardNetwork.visa: {
      '4005520201264821',
      '4242424242424242',
      '4000056655665556',
    },
    CardNetwork.mastercard: {
      '5500005555555559',
      '5555555555554444',
      '2223003122003222',
    },
    CardNetwork.americanExpress: {
      '340353278080900',
      '378282246310005',
      '371449635398431',
    },
    CardNetwork.discover: {
      '6011003179988686',
      '6011111111111117',
      '6011000990139424',
    },
  };

  for (final entry in expectedCatalogue.entries) {
    test(
      'Given${entry.key.name}Catalogue_WhenGenerated_ThenOnlyPublishedValidNumbersReturn',
      () {
        var index = 0;
        final values = entry.value.toList(growable: false);
        final result = CardGenerator.forTesting(
          candidate: (_) => values[index++ % values.length],
        ).generate(CardGenerationRequest(network: entry.key, count: 6));

        expect(result.network, entry.key);
        expect(result.synthetic, isTrue);
        expect(result.values, everyElement(isIn(entry.value)));
        expect(result.values, hasLength(6));
        for (final value in result.values) {
          expect(_matchesNetwork(entry.key, value), isTrue);
          expect(_passesLuhn(value), isTrue);
        }
      },
    );
  }

  test('GivenDefaultGenerator_WhenGenerated_ThenValueBelongsToCatalogue', () {
    final result = const CardGenerator().generate(
      const CardGenerationRequest(),
    );

    expect(result.values.single, isIn(expectedCatalogue[CardNetwork.visa]!));
  });

  for (final count in [0, -1]) {
    test(
      'GivenInvalidCount${count}_WhenGenerated_ThenValidationPrecedesCandidateSource',
      () {
        var calls = 0;
        final generator = CardGenerator.forTesting(
          candidate: (_) {
            calls++;
            return '4242424242424242';
          },
        );

        expect(
          () => generator.generate(CardGenerationRequest(count: count)),
          throwsA(
            isA<CardGenerationException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  CardGenerationFailureKind.validation,
                )
                .having((error) => error.code, 'code', 'card.invalid-count'),
          ),
        );
        expect(calls, 0);
      },
    );
  }

  test(
    'GivenCountAboveArbitraryCeiling_WhenGenerated_ThenExactBatchReturns',
    () {
      final result =
          CardGenerator.forTesting(
            candidate: (_) => '4242424242424242',
          ).generate(
            const CardGenerationRequest(network: CardNetwork.visa, count: 1001),
          );

      expect(result.values, hasLength(1001));
    },
  );

  test('GivenRejectedCandidatesThenValid_WhenGenerated_ThenBoundedReplacementSucceeds', () {
    final candidates = <String>[
      '5555555555554444', // valid PAN, wrong requested network
      '4242424242424241', // Visa shape, invalid Luhn
      '4111111111111111', // valid Visa shape/Luhn, outside the safe catalogue
      '4242424242424242',
    ];
    var calls = 0;
    final result = CardGenerator.forTesting(
      candidate: (_) => candidates[calls++],
    ).generate(const CardGenerationRequest());

    expect(result.values, ['4242424242424242']);
    expect(calls, 4);
  });

  test('GivenOnlyRejectedCandidates_WhenGenerated_ThenAtomicProcessingFailureReturns', () {
    var calls = 0;
    final generator = CardGenerator.forTesting(
      candidate: (_) {
        calls++;
        return 'PRIVATE PAN';
      },
    );

    expect(
      () => generator.generate(const CardGenerationRequest(count: 2)),
      throwsA(
        isA<CardGenerationException>()
            .having(
              (error) => error.kind,
              'kind',
              CardGenerationFailureKind.processing,
            )
            .having((error) => error.code, 'code', 'card.generation-failed')
            .having(
              (error) => error.toString(),
              'diagnostic',
              isNot(contains('PRIVATE')),
            ),
      ),
    );
    expect(calls, 32);
  });

  test(
    'GivenCandidateSourceFailure_WhenGenerated_ThenRedactedFailureReturns',
    () {
      final generator = CardGenerator.forTesting(
        candidate: (_) => throw StateError('PRIVATE PAN'),
      );

      expect(
        () => generator.generate(const CardGenerationRequest()),
        throwsA(
          isA<CardGenerationException>()
              .having((error) => error.code, 'code', 'card.source-unavailable')
              .having(
                (error) => error.toString(),
                'diagnostic',
                isNot(contains('PRIVATE')),
              ),
        ),
      );
    },
  );

  test('GivenAllocationFailure_WhenGenerated_ThenResourceFailureReturns', () {
    final generator = CardGenerator.forTesting(
      candidate: (_) => '4242424242424242',
      allocate: (_) => throw OutOfMemoryError(),
    );

    expect(
      () => generator.generate(const CardGenerationRequest()),
      throwsA(
        isA<CardGenerationException>()
            .having(
              (error) => error.kind,
              'kind',
              CardGenerationFailureKind.resource,
            )
            .having((error) => error.code, 'code', 'card.resource-limit'),
      ),
    );
  });

  test('GivenCompletedBatch_WhenCallerMutatesIt_ThenResultIsImmutable', () {
    final result = CardGenerator.forTesting(
      candidate: (_) => '4242424242424242',
    ).generate(const CardGenerationRequest());

    expect(() => result.values.add('4005520201264821'), throwsUnsupportedError);
  });
}

bool _matchesNetwork(CardNetwork network, String value) {
  if (!RegExp(r'^\d+$').hasMatch(value)) return false;
  return switch (network) {
    CardNetwork.visa => value.length == 16 && value.startsWith('4'),
    CardNetwork.mastercard =>
      value.length == 16 &&
          ((int.parse(value.substring(0, 2)) >= 51 &&
                  int.parse(value.substring(0, 2)) <= 55) ||
              (int.parse(value.substring(0, 4)) >= 2221 &&
                  int.parse(value.substring(0, 4)) <= 2720)),
    CardNetwork.americanExpress =>
      value.length == 15 && (value.startsWith('34') || value.startsWith('37')),
    CardNetwork.discover =>
      value.length == 16 &&
          (value.startsWith('6011') ||
              value.startsWith('65') ||
              (int.parse(value.substring(0, 3)) >= 644 &&
                  int.parse(value.substring(0, 3)) <= 649) ||
              (int.parse(value.substring(0, 6)) >= 622126 &&
                  int.parse(value.substring(0, 6)) <= 622925)),
  };
}

bool _passesLuhn(String value) {
  var sum = 0;
  var doubleDigit = false;
  for (var index = value.length - 1; index >= 0; index--) {
    var digit = int.parse(value[index]);
    if (doubleDigit) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
    doubleDigit = !doubleDigit;
  }
  return sum % 10 == 0;
}
