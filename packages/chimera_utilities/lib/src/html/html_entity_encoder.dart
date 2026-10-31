import 'dart:convert';

import 'package:meta/meta.dart';

enum HtmlEntityEncodeFailureKind { validation, resource }

/// Safe failure details, without source, output, or dependency exceptions.
final class HtmlEntityEncodeException implements Exception {
  const HtmlEntityEncodeException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
  });

  final HtmlEntityEncodeFailureKind kind;
  final String code;
  final String field;
  final String reason;
}

final class HtmlEntityEncodeRequest {
  const HtmlEntityEncodeRequest({required this.input, this.context = 'all'});

  final String input;
  final String context;
}

final class HtmlEntityEncodeResult {
  const HtmlEntityEncodeResult({required this.encoded, required this.context});

  final String encoded;
  final String context;
}

/// Stateless HTML entity encoding for normal elements and quoted attributes.
final class HtmlEntityEncoder {
  const HtmlEntityEncoder({this.maxInputCharacters, this.maxOutputCharacters})
    : _convert = _convertHtml,
      assert(maxInputCharacters == null || maxInputCharacters >= 0),
      assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  /// Injection at the conversion allocation boundary for resource tests.
  @visibleForTesting
  const HtmlEntityEncoder.forTesting({
    this.maxInputCharacters,
    this.maxOutputCharacters,
    this._convert = _convertHtml,
  }) : assert(maxInputCharacters == null || maxInputCharacters >= 0),
       assert(maxOutputCharacters == null || maxOutputCharacters >= 0);

  /// Optional UTF-16 code-unit budgets; production defaults impose no ceiling.
  final int? maxInputCharacters;
  final int? maxOutputCharacters;
  final String Function(String, HtmlEscapeMode) _convert;

  HtmlEntityEncodeResult encodeText(HtmlEntityEncodeRequest request) {
    try {
      final mode = _modeFor(request.context);
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
      return HtmlEntityEncodeResult(encoded: encoded, context: request.context);
    } on OutOfMemoryError {
      _throwResource(field: 'encoded', reason: 'allocation-limit');
    }
  }

  HtmlEntityEncodeResult encodeUtf8(List<int> input, {String context = 'all'}) {
    _modeFor(context);
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
    return encodeText(HtmlEntityEncodeRequest(input: text, context: context));
  }

  HtmlEscapeMode _modeFor(String context) => switch (context) {
    'all' => HtmlEscapeMode.unknown,
    'element' => HtmlEscapeMode.element,
    'double-quoted-attribute' => HtmlEscapeMode.attribute,
    'single-quoted-attribute' => HtmlEscapeMode.sqAttribute,
    _ => throw const HtmlEntityEncodeException(
      kind: HtmlEntityEncodeFailureKind.validation,
      code: 'html-encode.invalid-context',
      field: 'context',
      reason: 'unsupported-context',
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

  Never _throwInvalidInput(String reason) => throw HtmlEntityEncodeException(
    kind: HtmlEntityEncodeFailureKind.validation,
    code: 'html-encode.invalid-input',
    field: 'input',
    reason: reason,
  );

  Never _throwResource({required String field, required String reason}) =>
      throw HtmlEntityEncodeException(
        kind: HtmlEntityEncodeFailureKind.resource,
        code: 'html-encode.resource-limit',
        field: field,
        reason: reason,
      );
}

String _convertHtml(String input, HtmlEscapeMode mode) =>
    HtmlEscape(mode).convert(input);
