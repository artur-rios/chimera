import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:qr/qr.dart' as qr;

enum QrErrorCorrection { low, medium, quartile, high }

enum QrEncodeFailureKind { validation, resource }

final class QrEncodeException implements Exception {
  const QrEncodeException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final QrEncodeFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class QrEncodeResult {
  QrEncodeResult({
    required List<int> pngBytes,
    required this.size,
    required this.version,
    required this.moduleCount,
    required this.errorCorrection,
    required this.quietZoneModules,
    required this.foreground,
    required this.background,
    required this.inputByteCount,
  }) : pngBytes = Uint8List.fromList(pngBytes);

  final Uint8List pngBytes;
  final int size;
  final int version;
  final int moduleCount;
  final QrErrorCorrection errorCorrection;
  final int quietZoneModules;
  final String foreground;
  final String background;
  final int inputByteCount;

  int get outputByteCount => pngBytes.length;
}

final class QrEncoder {
  const QrEncoder({
    this.maxInputBytes = defaultMaxInputBytes,
    this.maxOutputBytes = defaultMaxOutputBytes,
  }) : assert(maxInputBytes == null || maxInputBytes >= 0),
       assert(maxOutputBytes == null || maxOutputBytes >= 0);

  static const int defaultMaxInputBytes = 8192;
  static const int defaultMaxOutputBytes = 64 * 1024 * 1024;
  static const int minimumSize = 64;
  static const int maximumSize = 4096;
  static const int maximumQuietZoneModules = 32;

  final int? maxInputBytes;
  final int? maxOutputBytes;

  QrEncodeResult encode(
    String input, {
    QrErrorCorrection errorCorrection = QrErrorCorrection.medium,
    int size = 512,
    int quietZoneModules = 4,
    String foreground = '#000000',
    String background = '#FFFFFF',
  }) {
    try {
      if (input.isEmpty) {
        _validation(field: 'input', reason: 'empty');
      }
      final inputByteCount = _validateAndCountUtf8(input);
      if (size < minimumSize || size > maximumSize) {
        _validation(field: 'size', reason: 'range');
      }
      if (quietZoneModules < 0 || quietZoneModules > maximumQuietZoneModules) {
        _validation(field: 'quietZoneModules', reason: 'range');
      }

      final normalizedForeground = _normalizeColor(
        foreground,
        field: 'foreground',
      );
      final normalizedBackground = _normalizeColor(
        background,
        field: 'background',
      );
      if (normalizedForeground == normalizedBackground) {
        _validation(field: 'colors', reason: 'indistinguishable');
      }

      final payload = qr.QrPayload();
      if (input.codeUnits.any((unit) => unit > 0x7F)) {
        payload.addECI(qr.QrEciValue.utf8);
      }
      payload.addString(input);
      final code = qr.QrCode(
        payload: payload,
        errorCorrectLevel: _toPackageLevel(errorCorrection),
      );
      final matrix = qr.QrImage(code);
      final totalModuleCount = matrix.moduleCount + quietZoneModules * 2;
      if (size < totalModuleCount) {
        _validation(field: 'size', reason: 'module-resolution');
      }

      final foregroundRgb = _parseColor(normalizedForeground);
      final backgroundRgb = _parseColor(normalizedBackground);
      final canvas = image.Image(width: size, height: size, numChannels: 3);
      image.fill(
        canvas,
        color: image.ColorRgb8(
          backgroundRgb.$1,
          backgroundRgb.$2,
          backgroundRgb.$3,
        ),
      );
      final darkColor = image.ColorRgb8(
        foregroundRgb.$1,
        foregroundRgb.$2,
        foregroundRgb.$3,
      );
      for (var row = 0; row < matrix.moduleCount; row++) {
        for (var column = 0; column < matrix.moduleCount; column++) {
          if (!matrix.isDark(row, column)) continue;
          final left = (column + quietZoneModules) * size ~/ totalModuleCount;
          final top = (row + quietZoneModules) * size ~/ totalModuleCount;
          final right =
              ((column + quietZoneModules + 1) * size ~/ totalModuleCount) - 1;
          final bottom =
              ((row + quietZoneModules + 1) * size ~/ totalModuleCount) - 1;
          image.fillRect(
            canvas,
            x1: left,
            y1: top,
            x2: right,
            y2: bottom,
            color: darkColor,
            alphaBlend: false,
          );
        }
      }

      final pngBytes = image.encodePng(canvas);
      if (maxOutputBytes case final maximum? when pngBytes.length > maximum) {
        _resource(field: 'output', reason: 'byte-limit');
      }
      return QrEncodeResult(
        pngBytes: pngBytes,
        size: size,
        version: code.typeNumber,
        moduleCount: matrix.moduleCount,
        errorCorrection: errorCorrection,
        quietZoneModules: quietZoneModules,
        foreground: normalizedForeground,
        background: normalizedBackground,
        inputByteCount: inputByteCount,
      );
    } on QrEncodeException {
      rethrow;
    } on qr.InputTooLongException {
      _validation(field: 'input', reason: 'capacity');
    } on OutOfMemoryError {
      _resource(field: 'output', reason: 'allocation-limit');
    }
  }

  int _validateAndCountUtf8(String value) {
    var length = 0;
    for (var index = 0; index < value.length; index++) {
      final unit = value.codeUnitAt(index);
      late final int width;
      if (unit <= 0x7F) {
        width = 1;
      } else if (unit <= 0x7FF) {
        width = 2;
      } else if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (index + 1 >= value.length) {
          _validation(field: 'input', reason: 'invalid-unicode');
        }
        final next = value.codeUnitAt(index + 1);
        if (next < 0xDC00 || next > 0xDFFF) {
          _validation(field: 'input', reason: 'invalid-unicode');
        }
        index++;
        width = 4;
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        _validation(field: 'input', reason: 'invalid-unicode');
      } else {
        width = 3;
      }
      if (maxInputBytes case final maximum? when length > maximum - width) {
        _resource(field: 'input', reason: 'byte-limit');
      }
      length += width;
    }
    return length;
  }

  static String _normalizeColor(String value, {required String field}) {
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      _validation(field: field, reason: 'color-format');
    }
    return value.toUpperCase();
  }

  static (int, int, int) _parseColor(String value) => (
    int.parse(value.substring(1, 3), radix: 16),
    int.parse(value.substring(3, 5), radix: 16),
    int.parse(value.substring(5, 7), radix: 16),
  );

  static qr.QrErrorCorrectLevel _toPackageLevel(QrErrorCorrection value) =>
      switch (value) {
        QrErrorCorrection.low => qr.QrErrorCorrectLevel.low,
        QrErrorCorrection.medium => qr.QrErrorCorrectLevel.medium,
        QrErrorCorrection.quartile => qr.QrErrorCorrectLevel.quartile,
        QrErrorCorrection.high => qr.QrErrorCorrectLevel.high,
      };

  static Never _validation({required String field, required String reason}) =>
      throw QrEncodeException(
        kind: QrEncodeFailureKind.validation,
        code: 'qr-encode.invalid-input',
        field: field,
        reason: reason,
      );

  static Never _resource({required String field, required String reason}) =>
      throw QrEncodeException(
        kind: QrEncodeFailureKind.resource,
        code: 'qr-encode.resource-limit',
        field: field,
        reason: reason,
      );
}
