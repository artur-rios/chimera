import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:zxing2/qrcode.dart' as zxing;

enum QrDecodeFailureKind { validation, decoding, resource }

final class QrDecodeException implements Exception {
  const QrDecodeException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final QrDecodeFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class QrDecodeResult {
  const QrDecodeResult({
    required this.text,
    required this.format,
    required this.width,
    required this.height,
    required this.inputByteCount,
  });

  final String text;
  final String format;
  final int width;
  final int height;
  final int inputByteCount;
}

/// Decodes one QR symbol locally without retaining the input image.
final class QrDecoder {
  const QrDecoder({
    this.maxInputBytes = defaultMaxInputBytes,
    this.maxPixels = defaultMaxPixels,
    this.maxOutputBytes = defaultMaxOutputBytes,
  }) : assert(maxInputBytes >= 0),
       assert(maxPixels >= 0),
       assert(maxOutputBytes >= 0);

  static const int defaultMaxInputBytes = 16 * 1024 * 1024;
  static const int defaultMaxPixels = 16777216;
  static const int defaultMaxOutputBytes = 8192;

  final int maxInputBytes;
  final int maxPixels;
  final int maxOutputBytes;

  QrDecodeResult decode(List<int> bytes) {
    try {
      if (bytes.length > maxInputBytes) {
        _fail(QrDecodeFailureKind.resource, 'input', 'byte-limit');
      }
      if (bytes.isEmpty) {
        _fail(QrDecodeFailureKind.decoding, 'input', 'empty');
      }
      for (final byte in bytes) {
        if (byte < 0 || byte > 255) {
          _fail(QrDecodeFailureKind.validation, 'input', 'invalid-byte');
        }
      }
      final encoded = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      final (format, decoder) = _imageDecoder(encoded);
      final metadata = decoder.startDecode(encoded);
      if (metadata == null || metadata.width < 1 || metadata.height < 1) {
        _fail(QrDecodeFailureKind.decoding, 'input', 'corrupt-image');
      }
      // Divide before multiplying: large dimensions must also be safe on web.
      if (metadata.width > maxPixels ~/ metadata.height) {
        _fail(QrDecodeFailureKind.resource, 'input', 'pixel-limit');
      }
      final raster = decoder.decodeFrame(0);
      if (raster == null || raster.width < 1 || raster.height < 1) {
        _fail(QrDecodeFailureKind.decoding, 'input', 'corrupt-image');
      }
      final source = zxing.RGBLuminanceSource(
        raster.width,
        raster.height,
        raster
            .convert(format: image.Format.uint8, numChannels: 4)
            .getBytes(order: image.ChannelOrder.bgra)
            .buffer
            .asInt32List(),
      );
      final bitmap = zxing.BinaryBitmap(zxing.HybridBinarizer(source));
      final text = _readText(bitmap);
      if (_QrDecodeUtf8Budget.exceeds(text, maxOutputBytes)) {
        _fail(QrDecodeFailureKind.resource, 'output', 'byte-limit');
      }
      return QrDecodeResult(
        text: text,
        format: format,
        width: metadata.width,
        height: metadata.height,
        inputByteCount: encoded.length,
      );
    } on QrDecodeException {
      rethrow;
    } on OutOfMemoryError {
      _fail(QrDecodeFailureKind.resource, 'input', 'allocation-limit');
    } on image.ImageException catch (error) {
      // image 4.12 wraps all errors, including VM allocation failures.
      if (error.message.contains('Out of Memory') ||
          error.message.contains('OutOfMemoryError')) {
        _fail(QrDecodeFailureKind.resource, 'input', 'allocation-limit');
      }
      _fail(QrDecodeFailureKind.decoding, 'input', 'corrupt-image');
    } on zxing.ReaderException {
      _fail(QrDecodeFailureKind.decoding, 'input', 'no-qr-code');
    } on FormatException {
      _fail(QrDecodeFailureKind.decoding, 'input', 'invalid-text');
    } catch (_) {
      _fail(QrDecodeFailureKind.decoding, 'input', 'corrupt-image');
    }
  }

  (String, image.Decoder) _imageDecoder(Uint8List bytes) {
    // Metadata readers run with their internal limit disabled so the shared,
    // overflow-safe check above classifies oversized images as resource errors.
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10) {
      return ('png', image.PngDecoder(maxPixels: 0));
    }
    if (bytes.length >= 2 && bytes[0] == 255 && bytes[1] == 216) {
      return ('jpeg', image.JpegDecoder(maxPixels: 0));
    }
    if (bytes.length >= 2 && bytes[0] == 66 && bytes[1] == 77) {
      _checkBmpPalette(bytes);
      return ('bmp', image.BmpDecoder(maxPixels: 0));
    }
    _fail(QrDecodeFailureKind.decoding, 'input', 'unsupported-format');
  }

  static void _checkBmpPalette(Uint8List bytes) {
    // BmpInfo allocates its palette while reading metadata. Validate its size
    // against the bit depth and available bytes before invoking that reader.
    if (bytes.length < 54) {
      _fail(QrDecodeFailureKind.decoding, 'input', 'corrupt-image');
    }
    final header = ByteData.sublistView(bytes);
    final headerSize = header.getUint32(14, Endian.little);
    final bits = header.getUint16(28, Endian.little);
    if (bits <= 8) {
      if (bits != 1 && bits != 4 && bits != 8) {
        _fail(QrDecodeFailureKind.decoding, 'input', 'corrupt-image');
      }
      final declaredColors = header.getUint32(46, Endian.little);
      final colors = declaredColors == 0 ? 1 << bits : declaredColors;
      final paletteOffset = 14 + headerSize;
      final pixelOffset = header.getUint32(10, Endian.little);
      if (colors > 1 << bits ||
          paletteOffset > bytes.length ||
          colors > (bytes.length - paletteOffset) ~/ 4 ||
          pixelOffset < paletteOffset + colors * 4) {
        _fail(QrDecodeFailureKind.decoding, 'input', 'corrupt-image');
      }
    }
  }

  static String _readText(zxing.BinaryBitmap bitmap) {
    // zxing2 0.2.4 decodes byte-mode segments through signed Int8List values.
    // Normalize at the codec boundary, preserving ECI selection and mixed-mode
    // segment order. This entire call is synchronous; restore the codecs even
    // when detection or text decoding fails, and retain no image or text there.
    final codecs = <zxing.CharacterSetECI, Encoding>{
      for (final charset in zxing.CharacterSetECI.all)
        charset: charset.encoding,
    };
    try {
      for (final entry in codecs.entries) {
        final strictDecoder = switch (entry.key.getValue()) {
          1 => latin1.decoder,
          26 => utf8.decoder,
          27 => ascii.decoder,
          _ => const _UnsupportedTextDecoder(),
        };
        entry.key.encoding = _UnsignedEncoding(entry.value, strictDecoder);
      }
      return zxing.QRCodeReader().decode(bitmap).text;
    } finally {
      for (final entry in codecs.entries) {
        entry.key.encoding = entry.value;
      }
    }
  }

  static Never _fail(QrDecodeFailureKind kind, String field, String reason) =>
      throw QrDecodeException(
        kind: kind,
        code: 'qr-decode.${kind.name}',
        field: field,
        reason: reason,
      );
}

final class _UnsignedEncoding extends Encoding {
  _UnsignedEncoding(this.delegate, this.textDecoder);

  final Encoding delegate;
  final Converter<List<int>, String> textDecoder;

  @override
  String get name => delegate.name;

  @override
  Converter<List<int>, String> get decoder => _UnsignedDecoder(textDecoder);

  @override
  Converter<String, List<int>> get encoder => delegate.encoder;
}

final class _UnsupportedTextDecoder extends Converter<List<int>, String> {
  const _UnsupportedTextDecoder();

  @override
  String convert(List<int> input) => throw const FormatException();
}

final class _UnsignedDecoder extends Converter<List<int>, String> {
  const _UnsignedDecoder(this.delegate);

  final Converter<List<int>, String> delegate;

  @override
  String convert(List<int> input) =>
      delegate.convert(Uint8List.fromList(input));
}

// Counts without allocating an encoded copy of the decoded content.
abstract final class _QrDecodeUtf8Budget {
  static bool exceeds(String value, int limit) {
    var length = 0;
    for (final rune in value.runes) {
      final width = switch (rune) {
        <= 0x7F => 1,
        <= 0x7FF => 2,
        <= 0xFFFF => 3,
        _ => 4,
      };
      if (length > limit - width) return true;
      length += width;
    }
    return false;
  }
}
