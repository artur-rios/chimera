import 'dart:typed_data';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _GzipCompressSource { text, bytes }

final class GzipCompressOperationRequest {
  factory GzipCompressOperationRequest.text(String input, {int level = 6}) =>
      GzipCompressOperationRequest._(
        source: _GzipCompressSource.text,
        text: input,
        level: level,
      );

  factory GzipCompressOperationRequest.bytes(
    List<int> input, {
    int level = 6,
  }) => GzipCompressOperationRequest._(
    source: _GzipCompressSource.bytes,
    bytes: input,
    level: level,
  );

  const GzipCompressOperationRequest._({
    required this._source,
    required this.level,
    this._text,
    this._bytes,
  });

  final _GzipCompressSource _source;
  final int level;
  final String? _text;
  final List<int>? _bytes;
}

final class GzipCompressOutput {
  const GzipCompressOutput(this.result);

  final GzipCompressionResult result;

  int get level => result.level;
  Uint8List get bytes => result.bytes;
  int get inputByteCount => result.inputByteCount;
  int get outputByteCount => result.outputByteCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'level': level,
    'bytes': bytes.toList(growable: false),
    'inputByteCount': inputByteCount,
    'outputByteCount': outputByteCount,
  };
}

final class GzipCompressService
    implements
        OperationService<GzipCompressOperationRequest, GzipCompressOutput> {
  const GzipCompressService({this.compressor = const GzipCompressor()});

  final GzipCompressor compressor;

  @override
  Future<ChimeraResult<GzipCompressOutput>> execute(
    GzipCompressOperationRequest request,
  ) async {
    try {
      final compressed = switch (request._source) {
        _GzipCompressSource.text => compressor.compressText(
          request._text!,
          level: request.level,
        ),
        _GzipCompressSource.bytes => compressor.compressBytes(
          request._bytes!,
          level: request.level,
        ),
      };

      return ChimeraSuccess<GzipCompressOutput>(GzipCompressOutput(compressed));
    } on GzipCompressException catch (error) {
      return ChimeraFailure<GzipCompressOutput>(
        kind: switch (error.kind) {
          GzipCompressFailureKind.validation => FailureKind.validation,
          GzipCompressFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          GzipCompressFailureKind.validation => 'error.gzipCompress.validation',
          GzipCompressFailureKind.resource => 'error.gzipCompress.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
        },
      );
    }
  }
}
