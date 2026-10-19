import 'dart:convert';
import 'dart:typed_data';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class QrEncodeOperationRequest {
  const QrEncodeOperationRequest({
    required this.text,
    this.errorCorrection = QrErrorCorrection.medium,
    this.size = 512,
    this.quietZoneModules = 4,
    this.foreground = '#000000',
    this.background = '#FFFFFF',
  });

  final String text;
  final QrErrorCorrection errorCorrection;
  final int size;
  final int quietZoneModules;
  final String foreground;
  final String background;
}

final class QrEncodeOutput {
  const QrEncodeOutput(this.result);

  final QrEncodeResult result;

  Uint8List get pngBytes => result.pngBytes;
  int get size => result.size;
  int get version => result.version;
  int get moduleCount => result.moduleCount;
  QrErrorCorrection get errorCorrection => result.errorCorrection;
  int get quietZoneModules => result.quietZoneModules;
  String get foreground => result.foreground;
  String get background => result.background;
  int get inputByteCount => result.inputByteCount;
  int get outputByteCount => result.outputByteCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'pngBase64': base64Encode(pngBytes),
    'size': size,
    'version': version,
    'moduleCount': moduleCount,
    'errorCorrection': errorCorrection.name,
    'quietZoneModules': quietZoneModules,
    'foreground': foreground,
    'background': background,
    'inputByteCount': inputByteCount,
    'outputByteCount': outputByteCount,
  };
}

final class QrEncodeService
    implements OperationService<QrEncodeOperationRequest, QrEncodeOutput> {
  const QrEncodeService({this.encoder = const QrEncoder()});

  final QrEncoder encoder;

  @override
  Future<ChimeraResult<QrEncodeOutput>> execute(
    QrEncodeOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<QrEncodeOutput>(
        QrEncodeOutput(
          encoder.encode(
            request.text,
            errorCorrection: request.errorCorrection,
            size: request.size,
            quietZoneModules: request.quietZoneModules,
            foreground: request.foreground,
            background: request.background,
          ),
        ),
      );
    } on QrEncodeException catch (error) {
      return ChimeraFailure<QrEncodeOutput>(
        kind: switch (error.kind) {
          QrEncodeFailureKind.validation => FailureKind.validation,
          QrEncodeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          QrEncodeFailureKind.validation => 'error.qrEncode.validation',
          QrEncodeFailureKind.resource => 'error.qrEncode.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
