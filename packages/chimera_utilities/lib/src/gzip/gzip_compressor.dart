import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:meta/meta.dart';

enum GzipCompressFailureKind { validation, resource }

/// Safe failure details; never retains the source or dependency exception.
final class GzipCompressException implements Exception {
  const GzipCompressException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
  });

  final GzipCompressFailureKind kind;
  final String code;
  final String field;
  final String reason;
}

/// One owned immutable GZIP member, with no retained source or duplicate view.
final class GzipCompressionResult {
  GzipCompressionResult._({
    required this.level,
    required this.bytes,
    required this.inputByteCount,
  });

  final int level;
  final Uint8List bytes;
  final int inputByteCount;
  int get outputByteCount => bytes.length;
}

/// Stateless compression using the same Dart encoder on every target.
final class GzipCompressor {
  const GzipCompressor({this.maxInputBytes, this.maxOutputBytes})
    : _copyBytes = _copyGzipBytes,
      _encodeUtf8 = _encodeGzipUtf8,
      _encode = _encodeGzip,
      assert(maxInputBytes == null || maxInputBytes >= 0),
      assert(maxOutputBytes == null || maxOutputBytes >= 0);

  /// Injection at allocation boundaries for deterministic resource tests.
  @visibleForTesting
  const GzipCompressor.forTesting({
    this.maxInputBytes,
    this.maxOutputBytes,
    this._copyBytes = _copyGzipBytes,
    this._encodeUtf8 = _encodeGzipUtf8,
    this._encode = _encodeGzip,
  }) : assert(maxInputBytes == null || maxInputBytes >= 0),
       assert(maxOutputBytes == null || maxOutputBytes >= 0);

  final int? maxInputBytes;
  final int? maxOutputBytes;
  final Uint8List Function(List<int>) _copyBytes;
  final List<int> Function(String) _encodeUtf8;
  final Uint8List Function(List<int>, int) _encode;

  GzipCompressionResult compressText(String input, {int level = 6}) {
    _validateLevel(level);
    late final List<int> source;
    try {
      _ensureInputBudget(_validatedUtf8Length(input));
      source = _encodeUtf8(input);
    } on OutOfMemoryError {
      _throwResourceLimit('input', 'allocation-limit');
    }
    return _compress(source, level);
  }

  GzipCompressionResult compressBytes(List<int> input, {int level = 6}) {
    _validateLevel(level);
    late final Uint8List source;
    try {
      _ensureInputBudget(input.length);
      for (final byte in input) {
        if (byte < 0 || byte > 255) _throwInvalidInput('byte-range');
      }
      source = _copyBytes(input);
    } on OutOfMemoryError {
      _throwResourceLimit('input', 'allocation-limit');
    }
    return _compress(source, level);
  }

  GzipCompressionResult _compress(List<int> source, int level) {
    try {
      final encoded = _encode(source, level);
      if (maxOutputBytes case final maximum? when encoded.length > maximum) {
        _throwResourceLimit('output', 'byte-limit');
      }
      // archive 4.5.2 writes wall-clock MTIME. All other header fields are fixed.
      encoded.fillRange(4, 8, 0);
      return GzipCompressionResult._(
        level: level,
        bytes: _copyBytes(encoded).asUnmodifiableView(),
        inputByteCount: source.length,
      );
    } on OutOfMemoryError {
      _throwResourceLimit('output', 'allocation-limit');
    }
  }

  void _validateLevel(int level) {
    if (level < 0 || level > 9) {
      throw const GzipCompressException(
        kind: GzipCompressFailureKind.validation,
        code: 'gzip-compress.invalid-level',
        field: 'level',
        reason: 'outside-range',
      );
    }
  }

  // Count before allocating UTF-8, rejecting replacement of invalid surrogates.
  int _validatedUtf8Length(String input) {
    var length = 0;
    for (var index = 0; index < input.length; index++) {
      final unit = input.codeUnitAt(index);
      if (unit <= 0x7f) {
        length++;
      } else if (unit <= 0x7ff) {
        length += 2;
      } else if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index >= input.length) _throwInvalidInput('invalid-unicode');
        final next = input.codeUnitAt(index);
        if (next < 0xdc00 || next > 0xdfff) {
          _throwInvalidInput('invalid-unicode');
        }
        length += 4;
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        _throwInvalidInput('invalid-unicode');
      } else {
        length += 3;
      }
    }
    return length;
  }

  void _ensureInputBudget(int length) {
    if (maxInputBytes case final maximum? when length > maximum) {
      _throwResourceLimit('input', 'byte-limit');
    }
  }

  Never _throwInvalidInput(String reason) => throw GzipCompressException(
    kind: GzipCompressFailureKind.validation,
    code: 'gzip-compress.invalid-input',
    field: 'input',
    reason: reason,
  );

  Never _throwResourceLimit(String field, String reason) =>
      throw GzipCompressException(
        kind: GzipCompressFailureKind.resource,
        code: 'gzip-compress.resource-limit',
        field: field,
        reason: reason,
      );
}

Uint8List _copyGzipBytes(List<int> input) => Uint8List.fromList(input);

List<int> _encodeGzipUtf8(String input) => utf8.encode(input);

Uint8List _encodeGzip(List<int> input, int level) =>
    const GZipEncoderWeb().encodeBytes(input, level: level);
