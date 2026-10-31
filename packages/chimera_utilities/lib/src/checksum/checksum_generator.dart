import 'dart:convert';

import 'package:meta/meta.dart';

enum ChecksumGenerateFailureKind { validation, resource }

/// Safe diagnostics contain no source, checksum, or dependency exception.
final class ChecksumGenerateException implements Exception {
  const ChecksumGenerateException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
  });
  final ChecksumGenerateFailureKind kind;
  final String code;
  final String field;
  final String reason;
}

/// Lowercase hexadecimal checksum. No source bytes or text are retained.
final class ChecksumGenerateResult {
  const ChecksumGenerateResult({
    required this.algorithm,
    required this.checksum,
  });
  final String algorithm;
  final String checksum;
}

/// Stateless local checksumming of exact bytes or strictly validated UTF-8 text.
final class ChecksumGenerator {
  const ChecksumGenerator()
    : _checksum = _generateChecksum,
      _encodeUtf8 = _encodeChecksumUtf8;

  @visibleForTesting
  const ChecksumGenerator.forTesting({
    this._checksum = _generateChecksum,
    this._encodeUtf8 = _encodeChecksumUtf8,
  });

  static const algorithms = ['crc32', 'adler32'];
  final String Function(List<int>, String) _checksum;
  final List<int> Function(String) _encodeUtf8;

  ChecksumGenerateResult generateText(
    String input, {
    String algorithm = 'crc32',
  }) {
    _validateAlgorithm(algorithm);
    for (var index = 0; index < input.length; index++) {
      final unit = input.codeUnitAt(index);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index == input.length) _invalid('input', 'invalid-unicode');
        final next = input.codeUnitAt(index);
        if (next < 0xdc00 || next > 0xdfff) {
          _invalid('input', 'invalid-unicode');
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        _invalid('input', 'invalid-unicode');
      }
    }
    try {
      return _generate(_encodeUtf8(input), algorithm);
    } on OutOfMemoryError {
      _resource();
    }
  }

  ChecksumGenerateResult generateBytes(
    List<int> input, {
    String algorithm = 'crc32',
  }) {
    _validateAlgorithm(algorithm);
    for (final byte in input) {
      if (byte < 0 || byte > 255) _invalid('input', 'byte-range');
    }
    return _generate(input, algorithm);
  }

  ChecksumGenerateResult _generate(List<int> input, String algorithm) {
    try {
      return ChecksumGenerateResult(
        algorithm: algorithm,
        checksum: _checksum(input, algorithm),
      );
    } on OutOfMemoryError {
      _resource();
    }
  }

  void _validateAlgorithm(String algorithm) {
    if (!algorithms.contains(algorithm)) {
      _invalid('algorithm', 'unsupported-algorithm');
    }
  }

  Never _invalid(String field, String reason) =>
      throw ChecksumGenerateException(
        kind: ChecksumGenerateFailureKind.validation,
        code: field == 'algorithm'
            ? 'checksum-generate.invalid-algorithm'
            : 'checksum-generate.invalid-input',
        field: field,
        reason: reason,
      );
  Never _resource() => throw const ChecksumGenerateException(
    kind: ChecksumGenerateFailureKind.resource,
    code: 'checksum-generate.resource-limit',
    field: 'input',
    reason: 'allocation-limit',
  );
}

List<int> _encodeChecksumUtf8(String input) => utf8.encode(input);
// CRC-32/ISO-HDLC: reflected polynomial, initial and final XOR 0xffffffff.
// RFC 1950 Adler-32: s1 starts at one, s2 at zero, modulo 65521.
String _generateChecksum(List<int> input, String algorithm) {
  var value = 0;
  if (algorithm == 'crc32') {
    var crc = 0xffffffff;
    for (final byte in input) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >>> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
      }
    }
    // Arithmetic avoids signed 32-bit formatting on compiled JavaScript.
    value = (crc ^ 0xffffffff).toUnsigned(32);
  } else {
    var s1 = 1;
    var s2 = 0;
    for (final byte in input) {
      s1 = (s1 + byte) % 65521;
      s2 = (s2 + s1) % 65521;
    }
    value = s2 * 65536 + s1;
  }
  // JS bitwise values may be signed; modulo restores the unsigned value.
  return (value % 4294967296).toRadixString(16).padLeft(8, '0');
}
