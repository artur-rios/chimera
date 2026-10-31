import 'dart:convert';

import 'package:meta/meta.dart';

enum UrlEncodeFailureKind { validation, resource }

/// Safe failure details, without source, output, or dependency exceptions.
final class UrlEncodeException implements Exception {
  const UrlEncodeException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
  });

  final UrlEncodeFailureKind kind;
  final String code;
  final String field;
  final String reason;
}

final class UrlEncodeRequest {
  const UrlEncodeRequest({required this.input, this.mode = 'component'});

  final String input;
  final String mode;
}

final class UrlEncodeResult {
  const UrlEncodeResult({required this.encoded, required this.mode});

  final String encoded;
  final String mode;
}

/// Stateless percent encoding using the Dart URI full/component primitives.
final class UrlEncoder {
  const UrlEncoder({this.maxInputCharacters, this.maxOutputCharacters})
    : _convert = _convertUrl,
      assert(maxInputCharacters == null || maxInputCharacters >= 0),
      assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  /// Injection at the conversion allocation boundary for resource tests.
  @visibleForTesting
  const UrlEncoder.forTesting({
    this.maxInputCharacters,
    this.maxOutputCharacters,
    this._convert = _convertUrl,
  }) : assert(maxInputCharacters == null || maxInputCharacters >= 0),
       assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  /// Optional UTF-16 code-unit budgets; production defaults impose no ceiling.
  final int? maxInputCharacters;
  final int? maxOutputCharacters;
  final String Function(String, String) _convert;

  UrlEncodeResult encodeText(UrlEncodeRequest request) {
    try {
      final mode = _modeFor(request.mode);
      _validateUnicodeScalars(request.input);
      if (maxInputCharacters case final maximum?
          when request.input.length > maximum) {
        _throwResource(field: 'input', reason: 'input-limit');
      }
      final encoded = _convert(request.input, mode);
      if (maxOutputCharacters case final maximum?
          when encoded.length > maximum) {
        _throwResource(field: 'encoded', reason: 'output-limit');
      }
      return UrlEncodeResult(encoded: encoded, mode: request.mode);
    } on OutOfMemoryError {
      _throwResource(field: 'encoded', reason: 'allocation-limit');
    }
  }

  UrlEncodeResult encodeUtf8(List<int> input, {String mode = 'component'}) {
    _modeFor(mode);
    late final String text;
    try {
      for (final byte in input) {
        if (byte < 0 || byte > 0xff) _throwInvalidInput('invalid-utf8');
      }
      final decoded = utf8.decode(input, allowMalformed: false);
      // The SDK strips one leading UTF-8 BOM; Chimera preserves source text.
      final hasBom =
          input.length >= 3 &&
          input[0] == 0xef &&
          input[1] == 0xbb &&
          input[2] == 0xbf;
      text = hasBom ? '\uFEFF$decoded' : decoded;
    } on FormatException {
      _throwInvalidInput('invalid-utf8');
    } on OutOfMemoryError {
      _throwResource(field: 'input', reason: 'allocation-limit');
    }
    return encodeText(UrlEncodeRequest(input: text, mode: mode));
  }

  String _modeFor(String mode) => switch (mode) {
    'full' || 'component' => mode,
    _ => throw const UrlEncodeException(
      kind: UrlEncodeFailureKind.validation,
      code: 'url-encode.invalid-mode',
      field: 'mode',
      reason: 'unsupported-mode',
    ),
  };

  void _validateUnicodeScalars(String input) {
    for (var index = 0; index < input.length; index++) {
      final unit = input.codeUnitAt(index);
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (index + 1 >= input.length ||
            input.codeUnitAt(index + 1) < 0xdc00 ||
            input.codeUnitAt(index + 1) > 0xdfff) {
          _throwInvalidInput('invalid-unicode');
        }
        index++;
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        _throwInvalidInput('invalid-unicode');
      }
    }
  }

  Never _throwInvalidInput(String reason) => throw UrlEncodeException(
    kind: UrlEncodeFailureKind.validation,
    code: 'url-encode.invalid-input',
    field: 'input',
    reason: reason,
  );

  Never _throwResource({required String field, required String reason}) =>
      throw UrlEncodeException(
        kind: UrlEncodeFailureKind.resource,
        code: 'url-encode.resource-limit',
        field: field,
        reason: reason,
      );
}

String _convertUrl(String input, String mode) =>
    mode == 'full' ? Uri.encodeFull(input) : Uri.encodeComponent(input);
