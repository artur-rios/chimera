import 'dart:convert';
import 'dart:typed_data';

enum Base64DecodeMode { text, binary }

enum Base64DecodeFailureKind { validation, resource }

final class Base64DecodeException implements Exception {
  const Base64DecodeException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final Base64DecodeFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class Base64DecodeResult {
  const Base64DecodeResult({
    required this.bytes,
    required this.text,
    required this.inputCharacterCount,
    required this.outputByteCount,
    required this.imageCandidateMediaType,
  });

  final Uint8List bytes;
  final String? text;
  final int inputCharacterCount;
  final int outputByteCount;
  final String? imageCandidateMediaType;
}

final class Base64ByteDecoder {
  const Base64ByteDecoder({this.maxInputCharacters, this.maxOutputBytes})
    : assert(
        maxInputCharacters == null || maxInputCharacters >= 0,
        'maxInputCharacters must not be negative',
      ),
      assert(
        maxOutputBytes == null || maxOutputBytes >= 0,
        'maxOutputBytes must not be negative',
      );

  final int? maxInputCharacters;
  final int? maxOutputBytes;

  Base64DecodeResult decodeString(
    String input, {
    required Base64DecodeMode mode,
  }) {
    try {
      return _decodeValidatedSource(input, mode);
    } on Base64DecodeException {
      rethrow;
    } on OutOfMemoryError {
      _throwAllocationLimit();
    }
  }

  Base64DecodeResult decodeUtf8(
    List<int> input, {
    required Base64DecodeMode mode,
  }) {
    try {
      _validateBytes(input);
      _ensureInputBudget(input.length);

      late final String source;
      try {
        source = _decodeStrictUtf8(input);
      } on FormatException {
        _throwInvalidSourceUtf8();
      }

      return _decodeValidatedSource(source, mode);
    } on Base64DecodeException {
      rethrow;
    } on OutOfMemoryError {
      _throwAllocationLimit();
    }
  }

  Base64DecodeResult _decodeValidatedSource(
    String input,
    Base64DecodeMode mode,
  ) {
    _ensureInputBudget(input.length);
    final paddingCount = _validateCanonicalStructure(input);
    final predictedOutputBytes = (input.length ~/ 4) * 3 - paddingCount;
    _ensureOutputBudget(predictedOutputBytes);

    late final Uint8List decoded;
    try {
      decoded = base64Decode(input);
    } on FormatException {
      _throwMalformedBase64();
    }

    if (base64Encode(decoded) != input) {
      _throwMalformedBase64();
    }

    final bytes = decoded.asUnmodifiableView();
    String? text;
    if (mode == Base64DecodeMode.text) {
      try {
        text = _decodeStrictUtf8(bytes);
      } on FormatException {
        throw const Base64DecodeException(
          kind: Base64DecodeFailureKind.validation,
          code: 'base64-decode.invalid-text',
          field: 'output',
          reason: 'invalid-utf8',
        );
      }
    }

    return Base64DecodeResult(
      bytes: bytes,
      text: text,
      inputCharacterCount: input.length,
      outputByteCount: decoded.length,
      imageCandidateMediaType: _detectImageCandidate(bytes),
    );
  }

  int _validateCanonicalStructure(String input) {
    if (input.isEmpty) return 0;
    if (input.length % 4 != 0) _throwMalformedBase64();

    var paddingCount = 0;
    if (input.codeUnitAt(input.length - 1) == _equals) {
      paddingCount = 1;
      if (input.codeUnitAt(input.length - 2) == _equals) {
        paddingCount = 2;
      }
    }

    final contentLength = input.length - paddingCount;
    for (var index = 0; index < input.length; index++) {
      final unit = input.codeUnitAt(index);
      if (index < contentLength) {
        if (!_isBase64Alphabet(unit)) _throwMalformedBase64();
      } else if (unit != _equals) {
        _throwMalformedBase64();
      }
    }

    return paddingCount;
  }

  bool _isBase64Alphabet(int unit) =>
      unit >= _upperA && unit <= _upperZ ||
      unit >= _lowerA && unit <= _lowerZ ||
      unit >= _zero && unit <= _nine ||
      unit == _plus ||
      unit == _slash;

  String? _detectImageCandidate(Uint8List bytes) {
    if (_startsWith(bytes, const <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ])) {
      return 'image/png';
    }
    if (_startsWith(bytes, const <int>[0xFF, 0xD8, 0xFF])) {
      return 'image/jpeg';
    }
    if (_startsWith(bytes, const <int>[0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
        _startsWith(bytes, const <int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
      return 'image/gif';
    }
    if (bytes.length >= 12 &&
        _matchesAt(bytes, 0, const <int>[0x52, 0x49, 0x46, 0x46]) &&
        _matchesAt(bytes, 8, const <int>[0x57, 0x45, 0x42, 0x50])) {
      return 'image/webp';
    }
    return null;
  }

  bool _startsWith(Uint8List bytes, List<int> signature) =>
      _matchesAt(bytes, 0, signature);

  bool _matchesAt(Uint8List bytes, int offset, List<int> signature) {
    if (bytes.length - offset < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[offset + index] != signature[index]) return false;
    }
    return true;
  }

  String _decodeStrictUtf8(List<int> bytes) {
    final decoded = utf8.decode(bytes, allowMalformed: false);
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return '\uFEFF$decoded';
    }
    return decoded;
  }

  void _validateBytes(List<int> input) {
    for (final byte in input) {
      if (byte < 0 || byte > 0xFF) {
        throw const Base64DecodeException(
          kind: Base64DecodeFailureKind.validation,
          code: 'base64-decode.invalid-input',
          field: 'input',
          reason: 'byte-range',
        );
      }
    }
  }

  void _ensureInputBudget(int length) {
    if (maxInputCharacters case final maximum? when length > maximum) {
      _throwResourceLimit(field: 'input', reason: 'character-limit');
    }
  }

  void _ensureOutputBudget(int length) {
    if (maxOutputBytes case final maximum? when length > maximum) {
      _throwResourceLimit(field: 'output', reason: 'byte-limit');
    }
  }

  Never _throwMalformedBase64() => throw const Base64DecodeException(
    kind: Base64DecodeFailureKind.validation,
    code: 'base64-decode.invalid-input',
    field: 'input',
    reason: 'malformed-base64',
  );

  Never _throwInvalidSourceUtf8() => throw const Base64DecodeException(
    kind: Base64DecodeFailureKind.validation,
    code: 'base64-decode.invalid-input',
    field: 'input',
    reason: 'invalid-utf8',
  );

  Never _throwAllocationLimit() =>
      _throwResourceLimit(field: 'output', reason: 'allocation-limit');

  Never _throwResourceLimit({required String field, required String reason}) =>
      throw Base64DecodeException(
        kind: Base64DecodeFailureKind.resource,
        code: 'base64-decode.resource-limit',
        field: field,
        reason: reason,
      );
}

const _upperA = 0x41;
const _upperZ = 0x5A;
const _lowerA = 0x61;
const _lowerZ = 0x7A;
const _zero = 0x30;
const _nine = 0x39;
const _plus = 0x2B;
const _slash = 0x2F;
const _equals = 0x3D;
