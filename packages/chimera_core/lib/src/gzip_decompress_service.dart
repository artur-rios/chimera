import 'dart:typed_data';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class GzipDecompressOperationRequest {
  const GzipDecompressOperationRequest.bytes(this._bytes, {required this.mode});

  final List<int> _bytes;
  final GzipDecompressMode mode;
}

final class GzipDecompressOutput {
  const GzipDecompressOutput(this.result);

  final GzipDecompressionResult result;

  GzipDecompressMode get mode => result.mode;
  Uint8List get bytes => result.bytes;
  String? get text => result.text;
  int get inputByteCount => result.inputByteCount;
  int get outputByteCount => result.outputByteCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode.name,
    'text': mode == GzipDecompressMode.text ? text : null,
    'bytes': mode == GzipDecompressMode.binary
        ? bytes.toList(growable: false)
        : null,
    'inputByteCount': inputByteCount,
    'outputByteCount': outputByteCount,
  };
}

final class GzipDecompressService
    implements
        OperationService<GzipDecompressOperationRequest, GzipDecompressOutput> {
  const GzipDecompressService({this.decompressor = const GzipDecompressor()});

  final GzipDecompressor decompressor;

  @override
  Future<ChimeraResult<GzipDecompressOutput>> execute(
    GzipDecompressOperationRequest request,
  ) async {
    try {
      final decompressed = decompressor.decompressBytes(
        request._bytes,
        mode: request.mode,
      );
      return ChimeraSuccess<GzipDecompressOutput>(
        GzipDecompressOutput(decompressed),
      );
    } on GzipDecompressException catch (error) {
      return ChimeraFailure<GzipDecompressOutput>(
        kind: switch (error.kind) {
          GzipDecompressFailureKind.validation => FailureKind.validation,
          GzipDecompressFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          GzipDecompressFailureKind.validation =>
            'error.gzipDecompress.validation',
          GzipDecompressFailureKind.resource => 'error.gzipDecompress.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
        },
      );
    }
  }
}
