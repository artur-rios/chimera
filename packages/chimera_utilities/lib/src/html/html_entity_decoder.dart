import 'dart:convert';

import 'package:meta/meta.dart';

enum HtmlEntityDecodeFailureKind { validation, resource }

/// Safe failure details, without source, output, or dependency exceptions.
final class HtmlEntityDecodeException implements Exception {
  const HtmlEntityDecodeException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
    this.offset,
  });

  final HtmlEntityDecodeFailureKind kind;
  final String code;
  final String field;
  final String reason;
  final int? offset;
}

final class HtmlEntityDecodeRequest {
  const HtmlEntityDecodeRequest({required this.input});

  final String input;
}

final class HtmlEntityDecodeResult {
  const HtmlEntityDecodeResult({required this.decoded});

  final String decoded;
}

/// Stateless strict decoding for HTML character references.
final class HtmlEntityDecoder {
  const HtmlEntityDecoder({this.maxInputCharacters, this.maxOutputCharacters})
    : _convert = _decodeHtml,
      assert(maxInputCharacters == null || maxInputCharacters >= 0),
      assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  @visibleForTesting
  const HtmlEntityDecoder.forTesting({
    this.maxInputCharacters,
    this.maxOutputCharacters,
    this._convert = _decodeHtml,
  }) : assert(maxInputCharacters == null || maxInputCharacters >= 0),
       assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  final int? maxInputCharacters;
  final int? maxOutputCharacters;
  final String Function(String) _convert;

  HtmlEntityDecodeResult decodeText(HtmlEntityDecodeRequest request) {
    if (maxInputCharacters case final maximum?
        when request.input.length > maximum) {
      _throwResource(field: 'input', reason: 'input-limit');
    }
    try {
      final decoded = _convert(request.input);
      if (maxOutputCharacters case final maximum?
          when decoded.length > maximum) {
        _throwResource(field: 'decoded', reason: 'output-limit');
      }
      return HtmlEntityDecodeResult(decoded: decoded);
    } on HtmlEntityDecodeException {
      rethrow;
    } on OutOfMemoryError {
      _throwResource(field: 'decoded', reason: 'allocation-limit');
    }
  }

  HtmlEntityDecodeResult decodeUtf8(List<int> input) {
    try {
      final invalidOffset = _firstInvalidUtf8Offset(input);
      if (invalidOffset != null) {
        _throwMalformed(reason: 'invalid-utf8', offset: invalidOffset);
      }
      final decoded = utf8.decode(input, allowMalformed: false);
      final hasBom =
          input.length >= 3 &&
          input[0] == 0xef &&
          input[1] == 0xbb &&
          input[2] == 0xbf;
      return decodeText(
        HtmlEntityDecodeRequest(input: hasBom ? '\uFEFF$decoded' : decoded),
      );
    } on HtmlEntityDecodeException {
      rethrow;
    } on FormatException catch (error) {
      _throwMalformed(reason: 'invalid-utf8', offset: error.offset ?? 0);
    } on OutOfMemoryError {
      _throwResource(field: 'input', reason: 'allocation-limit');
    }
  }

  Never _throwResource({required String field, required String reason}) =>
      throw HtmlEntityDecodeException(
        kind: HtmlEntityDecodeFailureKind.resource,
        code: 'html-decode.resource-limit',
        field: field,
        reason: reason,
      );
}

String _decodeHtml(String input) {
  final output = StringBuffer();
  var offset = 0;
  while (offset < input.length) {
    if (input.codeUnitAt(offset) != 0x26) {
      final first = input.codeUnitAt(offset);
      if (first >= 0xd800 && first <= 0xdbff) {
        if (offset + 1 >= input.length) {
          _throwMalformed(reason: 'surrogate-scalar', offset: offset);
        }
        final second = input.codeUnitAt(offset + 1);
        if (second < 0xdc00 || second > 0xdfff) {
          _throwMalformed(reason: 'surrogate-scalar', offset: offset);
        }
        output.write(input.substring(offset, offset + 2));
        offset += 2;
        continue;
      }
      if (first >= 0xdc00 && first <= 0xdfff) {
        _throwMalformed(reason: 'surrogate-scalar', offset: offset);
      }
      output.writeCharCode(first);
      offset += 1;
      continue;
    }

    final end = input.indexOf(';', offset + 1);
    if (end < 0) {
      _throwMalformed(reason: 'unterminated-entity', offset: offset);
    }
    final body = input.substring(offset + 1, end);
    final named = switch (body) {
      'amp' => 0x26,
      'lt' => 0x3c,
      'gt' => 0x3e,
      'quot' => 0x22,
      'apos' => 0x27,
      _ => null,
    };
    if (named != null) {
      output.writeCharCode(named);
    } else if (body.startsWith('#')) {
      final hexadecimal =
          body.length > 1 &&
          (body.codeUnitAt(1) == 0x78 || body.codeUnitAt(1) == 0x58);
      final digits = body.substring(hexadecimal ? 2 : 1);
      final validDigits =
          digits.isNotEmpty &&
          digits.codeUnits.every(hexadecimal ? _isHexDigit : _isDecimalDigit);
      if (!validDigits) {
        _throwMalformed(reason: 'invalid-number', offset: offset);
      }
      final scalar = int.tryParse(digits, radix: hexadecimal ? 16 : 10);
      if (scalar == null || scalar < 0 || scalar > 0x10ffff) {
        _throwMalformed(reason: 'out-of-range', offset: offset);
      }
      if (scalar >= 0xd800 && scalar <= 0xdfff) {
        _throwMalformed(reason: 'surrogate-scalar', offset: offset);
      }
      output.writeCharCode(scalar);
    } else {
      _throwMalformed(reason: 'unknown-entity', offset: offset);
    }
    offset = end + 1;
  }
  return output.toString();
}

int? _firstInvalidUtf8Offset(List<int> input) {
  var offset = 0;
  while (offset < input.length) {
    final first = input[offset];
    if (first < 0 || first > 0xff) return offset;
    if (first <= 0x7f) {
      offset += 1;
      continue;
    }

    final continuationCount = switch (first) {
      >= 0xc2 && <= 0xdf => 1,
      >= 0xe0 && <= 0xef => 2,
      >= 0xf0 && <= 0xf4 => 3,
      _ => -1,
    };
    if (continuationCount < 0 || offset + continuationCount >= input.length) {
      return offset;
    }
    for (var index = 1; index <= continuationCount; index += 1) {
      final continuation = input[offset + index];
      if (continuation < 0x80 || continuation > 0xbf) return offset;
    }

    final second = input[offset + 1];
    if (first == 0xe0 && second < 0xa0 ||
        first == 0xed && second > 0x9f ||
        first == 0xf0 && second < 0x90 ||
        first == 0xf4 && second > 0x8f) {
      return offset;
    }
    offset += continuationCount + 1;
  }
  return null;
}

bool _isHexDigit(int codeUnit) =>
    codeUnit >= 0x30 && codeUnit <= 0x39 ||
    codeUnit >= 0x41 && codeUnit <= 0x46 ||
    codeUnit >= 0x61 && codeUnit <= 0x66;

bool _isDecimalDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

Never _throwMalformed({required String reason, required int offset}) =>
    throw HtmlEntityDecodeException(
      kind: HtmlEntityDecodeFailureKind.validation,
      code: 'html-decode.malformed-input',
      field: 'input',
      reason: reason,
      offset: offset,
    );
