import 'dart:convert';
import 'dart:typed_data';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';
import 'package:zxing2/qrcode.dart';

void main() {
  group('QrEncoder', () {
    const encoder = QrEncoder();

    test('GivenDefaults_WhenEncoding_ThenReturnsDeterministicPng', () {
      final first = encoder.encode('hello');
      final second = encoder.encode('hello');

      expect(first.pngBytes, second.pngBytes);
      expect(first.pngBytes.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      expect(_pngDimension(first.pngBytes, 16), 512);
      expect(_pngDimension(first.pngBytes, 20), 512);
      expect(first.inputByteCount, 5);
      expect(first.outputByteCount, first.pngBytes.length);
      expect(first.errorCorrection, QrErrorCorrection.medium);
      expect(first.quietZoneModules, 4);
      expect(first.foreground, '#000000');
      expect(first.background, '#FFFFFF');
      expect(first.version, inInclusiveRange(1, 40));
      expect(first.moduleCount, 17 + first.version * 4);
      expect(() => first.pngBytes[0] = 0, throwsUnsupportedError);
    });

    for (final level in QrErrorCorrection.values) {
      test('Given${level.name}_WhenEncoding_ThenIndependentDecoderReadsIt', () {
        final result = encoder.encode(
          'level-${level.name}',
          errorCorrection: level,
        );

        expect(result.errorCorrection, level);
        expect(_decodeQr(result.pngBytes), 'level-${level.name}');
      });
    }

    test('GivenUnicodeAndImageOptions_WhenEncoding_ThenUsesUtf8AndOptions', () {
      final result = encoder.encode(
        'Olá, 世界 👋',
        size: 320,
        quietZoneModules: 8,
        foreground: '#123456',
        background: '#FEDCBA',
      );

      expect(result.inputByteCount, 17);
      expect(_pngDimension(result.pngBytes, 16), 320);
      expect(result.quietZoneModules, 8);
      expect(result.foreground, '#123456');
      expect(result.background, '#FEDCBA');
      expect(_decodeQr(result.pngBytes), 'Olá, 世界 👋');
    });

    test('GivenLatin1_WhenEncoding_ThenIndependentDecoderReadsUtf8', () {
      final result = encoder.encode('ação déjà vu');

      expect(_decodeQr(result.pngBytes), 'ação déjà vu');
    });

    test('GivenSingleEciVersionFortyBoundary_WhenEncoding_ThenPayloadFitsAndDecodes', () {
      final input = '界${'a' * 2949}';

      final result = encoder.encode(
        input,
        errorCorrection: QrErrorCorrection.low,
        size: 1850,
      );

      expect(result.inputByteCount, 2952);
      expect(result.version, 40);
      expect(_decodeQr(result.pngBytes), input);
    });

    test('GivenLowercaseColors_WhenEncoding_ThenNormalizesMetadata', () {
      final result = encoder.encode(
        'colors',
        foreground: '#abcdef',
        background: '#fedcba',
      );

      expect(result.foreground, '#ABCDEF');
      expect(result.background, '#FEDCBA');
    });

    test('GivenMaximumNumericCapacity_WhenEncoding_ThenUsesVersionForty', () {
      final result = encoder.encode(
        '1' * 7089,
        errorCorrection: QrErrorCorrection.low,
        size: 1024,
      );

      expect(result.version, 40);
    });

    final invalidCases = <String, void Function()>{
      'empty input': () => encoder.encode(''),
      'malformed unicode': () => encoder.encode(String.fromCharCode(0xD800)),
      'size below minimum': () => encoder.encode('x', size: 63),
      'size above maximum': () => encoder.encode('x', size: 4097),
      'negative quiet zone': () => encoder.encode('x', quietZoneModules: -1),
      'excessive quiet zone': () => encoder.encode('x', quietZoneModules: 33),
      'invalid foreground': () => encoder.encode('x', foreground: 'black'),
      'invalid background': () => encoder.encode('x', background: '#FFFF'),
      'indistinguishable colors': () =>
          encoder.encode('x', foreground: '#ffffff', background: '#FFFFFF'),
      'content beyond QR capacity': () =>
          encoder.encode('a' * 3000, errorCorrection: QrErrorCorrection.high),
      'image smaller than module grid': () =>
          encoder.encode('a' * 1000, size: 64, quietZoneModules: 32),
    };

    for (final entry in invalidCases.entries) {
      test('Given${entry.key}_WhenEncoding_ThenReturnsTypedValidation', () {
        expect(
          entry.value,
          throwsA(
            isA<QrEncodeException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  QrEncodeFailureKind.validation,
                )
                .having(
                  (error) => error.code,
                  'code',
                  startsWith('qr-encode.'),
                ),
          ),
        );
      });
    }

    test(
      'GivenConfiguredInputBudget_WhenExceeded_ThenReturnsResourceFailure',
      () {
        const bounded = QrEncoder(maxInputBytes: 3);

        expect(
          () => bounded.encode('four'),
          throwsA(
            isA<QrEncodeException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  QrEncodeFailureKind.resource,
                )
                .having((error) => error.reason, 'reason', 'byte-limit'),
          ),
        );
      },
    );

    test('GivenMultibyteInput_WhenCheckingBudget_ThenCountsUtf8Bytes', () {
      const bounded = QrEncoder(maxInputBytes: 3);

      expect(
        () => bounded.encode('éé'),
        throwsA(
          isA<QrEncodeException>().having(
            (error) => error.reason,
            'reason',
            'byte-limit',
          ),
        ),
      );
    });

    test(
      'GivenClipboardText_WhenPrechecked_ThenUtf8BudgetIsAllocationFree',
      () {
        expect(QrEncoder.inputExceedsByteLimit('é', limit: 2), isFalse);
        expect(QrEncoder.inputExceedsByteLimit('éé', limit: 3), isTrue);
        expect(QrEncoder.inputExceedsByteLimit('👋', limit: 4), isFalse);
        expect(QrEncoder.inputExceedsByteLimit('👋a', limit: 4), isTrue);
      },
    );
  });
}

int _pngDimension(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

String _decodeQr(List<int> pngBytes) {
  final decoded = image.decodePng(Uint8List.fromList(pngBytes))!;
  final source = RGBLuminanceSource(
    decoded.width,
    decoded.height,
    decoded
        .convert(numChannels: 4)
        .getBytes(order: image.ChannelOrder.abgr)
        .buffer
        .asInt32List(),
  );
  final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
  final hints = DecodeHints()..put(DecodeHintType.pureBarcode);
  final result = QRCodeReader().decode(bitmap, hints: hints);
  final segments =
      result.resultMetadata[ResultMetadataType.byteSegments] as List<Int8List>?;
  if (segments == null) return result.text;
  // zxing2 0.2.4 stores decoded bytes in signed Int8List values. Normalize
  // those values before applying UTF-8 so non-ASCII conformance is testable.
  return utf8.decode(
    segments.expand((segment) => segment.map((byte) => byte & 0xFF)).toList(),
  );
}
