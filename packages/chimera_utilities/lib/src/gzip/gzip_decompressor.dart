import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:meta/meta.dart';

enum GzipDecompressMode { text, binary }

enum GzipDecompressFailureKind { validation, resource }

/// Safe failure details; never retains source data or dependency exceptions.
final class GzipDecompressException implements Exception {
  const GzipDecompressException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
  });

  final GzipDecompressFailureKind kind;
  final String code;
  final String field;
  final String reason;
}

/// One owned immutable decompression result.
final class GzipDecompressionResult {
  const GzipDecompressionResult._({
    required this.mode,
    required this.bytes,
    required this.text,
    required this.inputByteCount,
  });

  final GzipDecompressMode mode;
  final Uint8List bytes;
  final String? text;
  final int inputByteCount;
  int get outputByteCount => bytes.length;
}

/// Strict, stateless RFC 1952 decompression using pure-Dart inflate.
final class GzipDecompressor {
  const GzipDecompressor({this.maxInputBytes, this.maxOutputBytes})
    : _copyInput = _copyGzipDecompressBytes,
      _copyOutput = _copyGzipDecompressBytes,
      _decodeUtf8 = _decodeGzipUtf8,
      _createOutput = _createGzipDecompressOutput,
      assert(maxInputBytes == null || maxInputBytes >= 0),
      assert(maxOutputBytes == null || maxOutputBytes >= 0);

  /// Injection at allocation boundaries for deterministic resource tests.
  @visibleForTesting
  const GzipDecompressor.forTesting({
    this.maxInputBytes,
    this.maxOutputBytes,
    this._copyInput = _copyGzipDecompressBytes,
    this._copyOutput = _copyGzipDecompressBytes,
    this._decodeUtf8 = _decodeGzipUtf8,
    this._createOutput = _createGzipDecompressOutput,
  }) : assert(maxInputBytes == null || maxInputBytes >= 0),
       assert(maxOutputBytes == null || maxOutputBytes >= 0);

  final int? maxInputBytes;
  final int? maxOutputBytes;
  final Uint8List Function(List<int>) _copyInput;
  final Uint8List Function(List<int>) _copyOutput;
  final String Function(List<int>) _decodeUtf8;
  final OutputMemoryStream Function() _createOutput;

  GzipDecompressionResult decompressBytes(
    List<int> input, {
    required GzipDecompressMode mode,
  }) {
    late final Uint8List source;
    try {
      _ensureInputBudget(input.length);
      for (final byte in input) {
        if (byte < 0 || byte > 0xff) {
          _throwValidation(
            code: 'gzip-decompress.invalid-input',
            field: 'input',
            reason: 'byte-range',
          );
        }
      }
      source = _copyInput(input);
    } on GzipDecompressException {
      rethrow;
    } on OutOfMemoryError {
      _throwResource(field: 'input', reason: 'allocation-limit');
    }

    try {
      late final OutputMemoryStream aggregate;
      try {
        aggregate = _createOutput();
      } on RangeError {
        throw const _GzipOutputAllocationFailure();
      }
      _decodeMembers(source, aggregate);
      final bytes = _copyOutput(aggregate.getBytes()).asUnmodifiableView();
      String? text;
      if (mode == GzipDecompressMode.text) {
        try {
          text = _decodeUtf8(bytes);
        } on FormatException {
          _throwValidation(
            code: 'gzip-decompress.invalid-text',
            field: 'output',
            reason: 'invalid-utf8',
          );
        }
      }
      return GzipDecompressionResult._(
        mode: mode,
        bytes: bytes,
        text: text,
        inputByteCount: source.length,
      );
    } on GzipDecompressException {
      rethrow;
    } on _GzipOutputAllocationFailure {
      _throwResource(field: 'output', reason: 'allocation-limit');
    } on OutOfMemoryError {
      _throwResource(field: 'output', reason: 'allocation-limit');
    }
  }

  void _decodeMembers(Uint8List source, OutputMemoryStream aggregate) {
    if (source.isEmpty) _throwMalformed();
    final input = _StrictDeflateInput(source);
    while (!input.isEOS) {
      _decodeMember(source, input, aggregate);
    }
  }

  void _decodeMember(
    Uint8List source,
    _StrictDeflateInput input,
    OutputMemoryStream aggregate,
  ) {
    final memberStart = input.position;
    _require(input, 10);
    if (input.readByte() != 0x1f || input.readByte() != 0x8b) {
      _throwMalformed();
    }
    if (input.readByte() != 8) _throwUnsupported();
    final flags = input.readByte();
    if (flags & 0xe0 != 0) _throwUnsupported();
    input.skip(6); // MTIME, XFL, and OS are metadata only.

    if (flags & 0x04 != 0) {
      _require(input, 2);
      final extraLength = input.readUint16();
      _require(input, extraLength);
      input.skip(extraLength);
    }
    if (flags & 0x08 != 0) _skipTerminated(input);
    if (flags & 0x10 != 0) _skipTerminated(input);
    if (flags & 0x02 != 0) {
      _require(input, 2);
      final expected = input.readUint16();
      final actual = getCrc32(
        Uint8List.sublistView(source, memberStart, input.position - 2),
      );
      if (actual & 0xffff != expected) _throwCorrupt();
    }

    final output = _MemberOutput(
      aggregate,
      maxOutputBytes: maxOutputBytes,
      onLimit: () => _throwResource(field: 'output', reason: 'byte-limit'),
    );
    final inflate = Inflate.lazy(input, output: output);
    try {
      while (inflate.inflateBlock()) {}
    } on ArchiveException {
      if (input.length < 8) _throwMalformed();
      _throwCorrupt();
    } on RangeError {
      if (input.length < 8) _throwMalformed();
      _throwCorrupt();
    }
    if (input.invalidStoredBlock) _throwCorrupt();

    _require(input, 8);
    final expectedCrc = input.readUint32();
    final expectedSize = input.readUint32();
    final memberBytes = aggregate.subset(output.memberStart, aggregate.length);
    if (getCrc32(memberBytes) != expectedCrc) _throwCorrupt();
    if (output.length % 0x100000000 != expectedSize) _throwCorrupt();
  }

  void _skipTerminated(InputMemoryStream input) {
    while (!input.isEOS) {
      if (input.readByte() == 0) return;
    }
    _throwMalformed();
  }

  void _require(InputMemoryStream input, int count) {
    if (count < 0 || input.length < count) _throwMalformed();
  }

  void _ensureInputBudget(int length) {
    if (maxInputBytes case final maximum? when length > maximum) {
      _throwResource(field: 'input', reason: 'byte-limit');
    }
  }

  Never _throwMalformed() => _throwArchive('malformed-gzip');
  Never _throwCorrupt() => _throwArchive('corrupt-gzip');
  Never _throwUnsupported() => _throwArchive('unsupported-gzip');

  Never _throwArchive(String reason) => _throwValidation(
    code: 'gzip-decompress.invalid-archive',
    field: 'input',
    reason: reason,
  );

  Never _throwValidation({
    required String code,
    required String field,
    required String reason,
  }) => throw GzipDecompressException(
    kind: GzipDecompressFailureKind.validation,
    code: code,
    field: field,
    reason: reason,
  );

  Never _throwResource({required String field, required String reason}) =>
      throw GzipDecompressException(
        kind: GzipDecompressFailureKind.resource,
        code: 'gzip-decompress.resource-limit',
        field: field,
        reason: reason,
      );
}

/// Records the stored-block length words that `archive` reads internally.
///
/// archive 4.5.2 does not compare LEN and NLEN when LEN is zero. Intercepting
/// its existing `readBytes` boundary keeps Chimera's framing strict without
/// duplicating the DEFLATE parser or relying on compressed byte patterns.
final class _StrictDeflateInput extends InputMemoryStream {
  _StrictDeflateInput(super.bytes);

  bool invalidStoredBlock = false;

  @override
  InputStream readBytes(int count) {
    if (position >= 4) {
      final data = buffer!;
      final declaredLength = data[position - 4] | data[position - 3] << 8;
      final complement = data[position - 2] | data[position - 1] << 8;
      if (count != declaredLength || complement != (declaredLength ^ 0xffff)) {
        invalidStoredBlock = true;
      }
    }
    return super.readBytes(count);
  }
}

final class _MemberOutput extends OutputStream {
  _MemberOutput(
    this._aggregate, {
    required this.maxOutputBytes,
    required this.onLimit,
  }) : memberStart = _aggregate.length,
       super(byteOrder: ByteOrder.littleEndian);

  final OutputMemoryStream _aggregate;
  final int memberStart;
  final int? maxOutputBytes;
  final void Function() onLimit;

  @override
  int get length => _aggregate.length - memberStart;

  void _ensureCapacity(int additional) {
    if (additional < 0) throw ArchiveException('Invalid output length');
    if (maxOutputBytes case final maximum?) {
      if (_aggregate.length > maximum ||
          additional > maximum - _aggregate.length) {
        onLimit();
      }
    }
  }

  @override
  void writeByte(int value) {
    _ensureCapacity(1);
    try {
      _aggregate.writeByte(value);
    } on RangeError {
      throw const _GzipOutputAllocationFailure();
    }
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    if (count < 0 || count > bytes.length) {
      throw ArchiveException('Invalid output length');
    }
    _ensureCapacity(count);
    try {
      _aggregate.writeBytes(bytes, length: count);
    } on RangeError {
      throw const _GzipOutputAllocationFailure();
    }
  }

  @override
  void writeStream(InputStream stream) =>
      writeBytes(stream.toUint8List(), length: stream.length);

  @override
  void writeBackReference(int distance, int count) {
    if (distance < 1 || distance > length || count < 0) {
      throw ArchiveException('Invalid back-reference');
    }
    _ensureCapacity(count);
    try {
      _aggregate.writeBackReference(distance, count);
    } on RangeError {
      throw const _GzipOutputAllocationFailure();
    }
  }

  @override
  Uint8List subset(int start, [int? end]) {
    final memberLength = length;
    final relativeStart = start < 0 ? memberLength + start : start;
    final relativeEnd = switch (end) {
      null => memberLength,
      < 0 => memberLength + end,
      final value => value,
    };
    if (relativeStart < 0 ||
        relativeEnd < relativeStart ||
        relativeEnd > memberLength) {
      throw ArchiveException('Invalid member output range');
    }
    return _aggregate.subset(
      memberStart + relativeStart,
      memberStart + relativeEnd,
    );
  }

  @override
  void clear() => throw UnsupportedError('Member output cannot be cleared');

  @override
  void flush() => _aggregate.flush();
}

final class _GzipOutputAllocationFailure implements Exception {
  const _GzipOutputAllocationFailure();
}

Uint8List _copyGzipDecompressBytes(List<int> input) =>
    Uint8List.fromList(input);

OutputMemoryStream _createGzipDecompressOutput() => OutputMemoryStream(size: 0);

String _decodeGzipUtf8(List<int> bytes) {
  final decoded = utf8.decode(bytes, allowMalformed: false);
  if (bytes.length >= 3 &&
      bytes[0] == 0xef &&
      bytes[1] == 0xbb &&
      bytes[2] == 0xbf) {
    return '\uFEFF$decoded';
  }
  return decoded;
}
