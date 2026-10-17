import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('TextAnalyzer', () {
    const analyzer = TextAnalyzer();

    test('GivenAsciiText_WhenAnalyzed_ThenEveryCountIsReturned', () {
      final result = analyzer.analyze('Hello, world!\nSecond line.');

      expect(result.characterCount, 26);
      expect(result.wordCount, 4);
      expect(result.lineCount, 2);
      expect(result.byteCount, 26);
    });

    test('GivenEmptyText_WhenAnalyzed_ThenEveryCountIsZero', () {
      final result = analyzer.analyze('');

      expect(result.characterCount, 0);
      expect(result.wordCount, 0);
      expect(result.lineCount, 0);
      expect(result.byteCount, 0);
    });

    test(
      'GivenUnicodeClusters_WhenAnalyzed_ThenCharactersUseGraphemeBoundaries',
      () {
        final result = analyzer.analyze('Cafe\u0301 👩🏽‍💻 🇧🇷');

        expect(result.characterCount, 8);
        expect(result.wordCount, 1);
        expect(result.lineCount, 1);
        expect(result.byteCount, 31);
      },
    );

    test(
      'GivenMultilingualText_WhenAnalyzed_ThenWordsUseUnicodeConstituents',
      () {
        final result = analyzer.analyze("Olá, 你好 — can't l’heure 123");

        expect(result.wordCount, 5);
      },
    );

    test(
      'GivenUnicodeNumbers_WhenAnalyzed_ThenOnlyDecimalDigitsCreateWords',
      () {
        final result = analyzer.analyze('١٢٣ ² Ⅻ');

        expect(result.wordCount, 1);
      },
    );

    test('GivenPunctuationAndEmoji_WhenAnalyzed_ThenTheyDoNotCreateWords', () {
      final result = analyzer.analyze('... 👩‍💻 --');

      expect(result.wordCount, 0);
    });

    test('GivenApostropheEdges_WhenAnalyzed_ThenOnlyInternalOnesJoinWords', () {
      final result = analyzer.analyze("'alpha' beta' 'gamma l’heure");

      expect(result.wordCount, 4);
    });

    test('GivenEveryLineEnding_WhenAnalyzed_ThenBoundariesAreCountedOnce', () {
      expect(analyzer.analyze('a').lineCount, 1);
      expect(analyzer.analyze('a\n').lineCount, 2);
      expect(analyzer.analyze('a\r\nb\rc\n').lineCount, 4);
    });

    test('GivenUnicodeScalars_WhenAnalyzed_ThenUtf8BytesAreExact', () {
      final result = analyzer.analyze('Aé漢🚀');

      expect(result.characterCount, 4);
      expect(result.byteCount, 10);
    });

    test(
      'GivenInputBudget_WhenAtOrBeyondBoundary_ThenOversizeInputIsRejected',
      () {
        final exact = const TextAnalyzer(maxInputCodeUnits: 2).analyze('🚀');
        expect(exact.characterCount, 1);

        expect(
          () => const TextAnalyzer(maxInputCodeUnits: 1).analyze('🚀'),
          _textAnalyzeFailure(
            kind: TextAnalyzeFailureKind.resource,
            code: 'text-analyze.resource-limit',
            field: 'input',
            reason: 'character-limit',
          ),
        );
      },
    );
  });
}

Matcher _textAnalyzeFailure({
  required TextAnalyzeFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<TextAnalyzeException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
