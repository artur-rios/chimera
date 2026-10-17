import 'dart:convert';

enum TextEscapeFailureKind { validation, resource }

final class TextEscapeException implements Exception {
  const TextEscapeException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final TextEscapeFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class TextEscapeRequest {
  const TextEscapeRequest({required this.input, required this.mode});

  final String input;
  final String mode;
}

final class TextEscapeResult {
  const TextEscapeResult({required this.escaped, required this.mode});

  final String escaped;
  final String mode;
}

final class TextEscaper {
  const TextEscaper({this.maxInputCharacters, this.maxOutputCharacters})
    : assert(
        maxInputCharacters == null || maxInputCharacters >= 0,
        'maxInputCharacters must not be negative',
      ),
      assert(
        maxOutputCharacters == null || maxOutputCharacters >= 0,
        'maxOutputCharacters must not be negative',
      );

  static const List<String> supportedModes = <String>[
    'json',
    'unicode',
    'c',
    'html',
    'url',
  ];

  final int? maxInputCharacters;
  final int? maxOutputCharacters;

  TextEscapeResult escape(TextEscapeRequest request) {
    if (!supportedModes.contains(request.mode)) {
      throw const TextEscapeException(
        kind: TextEscapeFailureKind.validation,
        code: 'text-escape.invalid-mode',
        field: 'mode',
        reason: 'unsupported-mode',
      );
    }
    if (maxInputCharacters case final maximum?
        when request.input.length > maximum) {
      _throwResourceLimit(field: 'input', reason: 'input-limit');
    }

    try {
      final writer = _EscapeWriter(maxOutputCharacters);
      switch (request.mode) {
        case 'json':
          _escapeJson(request.input, writer);
        case 'unicode':
          _escapeUnicode(request.input, writer);
        case 'c':
          _escapeC(request.input, writer);
        case 'html':
          _escapeHtml(request.input, writer);
        case 'url':
          _escapeUrl(request.input, writer);
      }
      return TextEscapeResult(escaped: writer.result, mode: request.mode);
    } on TextEscapeException {
      rethrow;
    } on OutOfMemoryError {
      _throwResourceLimit(field: 'escaped', reason: 'output-limit');
    }
  }

  void _escapeJson(String input, _EscapeWriter writer) {
    for (final unit in input.codeUnits) {
      switch (unit) {
        case 0x22:
          writer.write(r'\"');
        case 0x5C:
          writer.write(r'\\');
        case 0x08:
          writer.write(r'\b');
        case 0x0C:
          writer.write(r'\f');
        case 0x0A:
          writer.write(r'\n');
        case 0x0D:
          writer.write(r'\r');
        case 0x09:
          writer.write(r'\t');
        default:
          if (unit < 0x20) {
            writer.write('\\u${_hex(unit, 4)}');
          } else {
            writer.writeCharCode(unit);
          }
      }
    }
  }

  void _escapeUnicode(String input, _EscapeWriter writer) {
    for (final unit in input.codeUnits) {
      writer.write('\\u${_hex(unit, 4)}');
    }
  }

  void _escapeC(String input, _EscapeWriter writer) {
    for (final unit in input.codeUnits) {
      switch (unit) {
        case 0x5C:
          writer.write(r'\\');
        case 0x27:
          writer.write(r"\'");
        case 0x22:
          writer.write(r'\"');
        case 0x07:
          writer.write(r'\a');
        case 0x08:
          writer.write(r'\b');
        case 0x0C:
          writer.write(r'\f');
        case 0x0A:
          writer.write(r'\n');
        case 0x0D:
          writer.write(r'\r');
        case 0x09:
          writer.write(r'\t');
        case 0x0B:
          writer.write(r'\v');
        case 0x00:
          writer.write(r'\0');
        default:
          if (unit < 0x20 || unit == 0x7F) {
            writer.write('\\x${_hex(unit, 2)}');
          } else {
            writer.writeCharCode(unit);
          }
      }
    }
  }

  void _escapeHtml(String input, _EscapeWriter writer) {
    for (final unit in input.codeUnits) {
      switch (unit) {
        case 0x26:
          writer.write('&amp;');
        case 0x3C:
          writer.write('&lt;');
        case 0x3E:
          writer.write('&gt;');
        case 0x22:
          writer.write('&quot;');
        case 0x27:
          writer.write('&#39;');
        default:
          writer.writeCharCode(unit);
      }
    }
  }

  void _escapeUrl(String input, _EscapeWriter writer) {
    for (final byte in utf8.encode(input)) {
      if (_isUnreserved(byte)) {
        writer.writeCharCode(byte);
      } else {
        writer.write('%${_hex(byte, 2)}');
      }
    }
  }

  bool _isUnreserved(int byte) =>
      byte >= 0x41 && byte <= 0x5A ||
      byte >= 0x61 && byte <= 0x7A ||
      byte >= 0x30 && byte <= 0x39 ||
      byte == 0x2D ||
      byte == 0x2E ||
      byte == 0x5F ||
      byte == 0x7E;

  String _hex(int value, int width) =>
      value.toRadixString(16).toUpperCase().padLeft(width, '0');

  Never _throwResourceLimit({required String field, required String reason}) =>
      throw TextEscapeException(
        kind: TextEscapeFailureKind.resource,
        code: 'text-escape.resource-limit',
        field: field,
        reason: reason,
      );
}

final class _EscapeWriter {
  _EscapeWriter(this.maximumLength);

  final int? maximumLength;
  final StringBuffer _buffer = StringBuffer();
  int _length = 0;

  void write(String value) {
    _reserve(value.length);
    _buffer.write(value);
  }

  void writeCharCode(int codeUnit) {
    _reserve(1);
    _buffer.writeCharCode(codeUnit);
  }

  String get result => _buffer.toString();

  void _reserve(int length) {
    final maximum = maximumLength;
    if (maximum != null && _length + length > maximum) {
      throw const TextEscapeException(
        kind: TextEscapeFailureKind.resource,
        code: 'text-escape.resource-limit',
        field: 'escaped',
        reason: 'output-limit',
      );
    }
    _length += length;
  }
}
