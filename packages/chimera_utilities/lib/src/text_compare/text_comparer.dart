import 'package:characters/characters.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

enum TextCompareGranularity { line, word, character }

extension TextCompareGranularitySlug on TextCompareGranularity {
  String get slug => switch (this) {
    TextCompareGranularity.line => 'line',
    TextCompareGranularity.word => 'word',
    TextCompareGranularity.character => 'character',
  };
}

TextCompareGranularity parseTextCompareGranularity(String value) =>
    switch (value) {
      'line' => TextCompareGranularity.line,
      'word' => TextCompareGranularity.word,
      'character' => TextCompareGranularity.character,
      _ => throw const TextCompareException(
        kind: TextCompareFailureKind.validation,
        code: 'text-compare.invalid-granularity',
        field: 'granularity',
        reason: 'unsupported-granularity',
      ),
    };

enum TextDiffKind { unchanged, removed, added }

extension TextDiffKindSlug on TextDiffKind {
  String get slug => switch (this) {
    TextDiffKind.unchanged => 'unchanged',
    TextDiffKind.removed => 'removed',
    TextDiffKind.added => 'added',
  };
}

final class TextDiffSpan {
  const TextDiffSpan({
    required this.kind,
    required this.text,
    required this.tokenCount,
  });

  final TextDiffKind kind;
  final String text;
  final int tokenCount;
}

final class TextCompareSummary {
  const TextCompareSummary({
    required this.added,
    required this.removed,
    required this.unchanged,
  });

  final int added;
  final int removed;
  final int unchanged;
}

final class TextCompareResult {
  const TextCompareResult({
    required this.granularity,
    required this.spans,
    required this.summary,
  });

  final TextCompareGranularity granularity;
  final List<TextDiffSpan> spans;
  final TextCompareSummary summary;
}

enum TextCompareFailureKind { validation, resource }

final class TextCompareException implements Exception {
  const TextCompareException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final TextCompareFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class TextComparer {
  const TextComparer({
    this.maxInputCodeUnits = 1000000,
    this.maxTokenCount = 100000,
    this.maxDistinctTokens = maxEncodableTokens,
    this.maxWorkUnits = 25000000,
    this.maxResultSpans = 10000,
  }) : assert(
         maxInputCodeUnits == null || maxInputCodeUnits >= 0,
         'maxInputCodeUnits must not be negative',
       ),
       assert(
         maxTokenCount == null || maxTokenCount >= 0,
         'maxTokenCount must not be negative',
       ),
       assert(
         maxDistinctTokens == null || maxDistinctTokens >= 0,
         'maxDistinctTokens must not be negative',
       ),
       assert(
         maxWorkUnits == null || maxWorkUnits >= 0,
         'maxWorkUnits must not be negative',
       ),
       assert(
         maxResultSpans == null || maxResultSpans >= 0,
         'maxResultSpans must not be negative',
       );

  static const int maxEncodableTokens = 63487;

  final int? maxInputCodeUnits;
  final int? maxTokenCount;
  final int? maxDistinctTokens;
  final int? maxWorkUnits;
  final int? maxResultSpans;

  TextCompareResult compare({
    required String left,
    required String right,
    required String granularity,
  }) {
    final parsedGranularity = parseTextCompareGranularity(granularity);
    if (maxInputCodeUnits case final maximum?
        when left.length + right.length > maximum) {
      _throwResourceLimit(field: 'input', reason: 'character-limit');
    }

    try {
      final leftTokens = _tokenize(left, parsedGranularity);
      final rightTokens = _tokenize(right, parsedGranularity);
      final tokenCount = leftTokens.length + rightTokens.length;
      if (maxTokenCount case final maximum? when tokenCount > maximum) {
        _throwResourceLimit(field: 'tokens', reason: 'token-limit');
      }
      if (maxWorkUnits case final maximum?
          when leftTokens.length * rightTokens.length > maximum) {
        _throwResourceLimit(field: 'work', reason: 'work-limit');
      }

      final encoder = _TokenEncoder(maxDistinctTokens: maxDistinctTokens);
      final encodedLeft = encoder.encode(leftTokens);
      final encodedRight = encoder.encode(rightTokens);
      final engine = DiffMatchPatch()..diffTimeout = 0;
      final diffs = engine.diff(encodedLeft, encodedRight, false);
      final spans = <TextDiffSpan>[];
      var added = 0;
      var removed = 0;
      var unchanged = 0;

      for (final diff in diffs) {
        if (diff.text.isEmpty) continue;
        final kind = switch (diff.operation) {
          DIFF_EQUAL => TextDiffKind.unchanged,
          DIFF_DELETE => TextDiffKind.removed,
          DIFF_INSERT => TextDiffKind.added,
          _ => throw StateError('Unsupported diff operation'),
        };
        final decoded = encoder.decode(diff.text);
        final count = diff.text.length;
        switch (kind) {
          case TextDiffKind.unchanged:
            unchanged += count;
          case TextDiffKind.removed:
            removed += count;
          case TextDiffKind.added:
            added += count;
        }
        if (spans.isNotEmpty && spans.last.kind == kind) {
          final previous = spans.removeLast();
          spans.add(
            TextDiffSpan(
              kind: kind,
              text: previous.text + decoded,
              tokenCount: previous.tokenCount + count,
            ),
          );
        } else {
          spans.add(TextDiffSpan(kind: kind, text: decoded, tokenCount: count));
        }
        if (maxResultSpans case final maximum? when spans.length > maximum) {
          _throwResourceLimit(field: 'result', reason: 'span-limit');
        }
      }

      return TextCompareResult(
        granularity: parsedGranularity,
        spans: List<TextDiffSpan>.unmodifiable(spans),
        summary: TextCompareSummary(
          added: added,
          removed: removed,
          unchanged: unchanged,
        ),
      );
    } on TextCompareException {
      rethrow;
    } on OutOfMemoryError {
      _throwResourceLimit(field: 'result', reason: 'allocation-limit');
    }
  }

  List<String> _tokenize(String input, TextCompareGranularity granularity) =>
      switch (granularity) {
        TextCompareGranularity.line => _lineTokens(input),
        TextCompareGranularity.word => _wordTokens(input),
        TextCompareGranularity.character => input.characters.toList(
          growable: false,
        ),
      };

  List<String> _lineTokens(String input) {
    if (input.isEmpty) return const <String>[];
    final tokens = <String>[];
    var start = 0;
    var index = 0;
    while (index < input.length) {
      final codeUnit = input.codeUnitAt(index);
      if (codeUnit != 0x0A && codeUnit != 0x0D) {
        index++;
        continue;
      }
      tokens.add('${input.substring(start, index)}\n');
      if (codeUnit == 0x0D &&
          index + 1 < input.length &&
          input.codeUnitAt(index + 1) == 0x0A) {
        index++;
      }
      index++;
      start = index;
    }
    if (start < input.length) tokens.add(input.substring(start));
    return tokens;
  }

  List<String> _wordTokens(String input) {
    if (input.isEmpty) return const <String>[];
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool? whitespace;
    for (final character in input.characters) {
      final isWhitespace = character.runes.every(_isUnicodeWhiteSpace);
      if (whitespace != null && whitespace != isWhitespace) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      buffer.write(character);
      whitespace = isWhitespace;
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }
}

final class _TokenEncoder {
  _TokenEncoder({required this.maxDistinctTokens});

  final int? maxDistinctTokens;
  final Map<String, int> _symbols = <String, int>{};
  final Map<int, String> _tokens = <int, String>{};
  int _nextSymbol = 1;

  String encode(List<String> tokens) => String.fromCharCodes(
    tokens.map((token) => _symbols[token] ?? _addToken(token)),
  );

  String decode(String encoded) {
    final output = StringBuffer();
    for (final symbol in encoded.codeUnits) {
      output.write(_tokens[symbol]);
    }
    return output.toString();
  }

  int _addToken(String token) {
    if (maxDistinctTokens case final maximum? when _symbols.length >= maximum) {
      _throwResourceLimit(field: 'symbols', reason: 'symbol-limit');
    }
    if (_nextSymbol == 0xD800) _nextSymbol = 0xE000;
    if (_nextSymbol > 0xFFFF) {
      _throwResourceLimit(field: 'symbols', reason: 'symbol-limit');
    }
    final symbol = _nextSymbol++;
    _symbols[token] = symbol;
    _tokens[symbol] = token;
    return symbol;
  }
}

bool _isUnicodeWhiteSpace(int rune) =>
    (rune >= 0x0009 && rune <= 0x000D) ||
    rune == 0x0020 ||
    rune == 0x0085 ||
    rune == 0x00A0 ||
    rune == 0x1680 ||
    (rune >= 0x2000 && rune <= 0x200A) ||
    rune == 0x2028 ||
    rune == 0x2029 ||
    rune == 0x202F ||
    rune == 0x205F ||
    rune == 0x3000;

Never _throwResourceLimit({required String field, required String reason}) =>
    throw TextCompareException(
      kind: TextCompareFailureKind.resource,
      code: 'text-compare.resource-limit',
      field: field,
      reason: reason,
    );
