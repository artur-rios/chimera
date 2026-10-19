import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const generator = LoremGenerator();
  test('GivenDefaults_WhenGenerated_ThenKnownParagraph', () {
    final result = generator.generate(const LoremRequest());
    expect(result.unit, 'paragraphs');
    expect(result.count, 1);
    expect(
      result.text,
      'Lorem ipsum dolor sit amet. Consectetur adipiscing elit.',
    );
  });
  for (final count in [1, 2, 17, 10001]) {
    for (final unit in ['words', 'sentences', 'paragraphs']) {
      test('Given$count${unit}_WhenGenerated_ThenExactUnits', () {
        final text = generator
            .generate(LoremRequest(unit: unit, count: count))
            .text;
        final measured = switch (unit) {
          'words' => RegExp(r'\b[A-Za-z]+\b').allMatches(text).length,
          'sentences' => RegExp(r'[A-Z][^.?!]*[.?!]').allMatches(text).length,
          _ => text.split(RegExp(r'\n\s*\n')).length,
        };
        expect(measured, count);
        expect(text, isNot(endsWith('\n')));
      });
    }
  }
  for (final request in [
    const LoremRequest(unit: 'WORDS'),
    const LoremRequest(count: 0),
    const LoremRequest(count: -1),
  ]) {
    test(
      'GivenInvalid${request.unit}${request.count}_WhenGenerated_ThenValidationBeforeAllocation',
      () {
        expect(
          () => const LoremGenerator(maxOutputCharacters: 0).generate(request),
          throwsA(
            isA<LoremException>().having(
              (e) => e.kind,
              'kind',
              LoremFailureKind.validation,
            ),
          ),
        );
      },
    );
  }
  test('GivenExplicitBudget_WhenExceeded_ThenResourceWithoutPartialResult', () {
    expect(
      () =>
          const LoremGenerator(maxOutputCharacters: 3)
              .generate(const LoremRequest()),
      throwsA(
        isA<LoremException>().having(
          (e) => e.kind,
          'kind',
          LoremFailureKind.resource,
        ),
      ),
    );
  });
  test('GivenLargestNativeCount_WhenBudgetRejected_ThenResourceWithoutOverflowOrAllocation', () {
    var allocations = 0;
    final generator = LoremGenerator.forTesting(
      allocate: (_) {
        allocations++;
        return 'unused';
      },
      maxOutputCharacters: 1,
    );
    expect(
      () => generator.generate(const LoremRequest(count: 9223372036854775807)),
      throwsA(
        isA<LoremException>().having(
          (error) => error.kind,
          'kind',
          LoremFailureKind.resource,
        ),
      ),
    );
    expect(allocations, 0);
  });
  test('GivenExactBudget_WhenGenerated_ThenPermitWholeResult', () {
    expect(
      const LoremGenerator(maxOutputCharacters: 56)
          .generate(const LoremRequest())
          .text
          .length,
      56,
    );
  });
  test('GivenUnrelatedArgumentError_WhenAllocatorFails_ThenDoNotMisclassifyAsResource', () {
    final generator = LoremGenerator.forTesting(
      allocate: (_) => throw ArgumentError('PRIVATE'),
    );
    expect(
      () => generator.generate(const LoremRequest()),
      throwsA(isA<ArgumentError>()),
    );
  });
  test('GivenAllocationFailure_WhenGenerated_ThenRedactedResource', () {
    final generator = LoremGenerator.forTesting(
      allocate: (_) => throw OutOfMemoryError(),
    );
    expect(
      () => generator.generate(const LoremRequest()),
      throwsA(
        isA<LoremException>().having(
          (e) => e.code,
          'code',
          'lorem.resource-limit',
        ),
      ),
    );
  });
}
