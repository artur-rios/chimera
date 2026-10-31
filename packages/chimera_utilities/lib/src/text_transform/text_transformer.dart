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
    final parsedMode = parseTextTransformMode(mode);
    if (maxInputCodeUnits case final maximum? when input.length > maximum) {
      _throwResourceLimit(field: 'input', reason: 'character-limit');
    }

    try {
      final output = switch (parsedMode) {
        TextTransformMode.lowercase => _lowercase(input),
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

  String _normalizeWhitespace(String input) {
    var output = input.replaceAll(_whiteSpacePattern, ' ');
    if (output.startsWith(' ')) output = output.substring(1);
    if (output.endsWith(' ')) output = output.substring(0, output.length - 1);
    return output;
  }

  String _lowercase(String input) =>
      input.replaceAll('\u0130', 'i\u0307').toLowerCase();

  String _uppercase(String input) {
    final expanded = StringBuffer();
    for (final rune in input.runes) {
      expanded.write(_fullUppercaseMapping(rune) ?? String.fromCharCode(rune));
    }
    return expanded.toString().toUpperCase();
  }

  // Unicode 15.1 SpecialCasing.txt unconditional full uppercase mappings.
  String? _fullUppercaseMapping(int rune) {
    if (rune >= 0x1F80 && rune <= 0x1F87) {
      return String.fromCharCodes(<int>[0x1F08 + rune - 0x1F80, 0x0399]);
    }
    if (rune >= 0x1F88 && rune <= 0x1F8F) {
      return String.fromCharCodes(<int>[0x1F08 + rune - 0x1F88, 0x0399]);
    }
    if (rune >= 0x1F90 && rune <= 0x1F97) {
      return String.fromCharCodes(<int>[0x1F28 + rune - 0x1F90, 0x0399]);
    }
    if (rune >= 0x1F98 && rune <= 0x1F9F) {
      return String.fromCharCodes(<int>[0x1F28 + rune - 0x1F98, 0x0399]);
    }
    if (rune >= 0x1FA0 && rune <= 0x1FA7) {
      return String.fromCharCodes(<int>[0x1F68 + rune - 0x1FA0, 0x0399]);
    }
    if (rune >= 0x1FA8 && rune <= 0x1FAF) {
      return String.fromCharCodes(<int>[0x1F68 + rune - 0x1FA8, 0x0399]);
    }
    return _unconditionalUppercaseMappings[rune];
  }

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

const Map<int, String> _unconditionalUppercaseMappings = <int, String>{
  0x00DF: 'SS',
  0x0149: '\u02BCN',
  0x01F0: 'J\u030C',
  0x0390: '\u0399\u0308\u0301',
  0x03B0: '\u03A5\u0308\u0301',
  0x0587: '\u0535\u0552',
  0x1E96: 'H\u0331',
  0x1E97: 'T\u0308',
  0x1E98: 'W\u030A',
  0x1E99: 'Y\u030A',
  0x1E9A: 'A\u02BE',
  0x1F50: '\u03A5\u0313',
  0x1F52: '\u03A5\u0313\u0300',
  0x1F54: '\u03A5\u0313\u0301',
  0x1F56: '\u03A5\u0313\u0342',
  0x1FB2: '\u1FBA\u0399',
  0x1FB3: '\u0391\u0399',
  0x1FB4: '\u0386\u0399',
  0x1FB6: '\u0391\u0342',
  0x1FB7: '\u0391\u0342\u0399',
  0x1FBC: '\u0391\u0399',
  0x1FC2: '\u1FCA\u0399',
  0x1FC3: '\u0397\u0399',
  0x1FC4: '\u0389\u0399',
  0x1FC6: '\u0397\u0342',
  0x1FC7: '\u0397\u0342\u0399',
  0x1FCC: '\u0397\u0399',
  0x1FD2: '\u0399\u0308\u0300',
  0x1FD3: '\u0399\u0308\u0301',
  0x1FD6: '\u0399\u0342',
  0x1FD7: '\u0399\u0308\u0342',
  0x1FE2: '\u03A5\u0308\u0300',
  0x1FE3: '\u03A5\u0308\u0301',
  0x1FE4: '\u03A1\u0313',
  0x1FE6: '\u03A5\u0342',
  0x1FE7: '\u03A5\u0308\u0342',
  0x1FF2: '\u1FFA\u0399',
  0x1FF3: '\u03A9\u0399',
  0x1FF4: '\u038F\u0399',
  0x1FF6: '\u03A9\u0342',
  0x1FF7: '\u03A9\u0342\u0399',
  0x1FFC: '\u03A9\u0399',
  0xFB00: 'FF',
  0xFB01: 'FI',
  0xFB02: 'FL',
  0xFB03: 'FFI',
  0xFB04: 'FFL',
  0xFB05: 'ST',
  0xFB06: 'ST',
  0xFB13: '\u0544\u0546',
  0xFB14: '\u0544\u0535',
  0xFB15: '\u0544\u053B',
  0xFB16: '\u054E\u0546',
  0xFB17: '\u0544\u053D',
};

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
