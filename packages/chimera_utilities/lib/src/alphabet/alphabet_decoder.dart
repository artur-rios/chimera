import 'alphabet_codec.dart';

final class AlphabetDecodeRequest {
  const AlphabetDecodeRequest({required this.input, required this.alphabet});

  final String input;
  final AlphabetKind alphabet;
}

final class AlphabetDecodeResult {
  const AlphabetDecodeResult({
    required this.decoded,
    required this.alphabet,
    required this.mapping,
  });

  final String decoded;
  final AlphabetKind alphabet;
  final AlphabetMapping mapping;
}

/// Pure, stateless decoding of Chimera's canonical alphabet representations.
final class AlphabetDecoder {
  const AlphabetDecoder({this.maxOutputCharacters})
    : assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  /// Optional UTF-16 output budget for deterministic resource-boundary tests.
  final int? maxOutputCharacters;

  AlphabetDecodeResult decode(AlphabetDecodeRequest request) {
    try {
      final scalars = _validatedScalars(request.input);
      final mapping = alphabetMappingFor(request.alphabet);
      final decoded = switch (request.alphabet) {
        AlphabetKind.morse => _decodeTokens(
          scalars,
          mapping.symbols,
          asciiCaseInsensitive: false,
        ),
        AlphabetKind.nato => _decodeTokens(
          scalars,
          mapping.symbols,
          asciiCaseInsensitive: true,
        ),
        AlphabetKind.braille => _decodeBraille(scalars, mapping.symbols),
      };

      if (maxOutputCharacters case final maximum?
          when decoded.length > maximum) {
        _throwResource(field: 'output', reason: 'output-limit');
      }
      return AlphabetDecodeResult(
        decoded: decoded,
        alphabet: request.alphabet,
        mapping: mapping,
      );
    } on OutOfMemoryError {
      _throwResource(field: 'output', reason: 'allocation-limit');
    }
  }

  String _decodeTokens(
    List<int> scalars,
    Map<String, String> symbols, {
    required bool asciiCaseInsensitive,
  }) {
    final inverse = <String, String>{};
    for (final entry in symbols.entries) {
      if (entry.key.startsWith('<')) continue;
      inverse[asciiCaseInsensitive
              ? _asciiLowercase(entry.value)
              : entry.value] =
          entry.key;
    }
    inverse['/'] = ' ';

    final output = StringBuffer();
    final token = <int>[];
    var tokenStart = 0;
    var separatorPosition = -1;

    void flush() {
      final raw = String.fromCharCodes(token);
      final lookup = asciiCaseInsensitive ? _asciiLowercase(raw) : raw;
      final value = inverse[lookup];
      if (value == null) {
        _throwValidation(reason: 'unsupported-symbol', position: tokenStart);
      }
      output.write(value);
      token.clear();
      separatorPosition = -1;
    }

    for (var index = 0; index < scalars.length; index++) {
      final scalar = scalars[index];
      if (scalar == 0x0a || scalar == 0x0d) {
        if (token.isNotEmpty) {
          flush();
        } else if (separatorPosition >= 0) {
          _throwValidation(
            reason: 'invalid-token-sequence',
            position: separatorPosition,
          );
        }
        output.writeCharCode(scalar);
        continue;
      }
      if (scalar == 0x20) {
        if (token.isEmpty) {
          _throwValidation(reason: 'invalid-token-sequence', position: index);
        }
        flush();
        separatorPosition = index;
        continue;
      }
      if (token.isEmpty) tokenStart = index;
      token.add(scalar);
    }

    if (token.isNotEmpty) {
      flush();
    } else if (separatorPosition >= 0) {
      _throwValidation(
        reason: 'invalid-token-sequence',
        position: separatorPosition,
      );
    }
    return output.toString();
  }

  String _decodeBraille(List<int> scalars, Map<String, String> symbols) {
    final letters = <int, String>{};
    for (var scalar = 0x61; scalar <= 0x7a; scalar++) {
      final letter = String.fromCharCode(scalar);
      letters[symbols[letter]!.runes.single] = letter;
    }
    final digits = <int, String>{};
    for (var scalar = 0x30; scalar <= 0x39; scalar++) {
      final digit = String.fromCharCode(scalar);
      digits[symbols[digit]!.runes.single] = digit;
    }
    final capital = symbols['<capital-prefix>']!.runes.single;
    final numeric = symbols['<numeric-prefix>']!.runes.single;
    final grade1 = symbols['<grade-1-prefix>']!.runes.single;
    final output = StringBuffer();
    var numericMode = false;

    for (var index = 0; index < scalars.length; index++) {
      final scalar = scalars[index];
      if (scalar == 0x20 || scalar == 0x0a || scalar == 0x0d) {
        output.writeCharCode(scalar);
        numericMode = false;
        continue;
      }

      if (scalar == capital) {
        if (index + 1 >= scalars.length ||
            !letters.containsKey(scalars[index + 1])) {
          _throwValidation(
            reason: 'ambiguous-braille-sequence',
            position: index,
          );
        }
        final letter = letters[scalars[++index]]!;
        output.write(letter.toUpperCase());
        numericMode = false;
        continue;
      }

      if (scalar == numeric) {
        if (numericMode) {
          _throwValidation(
            reason: 'ambiguous-braille-sequence',
            position: index,
          );
        }
        if (index + 1 >= scalars.length ||
            !digits.containsKey(scalars[index + 1])) {
          final position =
              index + 1 < scalars.length && scalars[index + 1] == numeric
              ? index + 1
              : index;
          _throwValidation(
            reason: 'ambiguous-braille-sequence',
            position: position,
          );
        }
        numericMode = true;
        continue;
      }

      if (scalar == grade1) {
        if (!numericMode ||
            index + 1 >= scalars.length ||
            !digits.containsKey(scalars[index + 1])) {
          _throwValidation(
            reason: 'ambiguous-braille-sequence',
            position: index,
          );
        }
        output.write(letters[scalars[++index]]);
        numericMode = false;
        continue;
      }

      final letter = letters[scalar];
      if (letter == null) {
        _throwValidation(reason: 'unsupported-symbol', position: index);
      }
      final digit = digits[scalar];
      if (numericMode && digit != null) {
        output.write(digit);
      } else {
        output.write(letter);
        numericMode = false;
      }
    }
    return output.toString();
  }

  List<int> _validatedScalars(String input) {
    final scalars = <int>[];
    for (var index = 0; index < input.length; index++) {
      final first = input.codeUnitAt(index);
      if (first >= 0xd800 && first <= 0xdbff) {
        if (index + 1 >= input.length) _throwInvalidUnicode();
        final second = input.codeUnitAt(index + 1);
        if (second < 0xdc00 || second > 0xdfff) _throwInvalidUnicode();
        scalars.add(0x10000 + ((first - 0xd800) << 10) + (second - 0xdc00));
        index++;
      } else if (first >= 0xdc00 && first <= 0xdfff) {
        _throwInvalidUnicode();
      } else {
        scalars.add(first);
      }
    }
    return scalars;
  }

  String _asciiLowercase(String value) => String.fromCharCodes(
    value.runes.map(
      (scalar) => scalar >= 0x41 && scalar <= 0x5a ? scalar + 0x20 : scalar,
    ),
  );

  Never _throwInvalidUnicode() => throw const AlphabetException(
    kind: AlphabetFailureKind.validation,
    code: 'alphabet.invalid-input',
    field: 'input',
    reason: 'invalid-unicode',
  );

  Never _throwValidation({required String reason, required int position}) =>
      throw AlphabetException(
        kind: AlphabetFailureKind.validation,
        code: 'alphabet.invalid-input',
        field: 'input',
        reason: reason,
        position: position,
      );

  Never _throwResource({required String field, required String reason}) =>
      throw AlphabetException(
        kind: AlphabetFailureKind.resource,
        code: 'alphabet.resource-limit',
        field: field,
        reason: reason,
      );
}
