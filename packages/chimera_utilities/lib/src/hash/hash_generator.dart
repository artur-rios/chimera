import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:meta/meta.dart';

enum HashGenerateFailureKind { validation, resource }

/// Safe diagnostics contain no source, digest, or dependency exception.
final class HashGenerateException implements Exception {
  const HashGenerateException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
  });
  final HashGenerateFailureKind kind;
  final String code;
  final String field;
  final String reason;
}

/// Lowercase hexadecimal digest. No source bytes or text are retained.
final class HashGenerateResult {
  const HashGenerateResult({required this.algorithm, required this.digest});
  final String algorithm;
  final String digest;
  bool get legacy => algorithm == 'md5' || algorithm == 'sha1';
}

/// Stateless local hashing of exact bytes or strictly validated UTF-8 text.
final class HashGenerator {
  const HashGenerator() : _hash = _generateHash, _encodeUtf8 = _encodeHashUtf8;

  @visibleForTesting
  const HashGenerator.forTesting({
    this._hash = _generateHash,
    this._encodeUtf8 = _encodeHashUtf8,
  });

  static const algorithms = ['sha256', 'sha384', 'sha512', 'md5', 'sha1'];
  final String Function(List<int>, String) _hash;
  final List<int> Function(String) _encodeUtf8;

  HashGenerateResult generateText(String input, {String algorithm = 'sha256'}) {
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

  HashGenerateResult generateBytes(
    List<int> input, {
    String algorithm = 'sha256',
  }) {
    _validateAlgorithm(algorithm);
    for (final byte in input) {
      if (byte < 0 || byte > 255) _invalid('input', 'byte-range');
    }
    return _generate(input, algorithm);
  }

  HashGenerateResult _generate(List<int> input, String algorithm) {
    try {
      return HashGenerateResult(
        algorithm: algorithm,
        digest: _hash(input, algorithm),
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

  Never _invalid(String field, String reason) => throw HashGenerateException(
    kind: HashGenerateFailureKind.validation,
    code: field == 'algorithm'
        ? 'hash-generate.invalid-algorithm'
        : 'hash-generate.invalid-input',
    field: field,
    reason: reason,
  );
  Never _resource() => throw const HashGenerateException(
    kind: HashGenerateFailureKind.resource,
    code: 'hash-generate.resource-limit',
    field: 'input',
    reason: 'allocation-limit',
  );
}

List<int> _encodeHashUtf8(String input) => utf8.encode(input);
String _generateHash(List<int> input, String algorithm) => switch (algorithm) {
  'sha256' => crypto.sha256,
  'sha384' => crypto.sha384,
  'sha512' => crypto.sha512,
  'md5' => crypto.md5,
  'sha1' => crypto.sha1,
  _ => throw StateError('Unsupported validated algorithm'),
}.convert(input).toString();
