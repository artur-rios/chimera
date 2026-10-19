import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('QrEncodeService', () {
    test(
      'GivenValidRequest_WhenExecuted_ThenReturnsPngAndStableMetadata',
      () async {
        const service = QrEncodeService();
        final result = await service.execute(
          const QrEncodeOperationRequest(
            text: 'hello',
            errorCorrection: QrErrorCorrection.high,
            size: 256,
            quietZoneModules: 6,
            foreground: '#112233',
            background: '#F0F0F0',
          ),
        );

        final output = (result as ChimeraSuccess<QrEncodeOutput>).value;
        expect(output.pngBytes.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
        expect(output.size, 256);
        expect(output.errorCorrection, QrErrorCorrection.high);
        expect(output.quietZoneModules, 6);
        expect(output.foreground, '#112233');
        expect(output.background, '#F0F0F0');
        expect(output.inputByteCount, 5);
        expect(output.outputByteCount, output.pngBytes.length);
        expect(output.toJson(), <String, Object?>{
          'pngBase64': base64Encode(output.pngBytes),
          'size': 256,
          'version': output.version,
          'moduleCount': output.moduleCount,
          'errorCorrection': 'high',
          'quietZoneModules': 6,
          'foreground': '#112233',
          'background': '#F0F0F0',
          'inputByteCount': 5,
          'outputByteCount': output.outputByteCount,
        });
      },
    );

    test('GivenInvalidInput_WhenExecuted_ThenMapsValidationFailure', () async {
      const service = QrEncodeService();

      final result = await service.execute(
        const QrEncodeOperationRequest(text: ''),
      );

      final failure = result as ChimeraFailure<QrEncodeOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, 'qr-encode.invalid-input');
      expect(failure.messageKey, 'error.qrEncode.validation');
      expect(failure.details, <String, Object?>{
        'field': 'input',
        'reason': 'empty',
      });
    });

    test('GivenExceededBudget_WhenExecuted_ThenMapsResourceFailure', () async {
      const service = QrEncodeService(encoder: QrEncoder(maxInputBytes: 3));

      final result = await service.execute(
        const QrEncodeOperationRequest(text: 'four'),
      );

      final failure = result as ChimeraFailure<QrEncodeOutput>;
      expect(failure.kind, FailureKind.resource);
      expect(failure.code, 'qr-encode.resource-limit');
      expect(failure.messageKey, 'error.qrEncode.resource');
      expect(failure.details, <String, Object?>{
        'field': 'input',
        'reason': 'byte-limit',
      });
    });
  });
}
