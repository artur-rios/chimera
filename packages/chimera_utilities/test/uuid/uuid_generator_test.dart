import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenVersion4_WhenGenerated_ThenRfcVersionAndVariantBitsAreSet', () {
    final result = _generator(bytes: List<int>.filled(16, 0))
        .generate(const UuidGenerationRequest(version: UuidVersion.v4));

    expect(result.values, ['00000000-0000-4000-8000-000000000000']);
    expect(result.version, UuidVersion.v4);
  });

  test('GivenVersion7_WhenGenerated_ThenTimestampVersionAndVariantAreSet', () {
    final result = _generator(
      bytes: List<int>.filled(16, 0),
      milliseconds: 0x0123456789ab,
    ).generate(const UuidGenerationRequest(version: UuidVersion.v7));

    expect(result.values, ['01234567-89ab-7000-8000-000000000000']);
    expect(result.version, UuidVersion.v7);
  });

  test(
    'GivenGuidRepresentation_WhenGenerated_ThenBracedUppercaseTextReturns',
    () {
      final result = _generator(bytes: List<int>.filled(16, 0xab)).generate(
        const UuidGenerationRequest(
          version: UuidVersion.v4,
          representation: UuidRepresentation.guid,
        ),
      );

      expect(result.values, ['{ABABABAB-ABAB-4BAB-ABAB-ABABABABABAB}']);
      expect(result.representation, UuidRepresentation.guid);
    },
  );

  test('GivenCountThree_WhenGenerated_ThenExactUniqueBatchReturns', () {
    var call = 0;
    final generator = UuidGenerator.forTesting(
      randomBytes: () => List<int>.filled(16, call++),
      nowMilliseconds: () => 0,
    );

    final result = generator.generate(
      const UuidGenerationRequest(version: UuidVersion.v4, count: 3),
    );

    expect(result.values, hasLength(3));
    expect(result.values.toSet(), hasLength(3));
    expect(call, 3);
  });

  for (final count in [0, -1]) {
    test(
      'GivenInvalidCount${count}_WhenGenerated_ThenValidationPrecedesDependencies',
      () {
        var randomCalls = 0;
        var clockCalls = 0;
        final generator = UuidGenerator.forTesting(
          randomBytes: () {
            randomCalls++;
            return List<int>.filled(16, 0);
          },
          nowMilliseconds: () {
            clockCalls++;
            return 0;
          },
        );

        expect(
          () => generator.generate(UuidGenerationRequest(count: count)),
          throwsA(
            isA<UuidGenerationException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  UuidGenerationFailureKind.validation,
                )
                .having((error) => error.code, 'code', 'uuid.invalid-count'),
          ),
        );
        expect(randomCalls, 0);
        expect(clockCalls, 0);
      },
    );
  }

  test(
    'GivenCountAboveArbitraryCeiling_WhenGenerated_ThenExactBatchReturns',
    () {
      var call = 0;
      final generator = UuidGenerator.forTesting(
        randomBytes: () {
          var value = call++;
          return List<int>.generate(16, (_) {
            final byte = value % 256;
            value ~/= 256;
            return byte;
          }, growable: false);
        },
        nowMilliseconds: () => 0,
      );

      final result = generator.generate(
        const UuidGenerationRequest(count: 1001),
      );

      expect(result.values, hasLength(1001));
      expect(result.values.toSet(), hasLength(1001));
    },
  );

  test(
    'GivenEntropyFailureMidBatch_WhenGenerated_ThenNoPartialResultReturns',
    () {
      var call = 0;
      final generator = UuidGenerator.forTesting(
        randomBytes: () {
          if (call++ == 1) {
            throw StateError('PRIVATE IDENTIFIER');
          }
          return List<int>.filled(16, 0);
        },
        nowMilliseconds: () => 0,
      );

      expect(
        () => generator.generate(const UuidGenerationRequest(count: 3)),
        throwsA(
          isA<UuidGenerationException>()
              .having(
                (error) => error.kind,
                'kind',
                UuidGenerationFailureKind.processing,
              )
              .having((error) => error.code, 'code', 'uuid.random-unavailable')
              .having(
                (error) => error.toString(),
                'diagnostic',
                isNot(contains('PRIVATE')),
              ),
        ),
      );
    },
  );

  for (final bytes in <List<int>>[
    List<int>.filled(15, 0),
    [...List<int>.filled(15, 0), -1],
    [...List<int>.filled(15, 0), 256],
  ]) {
    test('GivenInvalidEntropy${bytes}_WhenGenerated_ThenProcessingFailure', () {
      expect(
        () => _generator(bytes: bytes).generate(const UuidGenerationRequest()),
        throwsA(
          isA<UuidGenerationException>()
              .having(
                (error) => error.kind,
                'kind',
                UuidGenerationFailureKind.processing,
              )
              .having((error) => error.code, 'code', 'uuid.random-unavailable'),
        ),
      );
    });
  }

  for (final milliseconds in [-1, 0x1000000000000]) {
    test(
      'GivenInvalidTime${milliseconds}_WhenGenerated_ThenProcessingFailure',
      () {
        expect(
          () => _generator(
            bytes: List<int>.filled(16, 0),
            milliseconds: milliseconds,
          ).generate(const UuidGenerationRequest(version: UuidVersion.v7)),
          throwsA(
            isA<UuidGenerationException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  UuidGenerationFailureKind.processing,
                )
                .having((error) => error.code, 'code', 'uuid.time-unavailable'),
          ),
        );
      },
    );
  }

  test('GivenClockFailure_WhenGenerated_ThenRedactedProcessingFailure', () {
    final generator = UuidGenerator.forTesting(
      randomBytes: () => List<int>.filled(16, 0),
      nowMilliseconds: () => throw StateError('PRIVATE TIME'),
    );

    expect(
      () => generator.generate(
        const UuidGenerationRequest(version: UuidVersion.v7),
      ),
      throwsA(
        isA<UuidGenerationException>()
            .having((error) => error.code, 'code', 'uuid.time-unavailable')
            .having(
              (error) => error.toString(),
              'diagnostic',
              isNot(contains('PRIVATE')),
            ),
      ),
    );
  });

  test('GivenAllocationFailure_WhenGenerated_ThenResourceFailureReturns', () {
    final generator = UuidGenerator.forTesting(
      randomBytes: () => List<int>.filled(16, 0),
      nowMilliseconds: () => 0,
      allocate: (_) => throw OutOfMemoryError(),
    );

    expect(
      () => generator.generate(const UuidGenerationRequest()),
      throwsA(
        isA<UuidGenerationException>()
            .having(
              (error) => error.kind,
              'kind',
              UuidGenerationFailureKind.resource,
            )
            .having((error) => error.code, 'code', 'uuid.resource-limit'),
      ),
    );
  });
}

UuidGenerator _generator({required List<int> bytes, int milliseconds = 0}) {
  return UuidGenerator.forTesting(
    randomBytes: () => List<int>.of(bytes),
    nowMilliseconds: () => milliseconds,
  );
}
