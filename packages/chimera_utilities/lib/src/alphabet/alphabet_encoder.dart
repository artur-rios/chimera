import 'alphabet_codec.dart';

final class AlphabetEncodeRequest {
  const AlphabetEncodeRequest({required this.input, required this.alphabet});

  final String input;
  final AlphabetKind alphabet;
}

final class AlphabetEncodeResult {
  const AlphabetEncodeResult({
    required this.encoded,
    required this.alphabet,
    required this.mapping,
  });

  final String encoded;
  final AlphabetKind alphabet;
  final AlphabetMapping mapping;
}

/// Pure, stateless encoding using Chimera's published representation alphabets.
final class AlphabetEncoder {
  const AlphabetEncoder({this.maxOutputCharacters})
    : assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  /// Optional UTF-16 output budget for deterministic resource-boundary tests.
  /// Production callers leave this unset and impose no product-specific limit.
  final int? maxOutputCharacters;

  AlphabetEncodeResult encode(AlphabetEncodeRequest request) {
    try {
      final scalars = _validatedScalars(request.input);
      _validateSupported(scalars);
      final mapping = alphabetMappingFor(request.alphabet);
      final encoded = switch (request.alphabet) {
        AlphabetKind.morse || AlphabetKind.nato => _encodeTokens(
          scalars,
          mapping.symbols,
        ),
        AlphabetKind.braille => _encodeBraille(scalars, mapping.symbols),
      };

      if (maxOutputCharacters case final maximum?
          when encoded.length > maximum) {
        _throwResource(field: 'output', reason: 'output-limit');
      }
      return AlphabetEncodeResult(
        encoded: encoded,
        alphabet: request.alphabet,
        mapping: mapping,
      );
    } on OutOfMemoryError {
      _throwResource(field: 'output', reason: 'allocation-limit');
    }
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

  void _validateSupported(List<int> scalars) {
    for (var index = 0; index < scalars.length; index++) {
      if (!_isAsciiLetter(scalars[index]) &&
          !_isAsciiDigit(scalars[index]) &&
          scalars[index] != 0x20 &&
          scalars[index] != 0x0a &&
          scalars[index] != 0x0d) {
        throw AlphabetException(
          kind: AlphabetFailureKind.validation,
          code: 'alphabet.unsupported-symbol',
          field: 'input',
          reason: 'unsupported-symbol',
          position: index,
        );
      }
    }
  }

  String _encodeTokens(List<int> scalars, Map<String, String> symbols) {
    final output = StringBuffer();
    var hasTokenOnLine = false;
    for (final scalar in scalars) {
      if (scalar == 0x0a || scalar == 0x0d) {
        output.writeCharCode(scalar);
        hasTokenOnLine = false;
        continue;
      }
      if (hasTokenOnLine) output.write(' ');
      if (scalar == 0x20) {
        output.write(symbols['<space>']);
      } else {
        output.write(symbols[String.fromCharCode(_uppercase(scalar))]);
      }
      hasTokenOnLine = true;
    }
    return output.toString();
  }

  String _encodeBraille(List<int> scalars, Map<String, String> symbols) {
    final output = StringBuffer();
    var numericMode = false;
    for (final scalar in scalars) {
      if (scalar == 0x20 || scalar == 0x0a || scalar == 0x0d) {
        output.writeCharCode(scalar);
        numericMode = false;
        continue;
      }

      if (_isAsciiDigit(scalar)) {
        if (!numericMode) output.write(symbols['<numeric-prefix>']);
        output.write(symbols[String.fromCharCode(scalar)]);
        numericMode = true;
        continue;
      }

      final uppercase = scalar >= 0x41 && scalar <= 0x5a;
      final lowercase = uppercase ? scalar + 0x20 : scalar;
      if (uppercase) {
        output.write(symbols['<capital-prefix>']);
      } else if (numericMode && lowercase >= 0x61 && lowercase <= 0x6a) {
        output.write(symbols['<grade-1-prefix>']);
      }
      output.write(symbols[String.fromCharCode(lowercase)]);
      numericMode = false;
    }
    return output.toString();
  }

  int _uppercase(int scalar) =>
      scalar >= 0x61 && scalar <= 0x7a ? scalar - 0x20 : scalar;

  bool _isAsciiLetter(int scalar) =>
      (scalar >= 0x41 && scalar <= 0x5a) ||
      (scalar >= 0x61 && scalar <= 0x7a);

  bool _isAsciiDigit(int scalar) => scalar >= 0x30 && scalar <= 0x39;

  Never _throwInvalidUnicode() => throw const AlphabetException(
    kind: AlphabetFailureKind.validation,
    code: 'alphabet.invalid-input',
    field: 'input',
    reason: 'invalid-unicode',
  );

  Never _throwResource({required String field, required String reason}) =>
      throw AlphabetException(
        kind: AlphabetFailureKind.resource,
        code: 'alphabet.resource-limit',
        field: field,
        reason: reason,
      );
}
