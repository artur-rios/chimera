import 'cipher_encoder.dart';

final class CipherDecodeRequest {
  const CipherDecodeRequest({
    required this.input,
    required this.algorithm,
    this.characterPolicy = CipherCharacterPolicy.preserve,
    this.shift,
    this.key,
    this.affineA,
    this.affineB,
    this.rails,
  });

  final String input;
  final CipherAlgorithm algorithm;
  final CipherCharacterPolicy characterPolicy;
  final int? shift;
  final String? key;
  final int? affineA;
  final int? affineB;
  final int? rails;
}

final class CipherDecodeResult {
  const CipherDecodeResult({
    required this.decoded,
    required this.algorithm,
    required this.characterPolicy,
  });

  final String decoded;
  final CipherAlgorithm algorithm;
  final CipherCharacterPolicy characterPolicy;
}

/// Pure, stateless classical-cipher decoding over the ASCII letter alphabet.
final class CipherDecoder {
  const CipherDecoder({this.maxOutputCharacters})
    : assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  /// Optional UTF-16 output budget for deterministic resource-boundary tests.
  /// Production callers leave this unset and impose no product-specific limit.
  final int? maxOutputCharacters;

  CipherDecodeResult decode(CipherDecodeRequest request) {
    try {
      final scalars = _validatedScalars(request.input);
      _validateCharacterPolicy(scalars, request.characterPolicy);
      _validateParameters(request);

      final decoded = switch (request.algorithm) {
        CipherAlgorithm.caesar => _rotate(scalars, -request.shift!),
        CipherAlgorithm.rot13 => _rotate(scalars, 13),
        CipherAlgorithm.vigenere => _vigenere(scalars, request.key!),
        CipherAlgorithm.atbash => _atbash(scalars),
        CipherAlgorithm.affine => _affine(
          scalars,
          request.affineA!,
          request.affineB!,
        ),
        CipherAlgorithm.bacon => _bacon(scalars),
        CipherAlgorithm.railFence => _railFence(scalars, request.rails!),
      };

      if (maxOutputCharacters case final maximum?
          when decoded.length > maximum) {
        _throwResource(field: 'output', reason: 'output-limit');
      }
      return CipherDecodeResult(
        decoded: decoded,
        algorithm: request.algorithm,
        characterPolicy: request.characterPolicy,
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

  void _validateCharacterPolicy(
    List<int> scalars,
    CipherCharacterPolicy policy,
  ) {
    if (policy == CipherCharacterPolicy.preserve) return;
    for (var index = 0; index < scalars.length; index++) {
      if (!_isAsciiLetter(scalars[index])) {
        throw CipherException(
          kind: CipherFailureKind.validation,
          code: 'cipher.unsupported-symbol',
          field: 'input',
          reason: 'unsupported-symbol',
          position: index,
        );
      }
    }
  }

  void _validateParameters(CipherDecodeRequest request) {
    switch (request.algorithm) {
      case CipherAlgorithm.caesar:
        _rejectUnexpected(request, allowed: const {'shift'});
        _requireRange(request.shift, field: 'shift', minimum: 0, maximum: 25);
      case CipherAlgorithm.rot13:
      case CipherAlgorithm.atbash:
      case CipherAlgorithm.bacon:
        _rejectUnexpected(request, allowed: const {});
      case CipherAlgorithm.vigenere:
        _rejectUnexpected(request, allowed: const {'key'});
        final key = request.key;
        if (key == null || key.isEmpty) {
          _throwParameter(field: 'key', reason: 'required');
        }
        if (key.codeUnits.any((unit) => !_isAsciiLetter(unit))) {
          _throwParameter(field: 'key', reason: 'ascii-letters-only');
        }
      case CipherAlgorithm.affine:
        _rejectUnexpected(request, allowed: const {'a', 'b'});
        _requireRange(request.affineA, field: 'a', minimum: 0, maximum: 25);
        _requireRange(request.affineB, field: 'b', minimum: 0, maximum: 25);
        if (_greatestCommonDivisor(request.affineA!, 26) != 1) {
          _throwParameter(field: 'a', reason: 'not-coprime');
        }
      case CipherAlgorithm.railFence:
        _rejectUnexpected(request, allowed: const {'rails'});
        final rails = request.rails;
        if (rails == null) {
          _throwParameter(field: 'rails', reason: 'required');
        }
        if (rails < 2) {
          _throwParameter(field: 'rails', reason: 'out-of-range');
        }
    }
  }

  void _rejectUnexpected(
    CipherDecodeRequest request, {
    required Set<String> allowed,
  }) {
    final supplied = <String, Object?>{
      'shift': request.shift,
      'key': request.key,
      'a': request.affineA,
      'b': request.affineB,
      'rails': request.rails,
    };
    for (final entry in supplied.entries) {
      if (entry.value != null && !allowed.contains(entry.key)) {
        _throwParameter(field: entry.key, reason: 'unexpected');
      }
    }
  }

  void _requireRange(
    int? value, {
    required String field,
    required int minimum,
    required int maximum,
  }) {
    if (value == null) _throwParameter(field: field, reason: 'required');
    if (value < minimum || value > maximum) {
      _throwParameter(field: field, reason: 'out-of-range');
    }
  }

  String _rotate(List<int> scalars, int shift) => String.fromCharCodes(
    scalars.map((scalar) => _mapLetter(scalar, (value) => value + shift)),
  );

  String _vigenere(List<int> scalars, String key) {
    final shifts = key.codeUnits.map(_letterValue).toList();
    var keyIndex = 0;
    return String.fromCharCodes(
      scalars.map((scalar) {
        if (!_isAsciiLetter(scalar)) return scalar;
        return _mapLetter(scalar, (value) {
          final shift = shifts[keyIndex % shifts.length];
          keyIndex++;
          return value - shift;
        });
      }),
    );
  }

  String _atbash(List<int> scalars) => String.fromCharCodes(
    scalars.map((scalar) => _mapLetter(scalar, (value) => 25 - value)),
  );

  String _affine(List<int> scalars, int a, int b) {
    final inverse = _modularInverse(a, 26);
    return String.fromCharCodes(
      scalars.map(
        (scalar) => _mapLetter(scalar, (value) => inverse * (value - b)),
      ),
    );
  }

  String _bacon(List<int> scalars) {
    final output = StringBuffer();
    var groupStart = 0;
    var groupLength = 0;
    var groupUppercase = true;
    var value = 0;

    for (var position = 0; position < scalars.length; position++) {
      final scalar = scalars[position];
      final isBaconSymbol =
          scalar == 0x41 || scalar == 0x42 || scalar == 0x61 || scalar == 0x62;
      if (isBaconSymbol) {
        final uppercase = scalar <= 0x42;
        if (groupLength == 0) {
          groupStart = position;
          groupUppercase = uppercase;
          value = 0;
        } else if (uppercase != groupUppercase) {
          _throwAmbiguousBacon(position);
        }
        value = (value << 1) | ((scalar == 0x42 || scalar == 0x62) ? 1 : 0);
        groupLength++;
        if (groupLength == 5) {
          if (value > 25) _throwAmbiguousBacon(groupStart);
          output.writeCharCode((groupUppercase ? 0x41 : 0x61) + value);
          groupLength = 0;
        }
        continue;
      }

      if (_isAsciiLetter(scalar) || groupLength != 0) {
        _throwAmbiguousBacon(position);
      }
      output.writeCharCode(scalar);
    }

    if (groupLength != 0) _throwAmbiguousBacon(groupStart);
    return output.toString();
  }

  String _railFence(List<int> scalars, int rails) {
    final letterCount = scalars.where(_isAsciiLetter).length;
    if (letterCount < 2 || rails >= letterCount) {
      return String.fromCharCodes(scalars);
    }

    final pattern = List<int>.filled(letterCount, 0);
    final counts = List<int>.filled(rails, 0);
    var row = 0;
    var direction = 1;
    for (var index = 0; index < letterCount; index++) {
      pattern[index] = row;
      counts[row]++;
      if (row == 0) {
        direction = 1;
      } else if (row == rails - 1) {
        direction = -1;
      }
      row += direction;
    }

    final encodedLetters = scalars.where(_isAsciiLetter).toList();
    final rows = List<List<int>>.generate(rails, (_) => <int>[]);
    var offset = 0;
    for (var index = 0; index < rails; index++) {
      final next = offset + counts[index];
      rows[index].addAll(encodedLetters.sublist(offset, next));
      offset = next;
    }

    final rowOffsets = List<int>.filled(rails, 0);
    var patternIndex = 0;
    return String.fromCharCodes(
      scalars.map((scalar) {
        if (!_isAsciiLetter(scalar)) return scalar;
        final sourceRow = pattern[patternIndex++];
        return rows[sourceRow][rowOffsets[sourceRow]++];
      }),
    );
  }

  int _mapLetter(int scalar, int Function(int value) transform) {
    if (!_isAsciiLetter(scalar)) return scalar;
    final base = scalar >= 0x61 ? 0x61 : 0x41;
    return base + (transform(scalar - base) % 26);
  }

  int _letterValue(int scalar) =>
      scalar >= 0x61 ? scalar - 0x61 : scalar - 0x41;

  bool _isAsciiLetter(int scalar) =>
      (scalar >= 0x41 && scalar <= 0x5a) || (scalar >= 0x61 && scalar <= 0x7a);

  int _greatestCommonDivisor(int left, int right) {
    var a = left;
    var b = right;
    while (b != 0) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    return a.abs();
  }

  int _modularInverse(int value, int modulus) {
    for (var candidate = 1; candidate < modulus; candidate++) {
      if ((value * candidate) % modulus == 1) return candidate;
    }
    _throwParameter(field: 'a', reason: 'not-coprime');
  }

  Never _throwInvalidUnicode() => throw const CipherException(
    kind: CipherFailureKind.validation,
    code: 'cipher.invalid-input',
    field: 'input',
    reason: 'invalid-unicode',
  );

  Never _throwAmbiguousBacon(int position) => throw CipherException(
    kind: CipherFailureKind.validation,
    code: 'cipher.invalid-input',
    field: 'input',
    reason: 'ambiguous-bacon-input',
    position: position,
  );

  Never _throwParameter({required String field, required String reason}) =>
      throw CipherException(
        kind: CipherFailureKind.validation,
        code: 'cipher.invalid-parameter',
        field: field,
        reason: reason,
      );

  Never _throwResource({required String field, required String reason}) =>
      throw CipherException(
        kind: CipherFailureKind.resource,
        code: 'cipher.resource-limit',
        field: field,
        reason: reason,
      );
}
