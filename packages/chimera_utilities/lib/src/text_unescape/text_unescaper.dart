import 'dart:convert';

enum TextUnescapeFailureKind { validation, resource }

final class TextUnescapeException implements Exception {
  const TextUnescapeException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
    this.offset,
  });

  final TextUnescapeFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
  final int? offset;
}

final class TextUnescapeRequest {
  const TextUnescapeRequest({required this.input, required this.mode});

  final String input;
  final String mode;
}

final class TextUnescapeResult {
  const TextUnescapeResult({required this.unescaped, required this.mode});

  final String unescaped;
  final String mode;
}

final class TextUnescaper {
  const TextUnescaper({this.maxInputCharacters, this.maxOutputCharacters})
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

  TextUnescapeResult unescape(TextUnescapeRequest request) {
    if (!supportedModes.contains(request.mode)) {
      throw const TextUnescapeException(
        kind: TextUnescapeFailureKind.validation,
        code: 'text-unescape.invalid-mode',
        field: 'mode',
        reason: 'unsupported-mode',
      );
    }
    if (maxInputCharacters case final maximum?
        when request.input.length > maximum) {
      _throwResourceLimit(field: 'input', reason: 'input-limit');
    }

    try {
      final writer = _UnescapeWriter(maxOutputCharacters);
      switch (request.mode) {
        case 'json':
          _unescapeJson(request.input, writer);
        case 'unicode':
          _unescapeUnicode(request.input, writer);
        case 'c':
          _unescapeC(request.input, writer);
        case 'html':
          _unescapeHtml(request.input, writer);
        case 'url':
          _unescapeUrl(request.input, writer);
      }
      return TextUnescapeResult(unescaped: writer.result, mode: request.mode);
    } on TextUnescapeException {
      rethrow;
    } on OutOfMemoryError {
      _throwResourceLimit(field: 'unescaped', reason: 'output-limit');
    }
  }

  void _unescapeJson(String input, _UnescapeWriter writer) {
    var offset = 0;
    while (offset < input.length) {
      final unit = input.codeUnitAt(offset);
      if (unit < 0x20) {
        _throwMalformed(reason: 'unescaped-control', offset: offset);
      }
      if (unit != 0x5C) {
        writer.writeCharCode(unit);
        offset += 1;
        continue;
      }

      final start = offset;
      if (++offset >= input.length) {
        _throwMalformed(reason: 'incomplete-sequence', offset: start);
      }
      switch (input.codeUnitAt(offset)) {
        case 0x22:
          writer.writeCharCode(0x22);
        case 0x5C:
          writer.writeCharCode(0x5C);
        case 0x2F:
          writer.writeCharCode(0x2F);
        case 0x62:
          writer.writeCharCode(0x08);
        case 0x66:
          writer.writeCharCode(0x0C);
        case 0x6E:
          writer.writeCharCode(0x0A);
        case 0x72:
          writer.writeCharCode(0x0D);
        case 0x74:
          writer.writeCharCode(0x09);
        case 0x75:
          writer.writeCharCode(
            _readHex(input, offset + 1, 4, sequenceOffset: start),
          );
          offset += 4;
        default:
          _throwMalformed(reason: 'unknown-escape', offset: start);
      }
      offset += 1;
    }
  }

  void _unescapeUnicode(String input, _UnescapeWriter writer) {
    var offset = 0;
    while (offset < input.length) {
      if (input.codeUnitAt(offset) != 0x5C) {
        writer.writeCharCode(input.codeUnitAt(offset));
        offset += 1;
        continue;
      }

      final start = offset;
      if (++offset >= input.length) {
        _throwMalformed(reason: 'incomplete-sequence', offset: start);
      }
      switch (input.codeUnitAt(offset)) {
        case 0x75:
          writer.writeCharCode(
            _readHex(input, offset + 1, 4, sequenceOffset: start),
          );
          offset += 5;
        case 0x55:
          final scalar = _readHex(input, offset + 1, 8, sequenceOffset: start);
          _validateScalar(scalar, start);
          writer.writeRune(scalar);
          offset += 9;
        default:
          _throwMalformed(reason: 'unknown-escape', offset: start);
      }
    }
  }

  void _unescapeC(String input, _UnescapeWriter writer) {
    var offset = 0;
    while (offset < input.length) {
      if (input.codeUnitAt(offset) != 0x5C) {
        writer.writeCharCode(input.codeUnitAt(offset));
        offset += 1;
        continue;
      }

      final start = offset;
      if (++offset >= input.length) {
        _throwMalformed(reason: 'incomplete-sequence', offset: start);
      }
      final marker = input.codeUnitAt(offset);
      final short = switch (marker) {
        0x5C => 0x5C,
        0x27 => 0x27,
        0x22 => 0x22,
        0x3F => 0x3F,
        0x61 => 0x07,
        0x62 => 0x08,
        0x66 => 0x0C,
        0x6E => 0x0A,
        0x72 => 0x0D,
        0x74 => 0x09,
        0x76 => 0x0B,
        _ => null,
      };
      if (short != null) {
        writer.writeCharCode(short);
        offset += 1;
        continue;
      }
      if (_isOctal(marker)) {
        var end = offset;
        while (end < input.length &&
            end < offset + 3 &&
            _isOctal(input.codeUnitAt(end))) {
          end += 1;
        }
        final value = int.parse(input.substring(offset, end), radix: 8);
        if (value > 0xFF) {
          _throwMalformed(reason: 'out-of-range', offset: start);
        }
        writer.writeCharCode(value);
        offset = end;
        continue;
      }
      switch (marker) {
        case 0x78:
          writer.writeCharCode(
            _readHex(input, offset + 1, 2, sequenceOffset: start),
          );
          offset += 3;
        case 0x75:
          writer.writeCharCode(
            _readHex(input, offset + 1, 4, sequenceOffset: start),
          );
          offset += 5;
        case 0x55:
          final scalar = _readHex(input, offset + 1, 8, sequenceOffset: start);
          _validateScalar(scalar, start);
          writer.writeRune(scalar);
          offset += 9;
        default:
          _throwMalformed(reason: 'unknown-escape', offset: start);
      }
    }
  }

  void _unescapeHtml(String input, _UnescapeWriter writer) {
    var offset = 0;
    while (offset < input.length) {
      if (input.codeUnitAt(offset) != 0x26) {
        writer.writeCharCode(input.codeUnitAt(offset));
        offset += 1;
        continue;
      }

      final start = offset;
      final end = input.indexOf(';', offset + 1);
      if (end < 0) {
        _throwMalformed(reason: 'unterminated-entity', offset: start);
      }
      final body = input.substring(offset + 1, end);
      final named = switch (body) {
        'amp' => 0x26,
        'lt' => 0x3C,
        'gt' => 0x3E,
        'quot' => 0x22,
        'apos' => 0x27,
        _ => null,
      };
      if (named != null) {
        writer.writeCharCode(named);
      } else if (body.startsWith('#')) {
        final hexadecimal =
            body.length > 1 &&
            (body.codeUnitAt(1) == 0x78 || body.codeUnitAt(1) == 0x58);
        final digits = body.substring(hexadecimal ? 2 : 1);
        final scalar = digits.isEmpty
            ? null
            : int.tryParse(digits, radix: hexadecimal ? 16 : 10);
        if (scalar == null) {
          _throwMalformed(reason: 'invalid-number', offset: start);
        }
        _validateScalar(scalar, start);
        writer.writeRune(scalar);
      } else {
        _throwMalformed(reason: 'unknown-entity', offset: start);
      }
      offset = end + 1;
    }
  }

  void _unescapeUrl(String input, _UnescapeWriter writer) {
    final bytes = <int>[];
    final offsets = <int>[];
    var offset = 0;
    while (offset < input.length) {
      if (input.codeUnitAt(offset) == 0x25) {
        if (offset + 2 >= input.length) {
          _throwMalformed(reason: 'incomplete-percent', offset: offset);
        }
        bytes.add(_readHex(input, offset + 1, 2, sequenceOffset: offset));
        offsets.add(offset);
        offset += 3;
        continue;
      }

      final start = offset;
      final first = input.codeUnitAt(offset);
      final width =
          first >= 0xD800 &&
              first <= 0xDBFF &&
              offset + 1 < input.length &&
              input.codeUnitAt(offset + 1) >= 0xDC00 &&
              input.codeUnitAt(offset + 1) <= 0xDFFF
          ? 2
          : 1;
      final encoded = utf8.encode(input.substring(offset, offset + width));
      bytes.addAll(encoded);
      offsets.addAll(List<int>.filled(encoded.length, start));
      offset += width;
    }

    var byteOffset = 0;
    while (byteOffset < bytes.length) {
      final leadOffset = byteOffset;
      final first = bytes[byteOffset];
      int scalar;
      int continuationCount;
      if (first <= 0x7F) {
        scalar = first;
        continuationCount = 0;
      } else if (first >= 0xC2 && first <= 0xDF) {
        scalar = first & 0x1F;
        continuationCount = 1;
      } else if (first >= 0xE0 && first <= 0xEF) {
        scalar = first & 0x0F;
        continuationCount = 2;
      } else if (first >= 0xF0 && first <= 0xF4) {
        scalar = first & 0x07;
        continuationCount = 3;
      } else {
        _throwMalformed(reason: 'invalid-utf8', offset: offsets[leadOffset]);
      }
      if (byteOffset + continuationCount >= bytes.length) {
        _throwMalformed(reason: 'invalid-utf8', offset: offsets[leadOffset]);
      }
      for (var index = 1; index <= continuationCount; index += 1) {
        final continuation = bytes[byteOffset + index];
        if (continuation < 0x80 || continuation > 0xBF) {
          _throwMalformed(reason: 'invalid-utf8', offset: offsets[leadOffset]);
        }
        scalar = (scalar << 6) | (continuation & 0x3F);
      }
      final overlong =
          continuationCount == 2 && scalar < 0x800 ||
          continuationCount == 3 && scalar < 0x10000;
      if (overlong ||
          scalar > 0x10FFFF ||
          scalar >= 0xD800 && scalar <= 0xDFFF) {
        _throwMalformed(reason: 'invalid-utf8', offset: offsets[leadOffset]);
      }
      writer.writeRune(scalar);
      byteOffset += continuationCount + 1;
    }
  }

  int _readHex(
    String input,
    int offset,
    int length, {
    required int sequenceOffset,
  }) {
    if (offset + length > input.length) {
      _throwMalformed(reason: 'incomplete-sequence', offset: sequenceOffset);
    }
    final value = int.tryParse(
      input.substring(offset, offset + length),
      radix: 16,
    );
    if (value == null) {
      _throwMalformed(reason: 'invalid-hex', offset: sequenceOffset);
    }
    return value;
  }

  bool _isOctal(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x37;

  void _validateScalar(int scalar, int offset) {
    if (scalar > 0x10FFFF) {
      _throwMalformed(reason: 'out-of-range', offset: offset);
    }
    if (scalar >= 0xD800 && scalar <= 0xDFFF) {
      _throwMalformed(reason: 'surrogate-scalar', offset: offset);
    }
  }

  Never _throwMalformed({required String reason, required int offset}) =>
      throw TextUnescapeException(
        kind: TextUnescapeFailureKind.validation,
        code: 'text-unescape.malformed-input',
        field: 'input',
        reason: reason,
        offset: offset,
      );

  Never _throwResourceLimit({required String field, required String reason}) =>
      throw TextUnescapeException(
        kind: TextUnescapeFailureKind.resource,
        code: 'text-unescape.resource-limit',
        field: field,
        reason: reason,
      );
}

final class _UnescapeWriter {
  _UnescapeWriter(this.maximumLength);

  final int? maximumLength;
  final StringBuffer _buffer = StringBuffer();
  int _length = 0;

  void writeCharCode(int codeUnit) {
    _reserve(1);
    _buffer.writeCharCode(codeUnit);
  }

  void writeRune(int rune) {
    final value = String.fromCharCode(rune);
    _reserve(value.length);
    _buffer.write(value);
  }

  String get result => _buffer.toString();

  void _reserve(int length) {
    final maximum = maximumLength;
    if (maximum != null && _length + length > maximum) {
      throw const TextUnescapeException(
        kind: TextUnescapeFailureKind.resource,
        code: 'text-unescape.resource-limit',
        field: 'unescaped',
        reason: 'output-limit',
      );
    }
    _length += length;
  }
}
