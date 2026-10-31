import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

typedef QrDecodeOperationService =
    OperationService<QrDecodeOperationRequest, QrDecodeOutput>;

final class QrDecodeOperationRequest {
  const QrDecodeOperationRequest({required this.bytes});

  final List<int> bytes;
}

final class QrDecodeOutput {
  const QrDecodeOutput(this.result);

  final QrDecodeResult result;

  String get text => result.text;
  String get format => result.format;
  int get width => result.width;
  int get height => result.height;
  int get inputByteCount => result.inputByteCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'text': text,
    'format': format,
    'width': width,
    'height': height,
    'inputByteCount': inputByteCount,
  };
}

final class QrDecodeService implements QrDecodeOperationService {
  const QrDecodeService({this.decoder = const QrDecoder()});

  final QrDecoder decoder;

  @override
  Future<ChimeraResult<QrDecodeOutput>> execute(
    QrDecodeOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess(QrDecodeOutput(decoder.decode(request.bytes)));
    } on QrDecodeException catch (error) {
      return ChimeraFailure(
        kind: switch (error.kind) {
          QrDecodeFailureKind.validation => FailureKind.validation,
          QrDecodeFailureKind.decoding => FailureKind.processing,
          QrDecodeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          QrDecodeFailureKind.validation => 'error.qrDecode.validation',
          QrDecodeFailureKind.decoding => 'error.qrDecode.decoding',
          QrDecodeFailureKind.resource => 'error.qrDecode.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
