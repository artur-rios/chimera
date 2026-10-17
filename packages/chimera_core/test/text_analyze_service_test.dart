import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenText_WhenAnalyzeServiceExecutes_ThenStableJsonReturns', () async {
    final result = await const TextAnalyzeService().execute(
      const TextAnalyzeOperationRequest(input: 'Olá 👩‍💻\nChimera'),
    );

    result.fold(
      onSuccess: (value) {
        expect(value.characterCount, 13);
        expect(value.wordCount, 2);
        expect(value.lineCount, 2);
        expect(value.byteCount, 24);
        expect(value.toJson(), <String, Object?>{
          'characters': 13,
          'words': 2,
          'lines': 2,
          'bytes': 24,
        });
      },
      onFailure: (failure) => fail(failure.code),
    );
  });

  test(
    'GivenResourceLimit_WhenAnalyzeServiceExecutes_ThenRedactedFailureReturns',
    () async {
      final result = await const TextAnalyzeService(
        analyzer: TextAnalyzer(maxInputCodeUnits: 2),
      ).execute(const TextAnalyzeOperationRequest(input: 'sensitive-text'));

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'text-analyze.resource-limit');
          expect(failure.messageKey, 'error.textAnalyze.resource');
          expect(failure.details, <String, Object?>{
            'field': 'input',
            'reason': 'character-limit',
          });
          expect(failure.details.toString(), isNot(contains('sensitive-text')));
        },
      );
    },
  );
}
