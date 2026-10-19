import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenDefaults_WhenExecuted_ThenStableJson', () async {
    final result = await const LoremService().execute(
      const LoremOperationRequest(),
    );
    expect((result as ChimeraSuccess<LoremOutput>).value.toJson(), {
      'unit': 'paragraphs',
      'count': 1,
      'text': 'Lorem ipsum dolor sit amet. Consectetur adipiscing elit.',
    });
  });
  for (final count in [
    '0',
    '-1',
    '+1',
    ' 1',
    '1.0',
    '',
    '1e2',
    '1\n',
    '999999999999999999999999999999999',
  ]) {
    test(
      'GivenInvalidCount${count}_WhenExecuted_ThenTypedRedactedFailure',
      () async {
        final result = await const LoremService().execute(
          LoremOperationRequest(count: count),
        );
        final failure = result as ChimeraFailure<LoremOutput>;
        expect(failure.kind, FailureKind.validation);
        expect(failure.details, {
          'field': 'count',
          'reason': 'positive-integer-required',
        });
      },
    );
  }
  test('GivenInvalidUnit_WhenExecuted_ThenValidation', () async {
    final failure = await const LoremService().execute(
      const LoremOperationRequest(unit: 'private'),
    ) as ChimeraFailure<LoremOutput>;
    expect(failure.code, 'lorem.invalid-unit');
    expect(failure.details.toString(), isNot(contains('private')));
  });
  for (final raw in ['0001', '9007199254740993', '9223372036854775807']) {
    test(
      'Given${raw}NativeExactCount_WhenAllocatedThroughSeam_ThenNoUnnecessaryWebCap',
      () async {
        int? observed;
        final service = LoremService(
          generator: LoremGenerator.forTesting(
            allocate: (request) {
              observed = request.count;
              return 'test-only';
            },
          ),
        );
        final result = await service.execute(LoremOperationRequest(count: raw));
        expect(result, isA<ChimeraSuccess<LoremOutput>>());
        expect(observed, int.parse(raw));
      },
    );
  }
  test('GivenResourceBudget_WhenExecuted_ThenNoPartialOutput', () async {
    final result = await const LoremService(
      generator: LoremGenerator(maxOutputCharacters: 1),
    ).execute(const LoremOperationRequest());
    expect((result as ChimeraFailure<LoremOutput>).kind, FailureKind.resource);
  });
}
