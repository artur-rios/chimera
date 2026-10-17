enum TextTransformMode {
  lowercase,
  uppercase,
  normalizeWhitespace,
  sortLines,
  deduplicateLines,
}

extension TextTransformModeSlug on TextTransformMode {
  String get slug => switch (this) {
    TextTransformMode.lowercase => 'lowercase',
    TextTransformMode.uppercase => 'uppercase',
    TextTransformMode.normalizeWhitespace => 'normalize-whitespace',
    TextTransformMode.sortLines => 'sort-lines',
    TextTransformMode.deduplicateLines => 'deduplicate-lines',
  };
}

TextTransformMode parseTextTransformMode(String value) => switch (value) {
  'lowercase' => TextTransformMode.lowercase,
  'uppercase' => TextTransformMode.uppercase,
  'normalize-whitespace' => TextTransformMode.normalizeWhitespace,
  'sort-lines' => TextTransformMode.sortLines,
  'deduplicate-lines' => TextTransformMode.deduplicateLines,
  _ => _throwInvalidMode(),
};

enum TextTransformFailureKind { validation, resource }

final class TextTransformException implements Exception {
  const TextTransformException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final TextTransformFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class TextTransformResult {
  const TextTransformResult({required this.mode, required this.output});

  final TextTransformMode mode;
  final String output;
}

final class TextTransformer {
  const TextTransformer({this.maxInputCodeUnits, this.maxOutputCodeUnits})
    : assert(
        maxInputCodeUnits == null || maxInputCodeUnits >= 0,
        'maxInputCodeUnits must not be negative',
      ),
      assert(
        maxOutputCodeUnits == null || maxOutputCodeUnits >= 0,
        'maxOutputCodeUnits must not be negative',
      );

  static final RegExp _whiteSpacePattern = RegExp(
    r'[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A'
    r'\u2028\u2029\u202F\u205F\u3000]+',
    unicode: true,
  );
  static final RegExp _lineBoundaryPattern = RegExp(r'\r\n|\r|\n');

  final int? maxInputCodeUnits;
  final int? maxOutputCodeUnits;

  TextTransformResult transform({required String input, required String mode}) {
    if (maxInputCodeUnits case final maximum? when input.length > maximum) {
      _throwResourceLimit(field: 'input', reason: 'character-limit');
    }

    try {
      final parsedMode = parseTextTransformMode(mode);
      final output = switch (parsedMode) {
        TextTransformMode.lowercase => input.toLowerCase(),
        TextTransformMode.uppercase => _uppercase(input),
        TextTransformMode.normalizeWhitespace => _normalizeWhitespace(input),
        TextTransformMode.sortLines => _sortLines(input),
        TextTransformMode.deduplicateLines => _deduplicateLines(input),
      };

      if (maxOutputCodeUnits case final maximum? when output.length > maximum) {
        _throwResourceLimit(field: 'output', reason: 'character-limit');
      }

      return TextTransformResult(mode: parsedMode, output: output);
    } on TextTransformException {
      rethrow;
    } on OutOfMemoryError {
      _throwResourceLimit(field: 'output', reason: 'allocation-limit');
    }
  }

  String _normalizeWhitespace(String input) =>
      input.replaceAll(_whiteSpacePattern, ' ').trim();

  String _uppercase(String input) => input
      .replaceAll('ß', 'SS')
      .replaceAll('ﬀ', 'FF')
      .replaceAll('ﬁ', 'FI')
      .replaceAll('ﬂ', 'FL')
      .replaceAll('ﬃ', 'FFI')
      .replaceAll('ﬄ', 'FFL')
      .replaceAll('ﬅ', 'ST')
      .replaceAll('ﬆ', 'ST')
      .toUpperCase();

  String _sortLines(String input) {
    final parsed = _parseLines(input);
    if (parsed == null) return '';
    parsed.lines.sort(_compareUtf16CodeUnits);
    return _joinLines(parsed);
  }

  String _deduplicateLines(String input) {
    final parsed = _parseLines(input);
    if (parsed == null) return '';
    final seen = <String>{};
    final unique = <String>[];
    for (final line in parsed.lines) {
      if (seen.add(line)) unique.add(line);
    }
    return _joinLines((
      lines: unique,
      hasTrailingBoundary: parsed.hasTrailingBoundary,
    ));
  }

  ({List<String> lines, bool hasTrailingBoundary})? _parseLines(String input) {
    if (input.isEmpty) return null;
    final hasTrailingBoundary = input.endsWith('\n') || input.endsWith('\r');
    final lines = input.split(_lineBoundaryPattern);
    if (hasTrailingBoundary) lines.removeLast();
    return (lines: lines, hasTrailingBoundary: hasTrailingBoundary);
  }

  String _joinLines(({List<String> lines, bool hasTrailingBoundary}) parsed) {
    final output = parsed.lines.join('\n');
    return parsed.hasTrailingBoundary ? '$output\n' : output;
  }

  int _compareUtf16CodeUnits(String left, String right) {
    final sharedLength = left.length < right.length
        ? left.length
        : right.length;
    for (var index = 0; index < sharedLength; index++) {
      final difference = left.codeUnitAt(index) - right.codeUnitAt(index);
      if (difference != 0) return difference;
    }
    return left.length - right.length;
  }
}

Never _throwInvalidMode() => throw const TextTransformException(
  kind: TextTransformFailureKind.validation,
  code: 'text-transform.invalid-mode',
  field: 'mode',
  reason: 'unsupported-mode',
);

Never _throwResourceLimit({required String field, required String reason}) =>
    throw TextTransformException(
      kind: TextTransformFailureKind.resource,
      code: 'text-transform.resource-limit',
      field: field,
      reason: reason,
    );
