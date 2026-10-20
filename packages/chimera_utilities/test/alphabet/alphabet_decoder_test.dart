import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const decoder = AlphabetDecoder();
  const encoder = AlphabetEncoder();

  group('AlphabetDecoder known answers', () {
    final fixtures = <({AlphabetDecodeRequest request, String decoded})>[
      (
        request: const AlphabetDecodeRequest(
          input: '... --- ... / ..---\n.- --..',
          alphabet: AlphabetKind.morse,
        ),
        decoded: 'SOS 2\nAZ',
      ),
      (
        request: const AlphabetDecodeRequest(
          input: 'alfa ZULU / tree niner\r\nBravo',
          alphabet: AlphabetKind.nato,
        ),
        decoded: 'AZ 39\r\nB',
      ),
      (
        request: const AlphabetDecodeRequest(
          input:
              '\u2820\u2801\u2803 \u283c\u2801\u2803\u2830\u2809 '
              '\u2820\u2835\u283c\u280a\u281a',
          alphabet: AlphabetKind.braille,
        ),
        decoded: 'Ab 12c Z90',
      ),
    ];

    for (final fixture in fixtures) {
      test(
        'Given${fixture.request.alphabet.name}_WhenDecoded_ThenKnownAnswerAndMappingReturn',
        () {
          final result = decoder.decode(fixture.request);

          expect(result.decoded, fixture.decoded);
          expect(result.alphabet, fixture.request.alphabet);
          expect(result.mapping, alphabetMappingFor(fixture.request.alphabet));
        },
      );
    }
  });

  test('GivenEveryMorseToken_WhenDecoded_ThenFullInverseTableMatches', () {
    final result = decoder.decode(
      AlphabetDecodeRequest(
        input: _morseTokens.join(' '),
        alphabet: AlphabetKind.morse,
      ),
    );

    expect(result.decoded, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789');
  });

  test(
    'GivenEveryNatoWord_WhenDecoded_ThenAsciiCaseInsensitiveTableMatches',
    () {
      final result = decoder.decode(
        AlphabetDecodeRequest(
          input: _natoWords.map((word) => word.toUpperCase()).join(' '),
          alphabet: AlphabetKind.nato,
        ),
      );

      expect(result.decoded, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789');
    },
  );

  for (final alphabet in AlphabetKind.values) {
    test(
      'Given${alphabet.name}_EncoderOutput_WhenDecoded_ThenItRoundTrips',
      () {
        const source = 'aA 10a 2k 3B\r\nZ90';
        final encoded = encoder.encode(
          AlphabetEncodeRequest(input: source, alphabet: alphabet),
        );

        final result = decoder.decode(
          AlphabetDecodeRequest(input: encoded.encoded, alphabet: alphabet),
        );

        final expected = alphabet == AlphabetKind.braille
            ? source
            : source.toUpperCase();
        expect(result.decoded, expected);
      },
    );
  }

  test('GivenEmptyInput_WhenDecoded_ThenEmptyResultWithMappingReturns', () {
    final result = decoder.decode(
      const AlphabetDecodeRequest(input: '', alphabet: AlphabetKind.morse),
    );

    expect(result.decoded, isEmpty);
    expect(result.mapping.id, 'itu-r-m.1677-1');
  });

  test('GivenEmptyTokenLines_WhenDecoded_ThenLineBreaksArePreserved', () {
    final result = decoder.decode(
      const AlphabetDecodeRequest(
        input: '.-\r\n\n-...',
        alphabet: AlphabetKind.morse,
      ),
    );

    expect(result.decoded, 'A\r\n\nB');
  });

  test('GivenSlashTokens_WhenDecoded_ThenEverySourceSpaceIsPreserved', () {
    final result = decoder.decode(
      const AlphabetDecodeRequest(
        input: '/ .- / / -... /',
        alphabet: AlphabetKind.morse,
      ),
    );

    expect(result.decoded, ' A  B ');
  });

  test('GivenBrailleTransitions_WhenDecoded_ThenStateIsCanonical', () {
    final result = decoder.decode(
      const AlphabetDecodeRequest(
        input:
            '\u2801\u2820\u2801 \u283c\u2801\u281a\u2830\u2801 '
            '\u283c\u2803\u2805 \u283c\u2809\u2820\u2803\r\n'
            '\u283c\u281a',
        alphabet: AlphabetKind.braille,
      ),
    );

    expect(result.decoded, 'aA 10a 2k 3B\r\n0');
  });

  group('canonical token grammar', () {
    final invalidInputs = <({String input, int position})>[
      (input: ' .-', position: 0),
      (input: '.- ', position: 2),
      (input: '.-  -...', position: 3),
      (input: '.- \n-...', position: 2),
    ];

    for (final fixture in invalidInputs) {
      test(
        'GivenNonCanonical${fixture.position}_WhenDecoded_ThenItIsRejected',
        () {
          expect(
            () => decoder.decode(
              AlphabetDecodeRequest(
                input: fixture.input,
                alphabet: AlphabetKind.morse,
              ),
            ),
            throwsA(_validationAt('invalid-token-sequence', fixture.position)),
          );
        },
      );
    }
  });

  test('GivenUnknownMorseToken_WhenDecoded_ThenTokenStartPositionReturns', () {
    expect(
      () => decoder.decode(
        const AlphabetDecodeRequest(
          input: '.- ..-- -...',
          alphabet: AlphabetKind.morse,
        ),
      ),
      throwsA(_validationAt('unsupported-symbol', 3)),
    );
  });

  test('GivenNonAsciiNatoLookalike_WhenDecoded_ThenItIsRejected', () {
    expect(
      () => decoder.decode(
        const AlphabetDecodeRequest(
          input: 'Alf\u0430',
          alphabet: AlphabetKind.nato,
        ),
      ),
      throwsA(_validationAt('unsupported-symbol', 0)),
    );
  });

  group('Braille invalid indicator sequences', () {
    final fixtures = <({String input, int position})>[
      (input: '\u2820', position: 0),
      (input: '\u2820\u2820\u2801', position: 0),
      (input: '\u283c', position: 0),
      (input: '\u283c\u2805', position: 0),
      (input: '\u283c\u283c\u2801', position: 1),
      (input: '\u2830\u2801', position: 0),
      (input: '\u283c\u2801\u2830', position: 2),
      (input: '\u283c\u2801\u2830\u2805', position: 2),
    ];

    for (final fixture in fixtures) {
      test(
        'GivenInvalidIndicator${fixture.input.length}_WhenDecoded_ThenFails',
        () {
          expect(
            () => decoder.decode(
              AlphabetDecodeRequest(
                input: fixture.input,
                alphabet: AlphabetKind.braille,
              ),
            ),
            throwsA(
              _validationAt('ambiguous-braille-sequence', fixture.position),
            ),
          );
        },
      );
    }
  });

  test('GivenUnknownBrailleCell_WhenDecoded_ThenScalarPositionReturns', () {
    expect(
      () => decoder.decode(
        const AlphabetDecodeRequest(
          input: '\u2801\u{1f600}',
          alphabet: AlphabetKind.braille,
        ),
      ),
      throwsA(_validationAt('unsupported-symbol', 1)),
    );
  });

  test('GivenMalformedUnicode_WhenDecoded_ThenTypedFailureReturns', () {
    expect(
      () => decoder.decode(
        const AlphabetDecodeRequest(
          input: '\uD800',
          alphabet: AlphabetKind.braille,
        ),
      ),
      throwsA(
        isA<AlphabetException>()
            .having((error) => error.code, 'code', 'alphabet.invalid-input')
            .having((error) => error.reason, 'reason', 'invalid-unicode')
            .having((error) => error.position, 'position', isNull),
      ),
    );
  });

  test('GivenOutputBudgetExceeded_WhenDecoded_ThenResourceFailureReturns', () {
    const limited = AlphabetDecoder(maxOutputCharacters: 1);

    expect(
      () => limited.decode(
        const AlphabetDecodeRequest(
          input: '.- -...',
          alphabet: AlphabetKind.morse,
        ),
      ),
      throwsA(
        isA<AlphabetException>()
            .having((error) => error.kind, 'kind', AlphabetFailureKind.resource)
            .having((error) => error.code, 'code', 'alphabet.resource-limit')
            .having((error) => error.field, 'field', 'output')
            .having((error) => error.reason, 'reason', 'output-limit'),
      ),
    );
  });
}

Matcher _validationAt(String reason, int position) => isA<AlphabetException>()
    .having((error) => error.kind, 'kind', AlphabetFailureKind.validation)
    .having((error) => error.code, 'code', 'alphabet.invalid-input')
    .having((error) => error.field, 'field', 'input')
    .having((error) => error.reason, 'reason', reason)
    .having((error) => error.position, 'position', position);

const _morseTokens = <String>[
  '.-',
  '-...',
  '-.-.',
  '-..',
  '.',
  '..-.',
  '--.',
  '....',
  '..',
  '.---',
  '-.-',
  '.-..',
  '--',
  '-.',
  '---',
  '.--.',
  '--.-',
  '.-.',
  '...',
  '-',
  '..-',
  '...-',
  '.--',
  '-..-',
  '-.--',
  '--..',
  '-----',
  '.----',
  '..---',
  '...--',
  '....-',
  '.....',
  '-....',
  '--...',
  '---..',
  '----.',
];

const _natoWords = <String>[
  'Alfa',
  'Bravo',
  'Charlie',
  'Delta',
  'Echo',
  'Foxtrot',
  'Golf',
  'Hotel',
  'India',
  'Juliett',
  'Kilo',
  'Lima',
  'Mike',
  'November',
  'Oscar',
  'Papa',
  'Quebec',
  'Romeo',
  'Sierra',
  'Tango',
  'Uniform',
  'Victor',
  'Whiskey',
  'X-ray',
  'Yankee',
  'Zulu',
  'Zero',
  'Wun',
  'Too',
  'Tree',
  'Fower',
  'Fife',
  'Six',
  'Seven',
  'Ait',
  'Niner',
];
