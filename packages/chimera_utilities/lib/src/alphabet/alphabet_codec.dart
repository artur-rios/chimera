enum AlphabetKind {
  morse('morse'),
  nato('nato'),
  braille('braille');

  const AlphabetKind(this.wireName);

  final String wireName;

  static AlphabetKind? tryParse(String value) {
    for (final alphabet in values) {
      if (alphabet.wireName == value) return alphabet;
    }
    return null;
  }
}

enum AlphabetFailureKind { validation, resource }

/// Safe failure metadata. Source symbols and partial output are excluded.
final class AlphabetException implements Exception {
  const AlphabetException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
    this.position,
  });

  final AlphabetFailureKind kind;
  final String code;
  final String field;
  final String reason;
  final int? position;
}

final class AlphabetMapping {
  AlphabetMapping({
    required this.id,
    required this.edition,
    required List<String> sources,
    required Map<String, String> symbols,
    required List<String> rules,
  }) : sources = List<String>.unmodifiable(sources),
       symbols = Map<String, String>.unmodifiable(symbols),
       rules = List<String>.unmodifiable(rules);

  final String id;
  final String edition;
  final List<String> sources;
  final Map<String, String> symbols;
  final List<String> rules;
}

AlphabetMapping alphabetMappingFor(AlphabetKind alphabet) => switch (alphabet) {
  AlphabetKind.morse => _morseMapping,
  AlphabetKind.nato => _natoMapping,
  AlphabetKind.braille => _brailleMapping,
};

final _morseMapping = AlphabetMapping(
  id: 'itu-r-m.1677-1',
  edition: '10/2009',
  sources: const ['https://www.itu.int/rec/R-REC-M.1677-1-200910-I/en'],
  symbols: _morseSymbols,
  rules: const [
    'ASCII letters are case-insensitive.',
    'Adjacent source symbols are separated by one ASCII space.',
    'Each ASCII space is represented by a slash token.',
    'CR and LF line-break scalars are preserved.',
  ],
);

final _natoMapping = AlphabetMapping(
  id: 'icao-radiotelephony-spelling-alphabet',
  edition: '1956',
  sources: const [
    'https://www.icao.int/sites/default/files/postalhistory/'
        'annex_10_aeronautical_telecommunications.htm',
  ],
  symbols: _natoSymbols,
  rules: const [
    'ASCII letters are case-insensitive.',
    'Digits use ICAO radiotelephony pronunciation words.',
    'Adjacent source symbols are separated by one ASCII space.',
    'Each ASCII space is represented by a slash token.',
    'CR and LF line-break scalars are preserved.',
  ],
);

final _brailleMapping = AlphabetMapping(
  id: 'ueb-uncontracted-unicode',
  edition: 'third-edition-2024',
  sources: const [
    'https://iceb.org/wp-content/uploads/2025/10/'
        'Rules-of-Unified-English-Braille-2024.pdf',
    'https://www.unicode.org/charts/PDF/U2800.pdf',
  ],
  symbols: _brailleSymbols,
  rules: const [
    'Letters use uncontracted six-dot Unified English Braille.',
    'Each uppercase letter is preceded by the dot-six capital prefix.',
    'Each contiguous digit run starts with the dots-3456 numeric prefix.',
    'A lowercase a-j after an adjacent digit run has a dots-56 grade-1 prefix.',
    'ASCII spaces and CR/LF line-break scalars are preserved.',
  ],
);

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
