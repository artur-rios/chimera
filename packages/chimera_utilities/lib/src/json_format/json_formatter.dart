enum JsonFormatFailureKind { validation, resource }

final class JsonFormatException implements Exception {
  const JsonFormatException({
    required this.kind,
    required this.code,
    this.offset,
    this.reason,
  });

  final JsonFormatFailureKind kind;
  final String code;
  final int? offset;
  final String? reason;
}

final class JsonFormatRequest {
  const JsonFormatRequest({required this.source, required this.indent});

  final String source;
  final int indent;
}

final class JsonFormatResult {
  const JsonFormatResult({required this.formatted, required this.indent});

  final String formatted;
  final int indent;
}

final class JsonFormatter {
  const JsonFormatter({
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

  JsonFormatResult format(JsonFormatRequest request) {
    if (request.indent != 2 && request.indent != 4) {
      throw const JsonFormatException(
        kind: JsonFormatFailureKind.validation,
        code: 'json-format.invalid-indent',
      );
    }
    if (request.source.length > maxSourceChars) _throwResourceLimit();

    final formatted = _BoundedJsonFormatter(
      request.source,
      indent: request.indent,
      maxNodes: maxNodes,
      maxDepth: maxDepth,
      maxOutputChars: maxOutputChars,
    ).format();
    return JsonFormatResult(formatted: formatted, indent: request.indent);
  }

  Never _throwResourceLimit() => throw const JsonFormatException(
    kind: JsonFormatFailureKind.resource,
    code: 'json-format.resource-limit',
  );
}

final class _BoundedJsonFormatter {
  _BoundedJsonFormatter(
    this.source, {
    required this.indent,
    required this.maxNodes,
    required this.maxDepth,
    required int maxOutputChars,
  }) : _sink = _BoundedStringSink(maxOutputChars);

  final String source;
  final int indent;
  final int maxNodes;
  final int maxDepth;
  final _BoundedStringSink _sink;

  var _index = 0;
  var _nodes = 0;

  String format() {
    _skipWhitespace();
    _formatValue(0);
    _skipWhitespace();
    if (_index != source.length) _throwUnexpected();
    return _sink.toString();
  }

  void _formatValue(int depth) {
    if (depth > maxDepth || ++_nodes > maxNodes) _throwResourceLimit();
    if (_index >= source.length) _throwUnexpectedEnd();

    switch (source.codeUnitAt(_index)) {
      case 0x7B:
        _formatObject(depth);
      case 0x5B:
        _formatArray(depth);
      case 0x22:
        _formatString();
      case 0x74:
        _formatLiteral('true');
      case 0x66:
        _formatLiteral('false');
      case 0x6E:
        _formatLiteral('null');
      case 0x2D:
        _formatNumber();
      case >= 0x30 && <= 0x39:
        _formatNumber();
      default:
        _throwUnexpected();
    }
  }

  void _formatObject(int depth) {
    _index++;
    _sink.write('{');
    _skipWhitespace();
    if (_consumeIf(0x7D)) {
      _sink.write('}');
      return;
    }

    _sink.write('\n');
    while (true) {
      _writeIndent(depth + 1);
      if (_index >= source.length) _throwUnexpectedEnd();
      if (source.codeUnitAt(_index) != 0x22) _throwUnexpected();
      _formatString();
      _skipWhitespace();
      if (!_consumeIf(0x3A)) _throwUnexpected();
      _sink.write(': ');
      _skipWhitespace();
      _formatValue(depth + 1);
      _skipWhitespace();
      if (_consumeIf(0x7D)) {
        _sink.write('\n');
        _writeIndent(depth);
        _sink.write('}');
        return;
      }
      if (!_consumeIf(0x2C)) _throwUnexpected();
      _sink.write(',\n');
      _skipWhitespace();
    }
  }

  void _formatArray(int depth) {
    _index++;
    _sink.write('[');
    _skipWhitespace();
    if (_consumeIf(0x5D)) {
      _sink.write(']');
      return;
    }

    _sink.write('\n');
    while (true) {
      _writeIndent(depth + 1);
      _formatValue(depth + 1);
      _skipWhitespace();
      if (_consumeIf(0x5D)) {
        _sink.write('\n');
        _writeIndent(depth);
        _sink.write(']');
        return;
      }
      if (!_consumeIf(0x2C)) _throwUnexpected();
      _sink.write(',\n');
      _skipWhitespace();
    }
  }

  void _formatString() {
    _index++;
    _sink.write('"');
    while (_index < source.length) {
      final codeUnit = source.codeUnitAt(_index++);
      if (codeUnit == 0x22) {
        _sink.write('"');
        return;
      }
      if (codeUnit < 0x20) _throwUnexpected(_index - 1);
      if (codeUnit == 0x5C) {
        _sink.writeCharCode(codeUnit);
        _formatEscape();
        continue;
      }
      _sink.writeCharCode(codeUnit);
    }
    _throwUnexpectedEnd();
  }

  void _formatEscape() {
    if (_index >= source.length) _throwUnexpectedEnd();
    final escape = source.codeUnitAt(_index++);
    _sink.writeCharCode(escape);
    if (escape == 0x75) {
      _formatHexCodeUnit();
      return;
    }
    if (escape != 0x22 &&
        escape != 0x2F &&
        escape != 0x5C &&
        escape != 0x62 &&
        escape != 0x66 &&
        escape != 0x6E &&
        escape != 0x72 &&
        escape != 0x74) {
      _throwUnexpected(_index - 1);
    }
  }

  int _formatHexCodeUnit() {
    if (_index + 4 > source.length) _throwUnexpectedEnd();
    var value = 0;
    for (var offset = 0; offset < 4; offset++) {
      final codeUnit = source.codeUnitAt(_index++);
      final digit = _hexValue(codeUnit);
      if (digit < 0) _throwUnexpected(_index - 1);
      value = (value << 4) | digit;
      _sink.writeCharCode(codeUnit);
    }
    return value;
  }

  void _formatLiteral(String literal) {
    for (var offset = 0; offset < literal.length; offset++) {
      if (_index + offset >= source.length) _throwUnexpectedEnd();
      if (source.codeUnitAt(_index + offset) != literal.codeUnitAt(offset)) {
        _throwUnrecognized(_index + offset);
      }
    }
    _index += literal.length;
    _sink.write(literal);
  }

  void _formatNumber() {
    final start = _index;
    _consumeIf(0x2D);
    if (_index >= source.length) _throwUnexpectedEnd();

    if (_consumeIf(0x30)) {
      if (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _throwUnexpected();
      }
    } else {
      if (!_isDigitOneToNine(source.codeUnitAt(_index))) _throwUnexpected();
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }

    if (_consumeIf(0x2E)) {
      if (_index >= source.length) _throwUnexpectedEnd();
      if (!_isDigit(source.codeUnitAt(_index))) _throwUnexpected();
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }

    if (_index < source.length &&
        (source.codeUnitAt(_index) == 0x65 ||
            source.codeUnitAt(_index) == 0x45)) {
      _index++;
      if (_index < source.length &&
          (source.codeUnitAt(_index) == 0x2B ||
              source.codeUnitAt(_index) == 0x2D)) {
        _index++;
      }
      if (_index >= source.length) _throwUnexpectedEnd();
      if (!_isDigit(source.codeUnitAt(_index))) _throwUnexpected();
      while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _index++;
      }
    }

    for (var index = start; index < _index; index++) {
      _sink.writeCharCode(source.codeUnitAt(index));
    }
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

  void _writeIndent(int depth) => _sink.write(' ' * (depth * indent));

  Never _throwUnexpected([int? offset]) => throw JsonFormatException(
    kind: JsonFormatFailureKind.validation,
    code: 'json-format.invalid-json',
    offset: offset ?? _index,
    reason: 'unexpected-character',
  );

  Never _throwUnexpectedEnd() => throw JsonFormatException(
    kind: JsonFormatFailureKind.validation,
    code: 'json-format.invalid-json',
    offset: _index,
    reason: 'unexpected-end-of-input',
  );

  Never _throwUnrecognized(int offset) => throw JsonFormatException(
    kind: JsonFormatFailureKind.validation,
    code: 'json-format.invalid-json',
    offset: offset,
    reason: 'unrecognized-token',
  );

  Never _throwResourceLimit() => throw const JsonFormatException(
    kind: JsonFormatFailureKind.resource,
    code: 'json-format.resource-limit',
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
      throw const JsonFormatException(
        kind: JsonFormatFailureKind.resource,
        code: 'json-format.resource-limit',
      );
    }
    _length += length;
  }

  @override
  String toString() => _buffer.toString();
}
