import 'dart:convert';

import 'package:meta/meta.dart';

enum UrlDecodeFailureKind { validation, resource }

/// Safe failure details, without source, output, or dependency exceptions.
final class UrlDecodeException implements Exception {
  const UrlDecodeException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
    this.offset,
  });

  final UrlDecodeFailureKind kind;
  final String code;
  final String field;
  final String reason;
  final int? offset;
}

final class UrlDecodeRequest {
  const UrlDecodeRequest({required this.input});

  final String input;
}

final class UrlDecodeResult {
  const UrlDecodeResult({required this.decoded});

  final String decoded;
}

/// Stateless strict decoding for URL character references.
final class UrlDecoder {
  const UrlDecoder({this.maxInputCharacters, this.maxOutputCharacters})
    : _convert = _decodeUrl,
      assert(maxInputCharacters == null || maxInputCharacters >= 0),
      assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  @visibleForTesting
  const UrlDecoder.forTesting({
    this.maxInputCharacters,
    this.maxOutputCharacters,
    this._convert = _decodeUrl,
  }) : assert(maxInputCharacters == null || maxInputCharacters >= 0),
       assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  final int? maxInputCharacters;
  final int? maxOutputCharacters;
  final String Function(String) _convert;

  UrlDecodeResult decodeText(UrlDecodeRequest request) {
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
      return UrlDecodeResult(decoded: decoded);
    } on UrlDecodeException {
      rethrow;
    } on OutOfMemoryError {
      _throwResource(field: 'decoded', reason: 'allocation-limit');
    }
  }

  UrlDecodeResult decodeUtf8(List<int> input) {
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
        UrlDecodeRequest(input: hasBom ? '\uFEFF$decoded' : decoded),
      );
    } on UrlDecodeException {
      rethrow;
    } on FormatException catch (error) {
      _throwMalformed(reason: 'invalid-utf8', offset: error.offset ?? 0);
    } on OutOfMemoryError {
      _throwResource(field: 'input', reason: 'allocation-limit');
    }
  }

  Never _throwResource({required String field, required String reason}) =>
      throw UrlDecodeException(
        kind: UrlDecodeFailureKind.resource,
        code: 'url-decode.resource-limit',
        field: field,
        reason: reason,
      );
}

String _decodeUrl(String input) {
  final output = StringBuffer();
  var offset = 0;
  while (offset < input.length) {
    final unit = input.codeUnitAt(offset);
    if (unit == 0x25) {
      final start = offset;
      final bytes = <int>[];
      while (offset < input.length && input.codeUnitAt(offset) == 0x25) {
        if (offset + 2 >= input.length) {
          _throwMalformed(reason: 'malformed-percent', offset: offset);
        }
        final high = _hex(input.codeUnitAt(offset + 1));
        final low = _hex(input.codeUnitAt(offset + 2));
        if (high < 0 || low < 0) {
          _throwMalformed(reason: 'malformed-percent', offset: offset);
        }
        bytes.add(high * 16 + low);
        offset += 3;
      }
      final invalid = _firstInvalidUtf8Offset(bytes);
      if (invalid != null) {
        _throwMalformed(
          reason: 'invalid-percent-utf8',
          offset: start + invalid * 3,
        );
      }
      // Prefix ASCII so the platform UTF-8 decoder preserves a leading BOM.
      output.write(
        Uri.decodeComponent('_${input.substring(start, offset)}').substring(1),
      );
    } else if (unit >= 0xd800 && unit <= 0xdbff) {
      if (offset + 1 >= input.length ||
          input.codeUnitAt(offset + 1) < 0xdc00 ||
          input.codeUnitAt(offset + 1) > 0xdfff) {
        _throwMalformed(reason: 'surrogate-scalar', offset: offset);
      }
      output.write(input.substring(offset, offset + 2));
      offset += 2;
    } else {
      if (unit >= 0xdc00 && unit <= 0xdfff) {
        _throwMalformed(reason: 'surrogate-scalar', offset: offset);
      }
      output.writeCharCode(unit);
      offset++;
    }
  }
  return output.toString();
}

int _hex(int unit) => switch (unit) {
  >= 0x30 && <= 0x39 => unit - 0x30,
  >= 0x41 && <= 0x46 => unit - 0x41 + 10,
  >= 0x61 && <= 0x66 => unit - 0x61 + 10,
  _ => -1,
};

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

Never _throwMalformed({required String reason, required int offset}) =>
    throw UrlDecodeException(
      kind: UrlDecodeFailureKind.validation,
      code: 'url-decode.malformed-input',
      field: 'input',
      reason: reason,
      offset: offset,
    );
