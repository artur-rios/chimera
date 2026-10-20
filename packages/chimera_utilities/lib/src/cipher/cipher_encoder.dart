enum CipherAlgorithm {
  caesar('caesar'),
  rot13('rot13'),
  vigenere('vigenere'),
  atbash('atbash'),
  affine('affine'),
  bacon('bacon'),
  railFence('rail-fence');

  const CipherAlgorithm(this.wireName);

  final String wireName;

  static CipherAlgorithm? tryParse(String value) {
    for (final algorithm in values) {
      if (algorithm.wireName == value) return algorithm;
    }
    return null;
  }
}

enum CipherCharacterPolicy {
  preserve('preserve'),
  reject('reject');

  const CipherCharacterPolicy(this.wireName);

  final String wireName;

  static CipherCharacterPolicy? tryParse(String value) {
    for (final policy in values) {
      if (policy.wireName == value) return policy;
    }
    return null;
  }
}

enum CipherFailureKind { validation, resource }

/// Safe failure metadata. Source text, keys, symbols, and output are excluded.
final class CipherException implements Exception {
  const CipherException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
    this.position,
  });

  final CipherFailureKind kind;
  final String code;
  final String field;
  final String reason;
  final int? position;
}

final class CipherEncodeRequest {
  const CipherEncodeRequest({
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

final class CipherEncodeResult {
  const CipherEncodeResult({
    required this.encoded,
    required this.algorithm,
    required this.characterPolicy,
  });

  final String encoded;
  final CipherAlgorithm algorithm;
  final CipherCharacterPolicy characterPolicy;
}

/// Pure, stateless classical-cipher encoding over the ASCII letter alphabet.
final class CipherEncoder {
  const CipherEncoder({this.maxOutputCharacters})
    : assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  /// Optional UTF-16 output budget for deterministic resource-boundary tests.
  /// Production callers leave this unset and impose no product-specific limit.
  final int? maxOutputCharacters;

  CipherEncodeResult encode(CipherEncodeRequest request) {
    try {
      final scalars = _validatedScalars(request.input);
      _validateCharacterPolicy(scalars, request.characterPolicy);
      _validateParameters(request);

      final encoded = switch (request.algorithm) {
        CipherAlgorithm.caesar => _rotate(scalars, request.shift!),
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
          when encoded.length > maximum) {
        _throwResource(field: 'output', reason: 'output-limit');
      }
      return CipherEncodeResult(
        encoded: encoded,
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

  void _validateParameters(CipherEncodeRequest request) {
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
    CipherEncodeRequest request, {
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
    final shifts = key.codeUnits.map((unit) => _letterValue(unit)).toList();
    var keyIndex = 0;
    return String.fromCharCodes(
      scalars.map((scalar) {
        if (!_isAsciiLetter(scalar)) return scalar;
        final encoded = _mapLetter(scalar, (value) {
          final shift = shifts[keyIndex % shifts.length];
          keyIndex++;
          return value + shift;
        });
        return encoded;
      }),
    );
  }

  String _atbash(List<int> scalars) => String.fromCharCodes(
    scalars.map((scalar) => _mapLetter(scalar, (value) => 25 - value)),
  );

  String _affine(List<int> scalars, int a, int b) => String.fromCharCodes(
    scalars.map((scalar) => _mapLetter(scalar, (value) => a * value + b)),
  );

  String _bacon(List<int> scalars) {
    final output = StringBuffer();
    for (final scalar in scalars) {
      if (!_isAsciiLetter(scalar)) {
        output.writeCharCode(scalar);
        continue;
      }
      final uppercase = scalar >= 0x41 && scalar <= 0x5a;
      final zero = uppercase ? 0x41 : 0x61;
      final one = uppercase ? 0x42 : 0x62;
      final value = _letterValue(scalar);
      for (var bit = 4; bit >= 0; bit--) {
        output.writeCharCode((value & (1 << bit)) == 0 ? zero : one);
      }
    }
    return output.toString();
  }

  String _railFence(List<int> scalars, int rails) {
    final letters = scalars.where(_isAsciiLetter).toList();
    if (letters.length < 2 || rails >= letters.length) {
      return String.fromCharCodes(scalars);
    }

    final rows = List<List<int>>.generate(rails, (_) => <int>[]);
    var row = 0;
    var direction = 1;
    for (final letter in letters) {
      rows[row].add(letter);
      if (row == 0) {
        direction = 1;
      } else if (row == rails - 1) {
        direction = -1;
      }
      row += direction;
    }
    final transformed = rows.expand((values) => values).iterator;
    return String.fromCharCodes(
      scalars.map((scalar) {
        if (!_isAsciiLetter(scalar)) return scalar;
        transformed.moveNext();
        return transformed.current;
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

  Never _throwInvalidUnicode() => throw const CipherException(
    kind: CipherFailureKind.validation,
    code: 'cipher.invalid-input',
    field: 'input',
    reason: 'invalid-unicode',
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
