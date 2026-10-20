import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const encoder = AlphabetEncoder();

  group('AlphabetKind', () {
    test('GivenWireNames_WhenParsed_ThenOnlyExactSupportedNamesResolve', () {
      expect(AlphabetKind.tryParse('morse'), AlphabetKind.morse);
      expect(AlphabetKind.tryParse('nato'), AlphabetKind.nato);
      expect(AlphabetKind.tryParse('braille'), AlphabetKind.braille);
      expect(AlphabetKind.tryParse('Morse'), isNull);
      expect(AlphabetKind.tryParse('unknown'), isNull);
    });
  });

  group('Published alphabet mappings', () {
    test('GivenMorseMapping_WhenInspected_ThenExactOfficialTableIsExposed', () {
      final mapping = alphabetMappingFor(AlphabetKind.morse);

      expect(mapping.id, 'itu-r-m.1677-1');
      expect(mapping.edition, '10/2009');
      expect(
        mapping.sources,
        contains('https://www.itu.int/rec/R-REC-M.1677-1-200910-I/en'),
      );
      expect(mapping.symbols, _morseSymbols);
      expect(mapping.rules, isNotEmpty);
    });

    test('GivenNatoMapping_WhenInspected_ThenExactIcaoTableIsExposed', () {
      final mapping = alphabetMappingFor(AlphabetKind.nato);

      expect(mapping.id, 'icao-radiotelephony-spelling-alphabet');
      expect(mapping.edition, '1956');
      expect(
        mapping.sources,
        contains(
          'https://www.icao.int/sites/default/files/postalhistory/'
          'annex_10_aeronautical_telecommunications.htm',
        ),
      );
      expect(mapping.symbols, _natoSymbols);
      expect(mapping.rules, isNotEmpty);
    });

    test('GivenBrailleMapping_WhenInspected_ThenExactUebTableIsExposed', () {
      final mapping = alphabetMappingFor(AlphabetKind.braille);

      expect(mapping.id, 'ueb-uncontracted-unicode');
      expect(mapping.edition, 'third-edition-2024');
      expect(
        mapping.sources,
        contains(
          'https://iceb.org/wp-content/uploads/2025/10/'
          'Rules-of-Unified-English-Braille-2024.pdf',
        ),
      );
      expect(
        mapping.sources,
        contains('https://www.unicode.org/charts/PDF/U2800.pdf'),
      );
      expect(mapping.symbols, _brailleSymbols);
      expect(mapping.rules, isNotEmpty);
    });

    test(
      'GivenMappingMetadata_WhenMutationIsAttempted_ThenItRemainsImmutable',
      () {
        final mapping = alphabetMappingFor(AlphabetKind.morse);

        expect(
          () => mapping.sources.add('https://example.test'),
          throwsUnsupportedError,
        );
        expect(() => mapping.rules.add('changed'), throwsUnsupportedError);
        expect(() => mapping.symbols['A'] = 'changed', throwsUnsupportedError);
      },
    );
  });

  group('AlphabetEncoder known answers', () {
    final fixtures = <({AlphabetEncodeRequest request, String encoded})>[
      (
        request: const AlphabetEncodeRequest(
          input: 'SOS 2\nAz',
          alphabet: AlphabetKind.morse,
        ),
        encoded: '... --- ... / ..---\n.- --..',
      ),
      (
        request: const AlphabetEncodeRequest(
          input: 'Az 39\r\nB',
          alphabet: AlphabetKind.nato,
        ),
        encoded: 'Alfa Zulu / Tree Niner\r\nBravo',
      ),
      (
        request: const AlphabetEncodeRequest(
          input: 'Ab 12c Z90',
          alphabet: AlphabetKind.braille,
        ),
        encoded:
            '\u2820\u2801\u2803 \u283c\u2801\u2803\u2830\u2809 '
            '\u2820\u2835\u283c\u280a\u281a',
      ),
    ];

    for (final fixture in fixtures) {
      test(
        'Given${fixture.request.alphabet.name}_WhenEncoded_ThenKnownAnswerAndMappingReturn',
        () {
          final result = encoder.encode(fixture.request);

          expect(result.encoded, fixture.encoded);
          expect(result.alphabet, fixture.request.alphabet);
          expect(result.mapping, alphabetMappingFor(fixture.request.alphabet));
        },
      );
    }
  });

  test(
    'GivenEverySupportedLetterAndDigit_WhenMorseEncoded_ThenTableMatches',
    () {
      final source = _morseSymbols.keys.where((key) => key.length == 1).join();
      final expected = _morseSymbols.values
          .where((value) => value != '/' && value != '<preserved>')
          .join(' ');

      final result = encoder.encode(
        AlphabetEncodeRequest(input: source, alphabet: AlphabetKind.morse),
      );

      expect(result.encoded, expected);
    },
  );

  test(
    'GivenEverySupportedLetterAndDigit_WhenNatoEncoded_ThenTableMatches',
    () {
      final source = _natoSymbols.keys.where((key) => key.length == 1).join();
      final expected = _natoSymbols.values
          .where((value) => value != '/' && value != '<preserved>')
          .join(' ');

      final result = encoder.encode(
        AlphabetEncodeRequest(input: source, alphabet: AlphabetKind.nato),
      );

      expect(result.encoded, expected);
    },
  );

  test('GivenLowercaseLetters_WhenTokenAlphabetEncoded_ThenCaseIsFolded', () {
    expect(
      encoder
          .encode(
            const AlphabetEncodeRequest(
              input: 'az',
              alphabet: AlphabetKind.morse,
            ),
          )
          .encoded,
      '.- --..',
    );
    expect(
      encoder
          .encode(
            const AlphabetEncodeRequest(
              input: 'az',
              alphabet: AlphabetKind.nato,
            ),
          )
          .encoded,
      'Alfa Zulu',
    );
  });

  test(
    'GivenRepeatedSpaces_WhenTokenAlphabetEncoded_ThenEachSpaceIsPreserved',
    () {
      expect(
        encoder
            .encode(
              const AlphabetEncodeRequest(
                input: ' A  B ',
                alphabet: AlphabetKind.morse,
              ),
            )
            .encoded,
        '/ .- / / -... /',
      );
    },
  );

  test(
    'GivenBrailleCaseAndNumericTransitions_WhenEncoded_ThenUebIsUnambiguous',
    () {
      final result = encoder.encode(
        const AlphabetEncodeRequest(
          input: 'aA 10a 2k 3B\r\n0',
          alphabet: AlphabetKind.braille,
        ),
      );

      expect(
        result.encoded,
        '\u2801\u2820\u2801 \u283c\u2801\u281a\u2830\u2801 '
        '\u283c\u2803\u2805 \u283c\u2809\u2820\u2803\r\n'
        '\u283c\u281a',
      );
    },
  );

  test('GivenEmptyText_WhenEncoded_ThenEmptyResultWithMapping', () {
    final result = encoder.encode(
      const AlphabetEncodeRequest(input: '', alphabet: AlphabetKind.braille),
    );

    expect(result.encoded, isEmpty);
    expect(result.mapping.id, 'ueb-uncontracted-unicode');
  });

  test(
    'GivenUnsupportedBmpSymbol_WhenEncoded_ThenTypedScalarPositionReturns',
    () {
      expect(
        () => encoder.encode(
          const AlphabetEncodeRequest(
            input: 'AB\tC',
            alphabet: AlphabetKind.nato,
          ),
        ),
        throwsA(
          isA<AlphabetException>()
              .having(
                (error) => error.kind,
                'kind',
                AlphabetFailureKind.validation,
              )
              .having(
                (error) => error.code,
                'code',
                'alphabet.unsupported-symbol',
              )
              .having((error) => error.field, 'field', 'input')
              .having((error) => error.reason, 'reason', 'unsupported-symbol')
              .having((error) => error.position, 'position', 2),
        ),
      );
    },
  );

  test(
    'GivenUnsupportedSupplementarySymbol_WhenEncoded_ThenScalarPositionReturns',
    () {
      expect(
        () => encoder.encode(
          const AlphabetEncodeRequest(
            input: 'AB\u{1f600}C',
            alphabet: AlphabetKind.morse,
          ),
        ),
        throwsA(
          isA<AlphabetException>()
              .having(
                (error) => error.code,
                'code',
                'alphabet.unsupported-symbol',
              )
              .having((error) => error.position, 'position', 2),
        ),
      );
    },
  );

  test(
    'GivenMalformedUnicode_WhenEncoded_ThenTypedValidationFailureReturns',
    () {
      expect(
        () => encoder.encode(
          const AlphabetEncodeRequest(
            input: '\uD800',
            alphabet: AlphabetKind.braille,
          ),
        ),
        throwsA(
          isA<AlphabetException>()
              .having((error) => error.code, 'code', 'alphabet.invalid-input')
              .having((error) => error.field, 'field', 'input')
              .having((error) => error.reason, 'reason', 'invalid-unicode'),
        ),
      );
    },
  );

  test(
    'GivenNatoPunctuation_WhenEncoded_ThenNoPartialOutputEscapesFailure',
    () {
      expect(
        () => encoder.encode(
          const AlphabetEncodeRequest(
            input: 'SECRET!',
            alphabet: AlphabetKind.nato,
          ),
        ),
        throwsA(
          isA<AlphabetException>()
              .having(
                (error) => error.code,
                'code',
                'alphabet.unsupported-symbol',
              )
              .having((error) => error.position, 'position', 6),
        ),
      );
    },
  );

  test(
    'GivenOutputBudgetExceeded_WhenEncoded_ThenTypedResourceFailureReturns',
    () {
      const limited = AlphabetEncoder(maxOutputCharacters: 6);

      expect(
        () => limited.encode(
          const AlphabetEncodeRequest(
            input: 'AB',
            alphabet: AlphabetKind.morse,
          ),
        ),
        throwsA(
          isA<AlphabetException>()
              .having(
                (error) => error.kind,
                'kind',
                AlphabetFailureKind.resource,
              )
              .having((error) => error.code, 'code', 'alphabet.resource-limit')
              .having((error) => error.field, 'field', 'output')
              .having((error) => error.reason, 'reason', 'output-limit'),
        ),
      );
    },
  );
}

const _morseSymbols = <String, String>{
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',
  '<space>': '/',
  '<line-break>': '<preserved>',
};

const _natoSymbols = <String, String>{
  'A': 'Alfa',
  'B': 'Bravo',
  'C': 'Charlie',
  'D': 'Delta',
  'E': 'Echo',
  'F': 'Foxtrot',
  'G': 'Golf',
  'H': 'Hotel',
  'I': 'India',
  'J': 'Juliett',
  'K': 'Kilo',
  'L': 'Lima',
  'M': 'Mike',
  'N': 'November',
  'O': 'Oscar',
  'P': 'Papa',
  'Q': 'Quebec',
  'R': 'Romeo',
  'S': 'Sierra',
  'T': 'Tango',
  'U': 'Uniform',
  'V': 'Victor',
  'W': 'Whiskey',
  'X': 'X-ray',
  'Y': 'Yankee',
  'Z': 'Zulu',
  '0': 'Zero',
  '1': 'Wun',
  '2': 'Too',
  '3': 'Tree',
  '4': 'Fower',
  '5': 'Fife',
  '6': 'Six',
  '7': 'Seven',
  '8': 'Ait',
  '9': 'Niner',
  '<space>': '/',
  '<line-break>': '<preserved>',
};

const _brailleSymbols = <String, String>{
  'a': '\u2801',
  'b': '\u2803',
  'c': '\u2809',
  'd': '\u2819',
  'e': '\u2811',
  'f': '\u280b',
  'g': '\u281b',
  'h': '\u2813',
  'i': '\u280a',
  'j': '\u281a',
  'k': '\u2805',
  'l': '\u2807',
  'm': '\u280d',
  'n': '\u281d',
  'o': '\u2815',
  'p': '\u280f',
  'q': '\u281f',
  'r': '\u2817',
  's': '\u280e',
  't': '\u281e',
  'u': '\u2825',
  'v': '\u2827',
  'w': '\u283a',
  'x': '\u282d',
  'y': '\u283d',
  'z': '\u2835',
  '1': '\u2801',
  '2': '\u2803',
  '3': '\u2809',
  '4': '\u2819',
  '5': '\u2811',
  '6': '\u280b',
  '7': '\u281b',
  '8': '\u2813',
  '9': '\u280a',
  '0': '\u281a',
  '<capital-prefix>': '\u2820',
  '<numeric-prefix>': '\u283c',
  '<grade-1-prefix>': '\u2830',
  '<space>': ' ',
  '<line-break>': '<preserved>',
};
