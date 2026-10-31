import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:image/image.dart' as image;
import 'package:qr/qr.dart' as qr;
import 'package:test/test.dart';
import 'package:zxing2/qrcode.dart' as zxing;

void main() {
  const decoder = QrDecoder();
  final canvas = _independentQr('CHIMERA 27');

  for (final format in ['png', 'jpeg', 'bmp']) {
    test('Given${format}Qr_WhenDecoded_ThenReturnsTextAndImageMetadata', () {
      final bytes = _encode(canvas, format);
      final result = decoder.decode(bytes);

      expect(result.text, 'CHIMERA 27');
      expect(result.format, format);
      expect(result.width, 256);
      expect(result.height, 256);
      expect(result.inputByteCount, bytes.length);
    });
    test(
      'GivenOversized${format}Metadata_WhenDecoded_ThenRejectsBeforeRaster',
      () {
        final bytes = _oversized(_encode(canvas, format), format);
        expect(
          () => decoder.decode(bytes),
          throwsA(_failure(QrDecodeFailureKind.resource, 'pixel-limit')),
        );
      },
    );
  }

  for (final angle in [90, 180, 270, 17]) {
    test('Given${angle}DegreeRotation_WhenDecoded_ThenDetectsSymbol', () {
      final rotated = image.copyRotate(canvas, angle: angle);
      expect(decoder.decode(image.encodePng(rotated)).text, 'CHIMERA 27');
    });
  }

  for (final text in ['Olá, 世界 👋', 'ação déjà vu', '12345678901234567890']) {
    test('Given${text}_WhenDecoded_ThenPreservesExactContent', () {
      final encoded = const QrEncoder().encode(text, size: 320);
      expect(decoder.decode(encoded.pngBytes).text, text);
    });
  }

  test('GivenInputByteBudget_WhenExceeded_ThenChecksBeforeReadingBytes', () {
    expect(
      () => const QrDecoder(maxInputBytes: 4).decode(_UnreadableBytes(5)),
      throwsA(_failure(QrDecodeFailureKind.resource, 'byte-limit')),
    );
  });

  test('GivenSixteenBitPng_WhenDecoded_ThenNormalizesPixelFormat', () {
    final raster = canvas.convert(format: image.Format.uint16);
    expect(decoder.decode(image.encodePng(raster)).text, 'CHIMERA 27');
  });

  test('GivenColoredQr_WhenDecoded_ThenUsesCorrectRgbChannels', () {
    final colored = image.Image.from(canvas);
    for (final pixel in colored) {
      if (pixel.r == 255) pixel.setRgb(255, 0, 0);
    }
    expect(decoder.decode(image.encodePng(colored)).text, 'CHIMERA 27');
  });

  test(
    'GivenMixedSegments_WhenDecoded_ThenPreservesOrderAndRestoresCodecs',
    () {
      final codecs = {
        for (final charset in zxing.CharacterSetECI.all)
          charset: charset.encoding,
      };
      final payload = qr.QrPayload()
        ..addNumeric('123')
        ..addECI(qr.QrEciValue.utf8)
        ..addTypedData(Uint8List.fromList(utf8.encode('Olá 👋')))
        ..addAlphaNumeric('END');
      expect(decoder.decode(_payloadPng(payload)).text, '123Olá 👋END');
      for (final entry in codecs.entries) {
        expect(entry.key.encoding, same(entry.value));
      }
      expect(
        () =>
            decoder.decode(image.encodePng(image.Image(width: 10, height: 10))),
        throwsA(isA<QrDecodeException>()),
      );
      for (final entry in codecs.entries) {
        expect(entry.key.encoding, same(entry.value));
      }
    },
  );

  test('GivenUnsupportedEci_WhenDecoded_ThenReturnsTypedTextFailure', () {
    final payload = qr.QrPayload()
      ..addECI(qr.QrEciValue.shiftJis)
      ..addTypedData(Uint8List.fromList([0x93, 0xfa, 0x96, 0x7b]));
    expect(
      () => decoder.decode(_payloadPng(payload)),
      throwsA(_failure(QrDecodeFailureKind.decoding, 'invalid-text')),
    );
  });

  test('GivenMalformedUtf8Eci_WhenDecoded_ThenRejectsReplacementText', () {
    final payload = qr.QrPayload()
      ..addECI(qr.QrEciValue.utf8)
      ..addTypedData(Uint8List.fromList([0xc3, 0x28]));
    expect(
      () => decoder.decode(_payloadPng(payload)),
      throwsA(_failure(QrDecodeFailureKind.decoding, 'invalid-text')),
    );
  });

  test('GivenUtf16BeEci_WhenDecoded_ThenRejectsUnsupportedCodec', () {
    final payload = qr.QrPayload()
      ..addECI(qr.QrEciValue.utf16BE)
      ..addTypedData(Uint8List.fromList([0, 79, 0, 108, 0, 225]));
    expect(
      () => decoder.decode(_payloadPng(payload)),
      throwsA(_failure(QrDecodeFailureKind.decoding, 'invalid-text')),
    );
  });

  test('GivenBmpPaletteBeyondBitDepth_WhenDecoded_ThenRejectsMetadata', () {
    final bytes = image.encodeBmp(canvas);
    final header = ByteData.sublistView(bytes);
    header.setUint16(28, 8, Endian.little);
    header.setUint32(46, 257, Endian.little);
    expect(
      () => decoder.decode(bytes),
      throwsA(_failure(QrDecodeFailureKind.decoding, 'corrupt-image')),
    );
  });

  test('GivenHugeBmpPalette_WhenDecoded_ThenRejectsBeforeAllocation', () {
    final bytes = Uint8List.fromList(image.encodeBmp(canvas).take(54).toList());
    final header = ByteData.sublistView(bytes);
    header.setUint32(18, 1, Endian.little);
    header.setUint32(22, 1, Endian.little);
    header.setUint16(28, 8, Endian.little);
    header.setUint32(46, 0xffffffff, Endian.little);
    expect(
      () => decoder.decode(bytes),
      throwsA(_failure(QrDecodeFailureKind.decoding, 'corrupt-image')),
    );
  });

  test('GivenExactBudgets_WhenDecoded_ThenAcceptsInclusiveLimits', () {
    final bytes = image.encodePng(canvas);
    final bounded = QrDecoder(
      maxInputBytes: bytes.length,
      maxPixels: 256 * 256,
      maxOutputBytes: 10,
    );
    expect(bounded.decode(bytes).text, 'CHIMERA 27');
  });

  test('GivenPixelBudget_WhenExceeded_ThenReturnsResourceFailure', () {
    expect(
      () => const QrDecoder(maxPixels: 65535).decode(image.encodePng(canvas)),
      throwsA(_failure(QrDecodeFailureKind.resource, 'pixel-limit')),
    );
  });

  test('GivenOutputBudget_WhenUnicodeExceedsUtf8Bytes_ThenReturnsResource', () {
    final bytes = const QrEncoder().encode('éé').pngBytes;
    expect(
      () => const QrDecoder(maxOutputBytes: 3).decode(bytes),
      throwsA(_failure(QrDecodeFailureKind.resource, 'byte-limit')),
    );
    expect(const QrDecoder(maxOutputBytes: 4).decode(bytes).text, 'éé');
  });

  test('GivenAllocationFailure_WhenReadingInput_ThenReturnsTypedResource', () {
    expect(
      () => decoder.decode(_UnreadableBytes(1)),
      throwsA(_failure(QrDecodeFailureKind.resource, 'allocation-limit')),
    );
  });

  final invalid = <String, (List<int>, String)>{
    'Empty': (<int>[], 'empty'),
    'Unsupported': (utf8.encode('private image content'), 'unsupported-format'),
    'Gif': (image.encodeGif(canvas), 'unsupported-format'),
    'CorruptPng': (<int>[137, 80, 78, 71, 13, 10, 26, 10, 0], 'corrupt-image'),
    'CorruptJpeg': (<int>[255, 216, 255], 'corrupt-image'),
    'CorruptBmp': (<int>[66, 77, 0], 'corrupt-image'),
    'NoQr': (
      image.encodePng(image.Image(width: 128, height: 128)),
      'no-qr-code',
    ),
  };
  for (final entry in invalid.entries) {
    test('Given${entry.key}_WhenDecoded_ThenReturnsSafeTypedDecodingError', () {
      expect(
        () => decoder.decode(entry.value.$1),
        throwsA(_failure(QrDecodeFailureKind.decoding, entry.value.$2)),
      );
    });
  }

  test('GivenInvalidByteValues_WhenDecoded_ThenRejectsWithoutTruncation', () {
    expect(
      () => decoder.decode([256, -1]),
      throwsA(_failure(QrDecodeFailureKind.validation, 'invalid-byte')),
    );
  });

  test(
    'GivenTruncatedImageHeaders_WhenDecoded_ThenOnlyThrowsTypedFailures',
    () {
      for (final format in ['png', 'jpeg', 'bmp']) {
        final bytes = _encode(canvas, format);
        for (final length in [1, 2, 3, 7, 8, 14, 18, 26, 33, 54, 100]) {
          expect(
            () => decoder.decode(bytes.sublist(0, length)),
            throwsA(isA<QrDecodeException>()),
            reason: '$format truncated at $length',
          );
        }
      }
    },
  );

  test(
    'GivenMalformedImageHeaders_WhenDecoded_ThenOnlyThrowsTypedFailures',
    () {
      final random = Random(27);
      for (final format in ['png', 'jpeg', 'bmp']) {
        final signature = _encode(canvas, format).take(format == 'png' ? 8 : 2);
        for (var sample = 0; sample < 64; sample++) {
          final bytes = [
            ...signature,
            for (var index = 0; index < 64; index++) random.nextInt(256),
          ];
          expect(
            () => decoder.decode(bytes),
            throwsA(isA<QrDecodeException>()),
            reason: '$format malformed sample $sample',
          );
        }
      }
    },
  );

  test(
    'GivenMutableInput_WhenChangedAfterDecode_ThenResultRetainsOnlyText',
    () {
      final bytes = image.encodePng(canvas);
      final result = decoder.decode(bytes);
      bytes.fillRange(0, bytes.length, 0);
      expect(result.text, 'CHIMERA 27');
      expect(result.inputByteCount, bytes.length);
      expect(
        decoder.decode(image.encodePng(_independentQr('NEXT'))).text,
        'NEXT',
      );
    },
  );
}

Matcher _failure(QrDecodeFailureKind kind, String reason) =>
    isA<QrDecodeException>()
        .having((error) => error.kind, 'kind', kind)
        .having((error) => error.code, 'code', 'qr-decode.${kind.name}')
        .having((error) => error.reason, 'reason', reason);

image.Image _independentQr(String text) {
  final matrix = zxing.Encoder.encode(
    text,
    zxing.ErrorCorrectionLevel.m,
  ).matrix!;
  final canvas = image.Image(width: 256, height: 256, numChannels: 3);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final moduleX = x * (matrix.width + 8) ~/ 256 - 4;
      final moduleY = y * (matrix.height + 8) ~/ 256 - 4;
      final dark =
          moduleX >= 0 &&
          moduleY >= 0 &&
          moduleX < matrix.width &&
          moduleY < matrix.height &&
          matrix.get(moduleX, moduleY) == 1;
      final value = dark ? 0 : 255;
      canvas.setPixelRgb(x, y, value, value, value);
    }
  }
  return canvas;
}

Uint8List _payloadPng(qr.QrPayload payload) {
  final matrix = qr.QrImage(
    qr.QrCode(
      payload: payload,
      errorCorrectLevel: qr.QrErrorCorrectLevel.medium,
    ),
  );
  final canvas = image.Image(width: 256, height: 256, numChannels: 3);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final column = x * (matrix.moduleCount + 8) ~/ 256 - 4;
      final row = y * (matrix.moduleCount + 8) ~/ 256 - 4;
      final dark =
          row >= 0 &&
          column >= 0 &&
          row < matrix.moduleCount &&
          column < matrix.moduleCount &&
          matrix.isDark(row, column);
      final value = dark ? 0 : 255;
      canvas.setPixelRgb(x, y, value, value, value);
    }
  }
  return image.encodePng(canvas);
}

Uint8List _encode(image.Image canvas, String format) => switch (format) {
  'png' => image.encodePng(canvas),
  'jpeg' => image.encodeJpg(canvas, quality: 95),
  'bmp' => image.encodeBmp(canvas),
  _ => throw StateError('Unsupported fixture format'),
};

Uint8List _oversized(Uint8List original, String format) {
  final bytes = Uint8List.fromList(original);
  final data = ByteData.sublistView(bytes);
  switch (format) {
    case 'png':
      data.setUint32(16, 100000);
      data.setUint32(20, 100000);
      data.setUint32(29, getCrc32(bytes.sublist(12, 29)));
    case 'bmp':
      data.setUint32(18, 100000, Endian.little);
      data.setUint32(22, 100000, Endian.little);
    case 'jpeg':
      for (var index = 2; index < bytes.length - 9; index++) {
        if (bytes[index] == 255 && bytes[index + 1] == 192) {
          data.setUint16(index + 5, 65535);
          data.setUint16(index + 7, 65535);
          return bytes;
        }
      }
      throw StateError('Fixture has no JPEG frame');
  }
  return bytes;
}

final class _UnreadableBytes extends ListBase<int> {
  _UnreadableBytes(this.length);

  @override
  int length;

  @override
  int operator [](int index) => throw OutOfMemoryError();

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('read only');
}
