import 'dart:convert';

enum Base64EncodeFailureKind { validation, resource }

final class Base64EncodeException implements Exception {
  const Base64EncodeException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final Base64EncodeFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class Base64EncodeResult {
  const Base64EncodeResult({
    required this.encoded,
    required this.inputByteCount,
    required this.outputCharacterCount,
  });

  final String encoded;
  final int inputByteCount;
  final int outputCharacterCount;
}

final class Base64ByteEncoder {
  const Base64ByteEncoder({this.maxInputBytes, this.maxOutputCharacters})
    : assert(
        maxInputBytes == null || maxInputBytes >= 0,
        'maxInputBytes must not be negative',
      ),
      assert(
        maxOutputCharacters == null || maxOutputCharacters >= 0,
        'maxOutputCharacters must not be negative',
      );

  final int? maxInputBytes;
  final int? maxOutputCharacters;

  Base64EncodeResult encodeBytes(List<int> input) {
    try {
      _validateBytes(input);
      return _encodeValidatedBytes(input);
    } on Base64EncodeException {
      rethrow;
    } on OutOfMemoryError {
      _throwAllocationLimit();
    }
  }

  Base64EncodeResult encodeText(String input) {
    try {
      _validateUnicodeScalars(input);
      return _encodeValidatedBytes(utf8.encode(input));
    } on Base64EncodeException {
      rethrow;
    } on OutOfMemoryError {
      _throwAllocationLimit();
    }
  }

  Base64EncodeResult encodeUtf8(List<int> input) {
    try {
      _validateBytes(input);
      _ensureInputBudget(input.length);
      utf8.decode(input, allowMalformed: false);
      return _encodeValidatedBytes(input, inputBudgetChecked: true);
    } on Base64EncodeException {
      rethrow;
    } on FormatException {
      throw const Base64EncodeException(
        kind: Base64EncodeFailureKind.validation,
        code: 'base64-encode.invalid-text',
        field: 'input',
        reason: 'invalid-utf8',
      );
    } on OutOfMemoryError {
      _throwAllocationLimit();
    }
  }

  Base64EncodeResult _encodeValidatedBytes(
    List<int> input, {
    bool inputBudgetChecked = false,
  }) {
    if (!inputBudgetChecked) _ensureInputBudget(input.length);

    final outputLength = ((input.length + 2) ~/ 3) * 4;
    if (maxOutputCharacters case final maximum? when outputLength > maximum) {
      _throwResourceLimit(field: 'output', reason: 'character-limit');
    }

    final encoded = base64Encode(input);
    return Base64EncodeResult(
      encoded: encoded,
      inputByteCount: input.length,
      outputCharacterCount: encoded.length,
    );
  }

  void _validateBytes(List<int> input) {
    for (final byte in input) {
      if (byte < 0 || byte > 0xFF) {
        throw const Base64EncodeException(
          kind: Base64EncodeFailureKind.validation,
          code: 'base64-encode.invalid-byte',
          field: 'input',
          reason: 'byte-range',
        );
      }
    }
  }

  void _validateUnicodeScalars(String input) {
    final units = input.codeUnits;
    for (var index = 0; index < units.length; index++) {
      final unit = units[index];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (index + 1 >= units.length ||
            units[index + 1] < 0xDC00 ||
            units[index + 1] > 0xDFFF) {
          _throwInvalidUnicode();
        }
        index++;
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        _throwInvalidUnicode();
      }
    }
  }

  void _ensureInputBudget(int length) {
    if (maxInputBytes case final maximum? when length > maximum) {
      _throwResourceLimit(field: 'input', reason: 'byte-limit');
    }
  }

  Never _throwInvalidUnicode() => throw const Base64EncodeException(
    kind: Base64EncodeFailureKind.validation,
    code: 'base64-encode.invalid-text',
    field: 'input',
    reason: 'invalid-unicode',
  );

  Never _throwAllocationLimit() =>
      _throwResourceLimit(field: 'output', reason: 'allocation-limit');

  Never _throwResourceLimit({required String field, required String reason}) =>
      throw Base64EncodeException(
        kind: Base64EncodeFailureKind.resource,
        code: 'base64-encode.resource-limit',
        field: field,
        reason: reason,
      );
}
