import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenDefaults_WhenExecuted_ThenStableJsonReturns', () async {
    final result = await UuidService(generator: _generator())
        .execute(const UuidOperationRequest());

    final output = (result as ChimeraSuccess<UuidOutput>).value;
    expect(output.toJson(), {
      'version': 'v4',
      'representation': 'uuid',
      'count': 1,
      'values': ['00000000-0000-4000-8000-000000000000'],
    });
  });

  for (final entry in <String, UuidOperationRequest>{
    'Version': const UuidOperationRequest(version: 'v1'),
    'Representation': const UuidOperationRequest(representation: 'urn'),
    'EmptyCount': const UuidOperationRequest(count: ''),
    'ZeroCount': const UuidOperationRequest(count: '0'),
    'SignedCount': const UuidOperationRequest(count: '+1'),
    'WhitespaceCount': const UuidOperationRequest(count: ' 1'),
    'DecimalCount': const UuidOperationRequest(count: '1.0'),
  }.entries) {
    test('GivenInvalid${entry.key}_WhenExecuted_ThenTypedValidation', () async {
      var randomCalls = 0;
      var clockCalls = 0;
      final result = await UuidService(
        generator: UuidGenerator.forTesting(
          randomBytes: () {
            randomCalls++;
            return List<int>.filled(16, 0);
          },
          nowMilliseconds: () {
            clockCalls++;
            return 0;
          },
        ),
      ).execute(entry.value);

      final failure = result as ChimeraFailure<UuidOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, startsWith('uuid.invalid-'));
      expect(randomCalls, 0);
      expect(clockCalls, 0);
    });
  }

  test(
    'GivenCountAboveArbitraryCeiling_WhenExecuted_ThenExactBatchReturns',
    () async {
      var call = 0;
      final result = await UuidService(
        generator: UuidGenerator.forTesting(
          randomBytes: () {
            var value = call++;
            return List<int>.generate(16, (_) {
              final byte = value % 256;
              value ~/= 256;
              return byte;
            }, growable: false);
          },
          nowMilliseconds: () => 0,
        ),
      ).execute(const UuidOperationRequest(count: '1001'));

      final output = (result as ChimeraSuccess<UuidOutput>).value;
      expect(output.count, 1001);
      expect(output.values.toSet(), hasLength(1001));
    },
  );

  test('GivenGuidV7_WhenExecuted_ThenRequestedOutputReturns', () async {
    final result = await UuidService(generator: _generator()).execute(
      const UuidOperationRequest(
        version: 'v7',
        representation: 'guid',
        count: '2',
      ),
    );

    final output = (result as ChimeraSuccess<UuidOutput>).value;
    expect(output.version, 'v7');
    expect(output.representation, 'guid');
    expect(output.values, everyElement(matches(RegExp(r'^\{[0-9A-F-]+\}$'))));
    expect(output.values, hasLength(2));
  });

  test(
    'GivenEntropyFailure_WhenExecuted_ThenRedactedProcessingFailure',
    () async {
      final result = await UuidService(
        generator: UuidGenerator.forTesting(
          randomBytes: () => throw StateError('PRIVATE IDENTIFIER'),
          nowMilliseconds: () => 0,
        ),
      ).execute(const UuidOperationRequest());

      final failure = result as ChimeraFailure<UuidOutput>;
      expect(failure.kind, FailureKind.processing);
      expect(failure.code, 'uuid.random-unavailable');
      expect(failure.messageKey, 'error.uuid.processing');
      expect(failure.toString(), isNot(contains('PRIVATE')));
    },
  );

  test('GivenResourceFailure_WhenExecuted_ThenTypedResourceFailure', () async {
    final result = await UuidService(
      generator: UuidGenerator.forTesting(
        randomBytes: () => List<int>.filled(16, 0),
        nowMilliseconds: () => 0,
        allocate: (_) => throw OutOfMemoryError(),
      ),
    ).execute(const UuidOperationRequest());

    final failure = result as ChimeraFailure<UuidOutput>;
    expect(failure.kind, FailureKind.resource);
    expect(failure.code, 'uuid.resource-limit');
    expect(failure.messageKey, 'error.uuid.resource');
  });
}

UuidGenerator _generator() {
  var call = 0;
  return UuidGenerator.forTesting(
    randomBytes: () => List<int>.filled(16, call++),
    nowMilliseconds: () => 0x0123456789ab,
  );
}
