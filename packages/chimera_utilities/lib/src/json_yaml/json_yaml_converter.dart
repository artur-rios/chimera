import 'package:yaml_writer/yaml_writer.dart';

enum JsonYamlFailureKind { validation, resource }

final class JsonYamlException implements Exception {
  const JsonYamlException({
    required this.kind,
    required this.code,
    this.offset,
  });

  final JsonYamlFailureKind kind;
  final String code;
  final int? offset;
}

final class JsonYamlRequest {
  const JsonYamlRequest({
    required this.source,
    required this.indent,
    required this.quoteStrings,
  });

  final String source;
  final int indent;
  final bool quoteStrings;
}

final class JsonYamlResult {
  const JsonYamlResult({
    required this.yaml,
    required this.indent,
    required this.quoteStrings,
  });

  final String yaml;
  final int indent;
  final bool quoteStrings;
}

final class JsonYamlConverter {
  const JsonYamlConverter({
    this.maxSourceChars = 4000000,
    this.maxNodes = 100000,
    this.maxDepth = 100,
    this.maxOutputChars = 4000000,
  }) : assert(maxSourceChars >= 0, 'maxSourceChars must not be negative'),
       assert(maxNodes >= 0, 'maxNodes must not be negative'),
       assert(maxDepth >= 0, 'maxDepth must not be negative'),
       assert(maxOutputChars >= 0, 'maxOutputChars must not be negative');

  final int maxSourceChars;
  final int maxNodes;
  final int maxDepth;
  final int maxOutputChars;

  JsonYamlResult convert(JsonYamlRequest request) {
    if (request.indent != 2 && request.indent != 4) {
      throw const JsonYamlException(
        kind: JsonYamlFailureKind.validation,
        code: 'json-yaml.invalid-indent',
      );
    }
    if (request.source.length > maxSourceChars) _throwResourceLimit();

    final decoded = _BoundedJsonParser(
      request.source,
      maxNodes: maxNodes,
      maxDepth: maxDepth,
    ).parse();
    final yaml = _BoundedYamlEmitter(
      indent: request.indent,
      quoteStrings: request.quoteStrings,
      maxOutputChars: maxOutputChars,
    ).write(decoded);

    return JsonYamlResult(
      yaml: yaml,
      indent: request.indent,
      quoteStrings: request.quoteStrings,
    );
  }

  Never _throwResourceLimit() => throw const JsonYamlException(
    kind: JsonYamlFailureKind.resource,
    code: 'json-yaml.resource-limit',
  );
}

final class _BoundedJsonParser {
  _BoundedJsonParser(
    this.source, {
    required this.maxNodes,
    required this.maxDepth,
  });

  final String source;
  final int maxNodes;
  final int maxDepth;

  var _index = 0;
  var _nodes = 0;

  Object? parse() {
    _skipWhitespace();
    final result = _parseValue(0);
    _skipWhitespace();
    if (_index != source.length) _throwInvalidJson();
    return result;
  }

  Object? _parseValue(int depth) {
    if (depth > maxDepth || ++_nodes > maxNodes) _throwResourceLimit();
    if (_index >= source.length) _throwInvalidJson();

    return switch (source.codeUnitAt(_index)) {
      0x7B => _parseObject(depth),
      0x5B => _parseArray(depth),
      0x22 => _parseString(),
      0x74 => _parseLiteral('true', true),
      0x66 => _parseLiteral('false', false),
      0x6E => _parseLiteral('null', null),
      0x2D => _parseNumber(),
      >= 0x30 && <= 0x39 => _parseNumber(),
      _ => _throwInvalidJson(),
    };
  }

  Map<String, Object?> _parseObject(int depth) {
    _index++;
    _skipWhitespace();
    final result = <String, Object?>{};
    if (_consumeIf(0x7D)) return result;

    while (true) {
      if (_index >= source.length || source.codeUnitAt(_index) != 0x22) {
        _throwInvalidJson();
      }
      final key = _parseString();
      _skipWhitespace();
      if (!_consumeIf(0x3A)) _throwInvalidJson();
      _skipWhitespace();
      result[key] = _parseValue(depth + 1);
      _skipWhitespace();
      if (_consumeIf(0x7D)) return result;
      if (!_consumeIf(0x2C)) _throwInvalidJson();
      _skipWhitespace();
    }
  }

  List<Object?> _parseArray(int depth) {
    _index++;
    _skipWhitespace();
    final result = <Object?>[];
    if (_consumeIf(0x5D)) return result;

    while (true) {
      result.add(_parseValue(depth + 1));
      _skipWhitespace();
      if (_consumeIf(0x5D)) return result;
      if (!_consumeIf(0x2C)) _throwInvalidJson();
      _skipWhitespace();
    }
  }

  String _parseString() {
    _index++;
    final result = StringBuffer();
    while (_index < source.length) {
      final codeUnit = source.codeUnitAt(_index++);
      if (codeUnit == 0x22) return result.toString();
      if (codeUnit < 0x20) _throwInvalidJson(_index - 1);
      if (codeUnit != 0x5C) {
        result.writeCharCode(codeUnit);
        continue;
      }
      if (_index >= source.length) _throwInvalidJson();
      final escape = source.codeUnitAt(_index++);
      switch (escape) {
        case 0x22:
        case 0x2F:
        case 0x5C:
          result.writeCharCode(escape);
        case 0x62:
          result.writeCharCode(0x08);
        case 0x66:
          result.writeCharCode(0x0C);
        case 0x6E:
          result.writeCharCode(0x0A);
        case 0x72:
          result.writeCharCode(0x0D);
        case 0x74:
          result.writeCharCode(0x09);
        case 0x75:
          _writeUnicodeEscape(result);
        default:
          _throwInvalidJson(_index - 1);
      }
    }
    _throwInvalidJson();
  }

  void _writeUnicodeEscape(StringBuffer result) {
    final first = _readHexCodeUnit();
    if (first >= 0xD800 && first <= 0xDBFF) {
      if (_index + 2 > source.length ||
          source.codeUnitAt(_index) != 0x5C ||
          source.codeUnitAt(_index + 1) != 0x75) {
        _throwInvalidJson();
      }
      _index += 2;
      final second = _readHexCodeUnit();
      if (second < 0xDC00 || second > 0xDFFF) _throwInvalidJson(_index - 4);
      result
        ..writeCharCode(first)
        ..writeCharCode(second);
      return;
    }
    if (first >= 0xDC00 && first <= 0xDFFF) _throwInvalidJson(_index - 4);
    result.writeCharCode(first);
  }

  int _readHexCodeUnit() {
    if (_index + 4 > source.length) _throwInvalidJson();
    var value = 0;
    for (var offset = 0; offset < 4; offset++) {
      final digit = _hexValue(source.codeUnitAt(_index + offset));
      if (digit < 0) _throwInvalidJson(_index + offset);
      value = (value << 4) | digit;
    }
    _index += 4;
    return value;
  }

  Object? _parseLiteral(String literal, Object? value) {
    if (_index + literal.length > source.length ||
        source.substring(_index, _index + literal.length) != literal) {
      _throwInvalidJson();
    }
    _index += literal.length;
    return value;
  }

  num _parseNumber() {
    final start = _index;
    _consumeIf(0x2D);
    _checkNumberLength(start);
    if (_index >= source.length) _throwInvalidJson();

    final integerStart = _index;
    if (_consumeIf(0x30)) {
      if (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _throwInvalidJson();
      }
    } else {
      if (!_isDigitOneToNine(source.codeUnitAt(_index))) _throwInvalidJson();
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
        _checkNumberLength(start);
      }
    }
    final integerEnd = _index;

    var fractional = false;
    if (_consumeIf(0x2E)) {
      fractional = true;
      _checkNumberLength(start);
      if (_index >= source.length || !_isDigit(source.codeUnitAt(_index))) {
        _throwInvalidJson();
      }
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
        _checkNumberLength(start);
      }
    }
    final coefficientEnd = _index;

    var exponential = false;
    if (_index < source.length &&
        (source.codeUnitAt(_index) == 0x65 ||
            source.codeUnitAt(_index) == 0x45)) {
      exponential = true;
      _index++;
      _checkNumberLength(start);
      if (_index < source.length &&
          (source.codeUnitAt(_index) == 0x2B ||
              source.codeUnitAt(_index) == 0x2D)) {
        _index++;
        _checkNumberLength(start);
      }
      if (_index >= source.length || !_isDigit(source.codeUnitAt(_index))) {
        _throwInvalidJson();
      }
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
        _checkNumberLength(start);
      }
    }

    if (!fractional && !exponential) {
      const maximumSafeInteger = '9007199254740991';
      if (integerEnd - integerStart > maximumSafeInteger.length) {
        _throwUnsupportedNumber(start);
      }
      final digits = source.substring(integerStart, integerEnd);
      if (digits.length == maximumSafeInteger.length &&
          digits.compareTo(maximumSafeInteger) > 0) {
        _throwUnsupportedNumber(start);
      }
      return int.parse(source.substring(start, integerEnd));
    }

    final lexeme = source.substring(start, _index);
    final value = double.parse(lexeme);
    var coefficientIndex = 0;
    var firstNonZero = -1;
    var lastNonZero = -1;
    for (var index = integerStart; index < coefficientEnd; index++) {
      final codeUnit = source.codeUnitAt(index);
      if (codeUnit == 0x2E) continue;
      if (codeUnit != 0x30) {
        firstNonZero = firstNonZero < 0 ? coefficientIndex : firstNonZero;
        lastNonZero = coefficientIndex;
      }
      coefficientIndex++;
    }
    final meaningfulDigits = firstNonZero < 0
        ? 0
        : lastNonZero - firstNonZero + 1;
    if (!value.isFinite ||
        (value == 0 && meaningfulDigits > 0) ||
        meaningfulDigits > 15) {
      _throwUnsupportedNumber(start);
    }
    return value;
  }

  void _checkNumberLength(int start) {
    if (_index - start > _maximumNumberChars) _throwResourceLimit();
  }

  void _skipWhitespace() {
    while (_index < source.length) {
      final codeUnit = source.codeUnitAt(_index);
      if (codeUnit != 0x20 &&
          codeUnit != 0x09 &&
          codeUnit != 0x0A &&
          codeUnit != 0x0D) {
        return;
      }
      _index++;
    }
  }

  bool _consumeIf(int codeUnit) {
    if (_index >= source.length || source.codeUnitAt(_index) != codeUnit) {
      return false;
    }
    _index++;
    return true;
  }

  Never _throwInvalidJson([int? offset]) => throw JsonYamlException(
    kind: JsonYamlFailureKind.validation,
    code: 'json-yaml.invalid-json',
    offset: offset ?? _index,
  );

  Never _throwUnsupportedNumber(int offset) => throw JsonYamlException(
    kind: JsonYamlFailureKind.validation,
    code: 'json-yaml.unsupported-number',
    offset: offset,
  );

  Never _throwResourceLimit() => throw const JsonYamlException(
    kind: JsonYamlFailureKind.resource,
    code: 'json-yaml.resource-limit',
  );

  bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  bool _isDigitOneToNine(int codeUnit) => codeUnit >= 0x31 && codeUnit <= 0x39;

  int _hexValue(int codeUnit) {
    if (codeUnit >= 0x30 && codeUnit <= 0x39) return codeUnit - 0x30;
    if (codeUnit >= 0x41 && codeUnit <= 0x46) return codeUnit - 0x41 + 10;
    if (codeUnit >= 0x61 && codeUnit <= 0x66) return codeUnit - 0x61 + 10;
    return -1;
  }
}

const _maximumNumberChars = 1024;

final class _BoundedYamlEmitter {
  _BoundedYamlEmitter({
    required this.indent,
    required this.quoteStrings,
    required this.maxOutputChars,
  });

  final int indent;
  final bool quoteStrings;
  final int maxOutputChars;

  late final _BoundedStringSink _sink = _BoundedStringSink(maxOutputChars);

  String write(Object? value) {
    _writeValue(value, 0);
    return _sink.toString();
  }

  void _writeValue(Object? value, int depth) {
    switch (value) {
      case Map<String, Object?>():
        _writeMap(value, depth);
      case List<Object?>():
        _writeList(value, depth);
      case String():
        _writeString(value, forceQuote: quoteStrings);
      default:
        _writePrimitive(value);
    }
  }

  void _writeMap(Map<String, Object?> value, int depth) {
    if (value.isEmpty) {
      _sink.write('{}');
      return;
    }
    var first = true;
    for (final entry in value.entries) {
      if (!first) _sink.write('\n');
      first = false;
      _writeIndent(depth);
      _writeString(entry.key, forceQuote: false);
      _sink.write(':');
      if (_isNonEmptyCollection(entry.value)) {
        _sink.write('\n');
        _writeValue(entry.value, depth + 1);
      } else {
        _sink.write(' ');
        _writeValue(entry.value, depth + 1);
      }
    }
  }

  void _writeList(List<Object?> value, int depth) {
    if (value.isEmpty) {
      _sink.write('[]');
      return;
    }
    for (var index = 0; index < value.length; index++) {
      if (index > 0) _sink.write('\n');
      _writeIndent(depth);
      _sink.write('-');
      final item = value[index];
      if (_isNonEmptyCollection(item)) {
        _sink.write('\n');
        _writeValue(item, depth + 1);
      } else {
        _sink.write(' ');
        _writeValue(item, depth + 1);
      }
    }
  }

  bool _isNonEmptyCollection(Object? value) => switch (value) {
    Map<String, Object?>() => value.isNotEmpty,
    List<Object?>() => value.isNotEmpty,
    _ => false,
  };

  void _writeIndent(int depth) => _sink.write(' ' * (depth * indent));

  void _writeString(String value, {required bool forceQuote}) {
    if (!forceQuote && _isSafePlainScalar(value)) {
      _sink.write(value);
      return;
    }

    _sink.write('"');
    for (final codeUnit in value.codeUnits) {
      switch (codeUnit) {
        case 0x22:
          _sink.write(r'\"');
        case 0x5C:
          _sink.write(r'\\');
        case 0x08:
          _sink.write(r'\b');
        case 0x0C:
          _sink.write(r'\f');
        case 0x0A:
          _sink.write(r'\n');
        case 0x0D:
          _sink.write(r'\r');
        case 0x09:
          _sink.write(r'\t');
        case < 0x20 || (>= 0x7F && <= 0x9F) || 0x2028 || 0x2029:
          _sink.write('\\u${codeUnit.toRadixString(16).padLeft(4, '0')}');
        default:
          _sink.writeCharCode(codeUnit);
      }
    }
    _sink.write('"');
  }

  bool _isSafePlainScalar(String value) {
    if (value.isEmpty || value.trim() != value) return false;
    final first = value.codeUnitAt(0);
    if (!_isAsciiLetter(first)) return false;
    for (final codeUnit in value.codeUnits) {
      if (!_isAsciiLetter(codeUnit) &&
          !_isAsciiDigit(codeUnit) &&
          codeUnit != 0x20 &&
          codeUnit != 0x2D &&
          codeUnit != 0x2E &&
          codeUnit != 0x2F &&
          codeUnit != 0x5F) {
        return false;
      }
    }
    return !_yamlNativeWords.contains(value.toLowerCase());
  }

  bool _isAsciiLetter(int codeUnit) =>
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A);

  bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  void _writePrimitive(Object? value) {
    final encoded = YamlWriter.config(
      config: const YamlWriterConfig(
        indentSize: 2,
        quoteStyle: QuoteStyle.doubleQuote,
      ),
    ).write(value);
    _sink.write(
      encoded.endsWith('\n')
          ? encoded.substring(0, encoded.length - 1)
          : encoded,
    );
  }
}

const _yamlNativeWords = <String>{
  'null',
  'true',
  'false',
  'yes',
  'no',
  'on',
  'off',
  'y',
  'n',
  '.nan',
  '.inf',
  '+.inf',
  '-.inf',
};

final class _BoundedStringSink {
  _BoundedStringSink(this.maximumLength);

  final int maximumLength;
  final _buffer = StringBuffer();
  var _length = 0;

  void write(String value) {
    _reserve(value.length);
    _buffer.write(value);
  }

  void writeCharCode(int codeUnit) {
    _reserve(1);
    _buffer.writeCharCode(codeUnit);
  }

  void _reserve(int length) {
    if (_length + length > maximumLength) {
      throw const JsonYamlException(
        kind: JsonYamlFailureKind.resource,
        code: 'json-yaml.resource-limit',
      );
    }
    _length += length;
  }

  @override
  String toString() => _buffer.toString();
}
