import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenQrImage_WhenExecuted_ThenReturnsOnlyTextAndSafeImageMetadata',
    () async {
      final bytes = const QrEncoder().encode('Olá 👋', size: 256).pngBytes;
      const QrDecodeOperationService service = QrDecodeService();
      final result = await service.execute(
        QrDecodeOperationRequest(bytes: bytes),
      );
      final output = (result as ChimeraSuccess<QrDecodeOutput>).value;
      expect(output.text, 'Olá 👋');
      expect(output.format, 'png');
      expect(output.width, 256);
      expect(output.height, 256);
      expect(output.inputByteCount, bytes.length);
      expect(output.toJson(), <String, Object?>{
        'text': 'Olá 👋',
        'format': 'png',
        'width': 256,
        'height': 256,
        'inputByteCount': bytes.length,
      });
    },
  );

  for (final entry in <String, (List<int>, FailureKind, String, String)>{
    'Empty': (<int>[], FailureKind.processing, 'decoding', 'empty'),
    'Unsupported': (
      utf8.encode('private input never logged'),
      FailureKind.processing,
      'decoding',
      'unsupported-format',
    ),
    'InvalidByte': (
      <int>[-1],
      FailureKind.validation,
      'validation',
      'invalid-byte',
    ),
  }.entries) {
    test('Given${entry.key}_WhenExecuted_ThenMapsSafeTypedFailure', () async {
      final result = await const QrDecodeService().execute(
        QrDecodeOperationRequest(bytes: entry.value.$1),
      );
      final failure = result as ChimeraFailure<QrDecodeOutput>;
      expect(failure.kind, entry.value.$2);
      expect(failure.code, 'qr-decode.${entry.value.$3}');
      expect(failure.messageKey, 'error.qrDecode.${entry.value.$3}');
      expect(failure.details, {'field': 'input', 'reason': entry.value.$4});
      expect(jsonEncode(failure.details), isNot(contains('private')));
    });
  }

  test('GivenExceededBudget_WhenExecuted_ThenMapsResourceFailure', () async {
    final result = await const QrDecodeService(
      decoder: QrDecoder(maxInputBytes: 2),
    ).execute(QrDecodeOperationRequest(bytes: [1, 2, 3]));
    final failure = result as ChimeraFailure<QrDecodeOutput>;
    expect(failure.kind, FailureKind.resource);
    expect(failure.code, 'qr-decode.resource');
    expect(failure.messageKey, 'error.qrDecode.resource');
    expect(failure.details, {'field': 'input', 'reason': 'byte-limit'});
  });
}
