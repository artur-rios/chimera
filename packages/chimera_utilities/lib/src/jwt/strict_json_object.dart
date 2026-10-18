import 'dart:convert';

enum StrictJsonObjectFailure {
  invalidJson,
  objectRequired,
  invalidUnicode,
  nonFiniteNumber,
  nestingLimit,
}

final class StrictJsonObjectException implements Exception {
  const StrictJsonObjectException(this.failure);

  final StrictJsonObjectFailure failure;
}

Map<String, dynamic> decodeStrictJsonObject(
  String source, {
  int? maxNestingDepth,
}) {
  assert(maxNestingDepth == null || maxNestingDepth >= 0);
  dynamic decoded;
  try {
    _DuplicateJsonMemberScanner(
      source,
      maxNestingDepth: maxNestingDepth,
    ).validate();
    decoded = jsonDecode(source);
  } on StrictJsonObjectException {
    rethrow;
  } on FormatException {
    throw const StrictJsonObjectException(StrictJsonObjectFailure.invalidJson);
  }
  if (decoded is! Map<String, dynamic>) {
    throw const StrictJsonObjectException(
      StrictJsonObjectFailure.objectRequired,
    );
  }
  if (_decodedValueFailure(decoded) case final failure?) {
    throw StrictJsonObjectException(failure);
  }
  return decoded;
}

StrictJsonObjectFailure? _decodedValueFailure(Object? value) {
  if (value is String) {
    final units = value.codeUnits;
    for (var index = 0; index < units.length; index++) {
      final unit = units[index];
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index >= units.length ||
            units[index] < 0xdc00 ||
            units[index] > 0xdfff) {
          return StrictJsonObjectFailure.invalidUnicode;
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        return StrictJsonObjectFailure.invalidUnicode;
      }
    }
    return null;
  }
  if (value is num && !value.isFinite) {
    return StrictJsonObjectFailure.nonFiniteNumber;
  }
  if (value is List<Object?>) {
    for (final item in value) {
      if (_decodedValueFailure(item) case final failure?) return failure;
    }
    return null;
  }
  if (value is Map<String, dynamic>) {
    for (final entry in value.entries) {
      if (_decodedValueFailure(entry.key) case final failure?) return failure;
      if (_decodedValueFailure(entry.value) case final failure?) return failure;
    }
  }
  return null;
}

final class _DuplicateJsonMemberScanner {
  _DuplicateJsonMemberScanner(this.source, {required this.maxNestingDepth});

  final String source;
  final int? maxNestingDepth;
  var _index = 0;
  var _depth = 0;

  void validate() {
    _skipWhitespace();
    _scanValue();
    _skipWhitespace();
    if (_index != source.length) throw const FormatException();
  }

  void _scanValue() {
    _skipWhitespace();
    if (_index >= source.length) throw const FormatException();
    switch (source.codeUnitAt(_index)) {
      case 0x7b:
        _scanObject();
      case 0x5b:
        _scanArray();
      case 0x22:
        _scanString();
      case 0x74:
        _scanLiteral('true');
      case 0x66:
        _scanLiteral('false');
      case 0x6e:
        _scanLiteral('null');
      default:
        _scanNumber();
    }
  }

  void _scanObject() {
    _enterContainer();
    _index++;
    _skipWhitespace();
    if (_consume(0x7d)) {
      _depth--;
      return;
    }
    final names = <String>{};
    while (true) {
      _skipWhitespace();
      final start = _index;
      _scanString();
      final name = jsonDecode(source.substring(start, _index)) as String;
      if (!names.add(name)) throw const FormatException();
      _skipWhitespace();
      if (!_consume(0x3a)) throw const FormatException();
      _scanValue();
      _skipWhitespace();
      if (_consume(0x7d)) {
        _depth--;
        return;
      }
      if (!_consume(0x2c)) throw const FormatException();
    }
  }

  void _scanArray() {
    _enterContainer();
    _index++;
    _skipWhitespace();
    if (_consume(0x5d)) {
      _depth--;
      return;
    }
    while (true) {
      _scanValue();
      _skipWhitespace();
      if (_consume(0x5d)) {
        _depth--;
        return;
      }
      if (!_consume(0x2c)) throw const FormatException();
    }
  }

  void _enterContainer() {
    _depth++;
    if (maxNestingDepth case final maximum? when _depth > maximum) {
      throw const StrictJsonObjectException(
        StrictJsonObjectFailure.nestingLimit,
      );
    }
  }

  void _scanString() {
    if (!_consume(0x22)) throw const FormatException();
    while (_index < source.length) {
      final unit = source.codeUnitAt(_index++);
      if (unit == 0x22) return;
      if (unit < 0x20) throw const FormatException();
      if (unit != 0x5c) continue;
      if (_index >= source.length) throw const FormatException();
      final escape = source.codeUnitAt(_index++);
      if (escape == 0x75) {
        for (var count = 0; count < 4; count++) {
          if (_index >= source.length || !_isHex(source.codeUnitAt(_index++))) {
            throw const FormatException();
          }
        }
      } else if (!const <int>{
        0x22,
        0x5c,
        0x2f,
        0x62,
        0x66,
        0x6e,
        0x72,
        0x74,
      }.contains(escape)) {
        throw const FormatException();
      }
    }
    throw const FormatException();
  }

  void _scanLiteral(String literal) {
    if (!source.startsWith(literal, _index)) throw const FormatException();
    _index += literal.length;
  }

  void _scanNumber() {
    _consume(0x2d);
    if (_index >= source.length) throw const FormatException();
    if (_consume(0x30)) {
      if (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        throw const FormatException();
      }
    } else {
      if (!_isOneToNine(source.codeUnitAt(_index))) {
        throw const FormatException();
      }
      _index++;
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }
    if (_consume(0x2e)) {
      if (_index >= source.length || !_isDigit(source.codeUnitAt(_index))) {
        throw const FormatException();
      }
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }
    if (_index < source.length &&
        (source.codeUnitAt(_index) == 0x65 ||
            source.codeUnitAt(_index) == 0x45)) {
      _index++;
      if (_index < source.length &&
          (source.codeUnitAt(_index) == 0x2b ||
              source.codeUnitAt(_index) == 0x2d)) {
        _index++;
      }
      if (_index >= source.length || !_isDigit(source.codeUnitAt(_index))) {
        throw const FormatException();
      }
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }
  }

  void _skipWhitespace() {
    while (_index < source.length &&
        const <int>{
          0x20,
          0x09,
          0x0a,
          0x0d,
        }.contains(source.codeUnitAt(_index))) {
      _index++;
    }
  }

  bool _consume(int unit) {
    if (_index >= source.length || source.codeUnitAt(_index) != unit) {
      return false;
    }
    _index++;
    return true;
  }

  static bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

  static bool _isOneToNine(int unit) => unit >= 0x31 && unit <= 0x39;

  static bool _isHex(int unit) =>
      _isDigit(unit) ||
      (unit >= 0x41 && unit <= 0x46) ||
      (unit >= 0x61 && unit <= 0x66);
}
