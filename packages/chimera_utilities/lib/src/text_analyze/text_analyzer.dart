import 'dart:convert';

import 'package:characters/characters.dart';

enum TextAnalyzeFailureKind { resource }

final class TextAnalyzeException implements Exception {
  const TextAnalyzeException({
    required this.kind,
    required this.code,
    this.field,
    this.reason,
  });

  final TextAnalyzeFailureKind kind;
  final String code;
  final String? field;
  final String? reason;
}

final class TextAnalyzeResult {
  const TextAnalyzeResult({
    required this.characterCount,
    required this.wordCount,
    required this.lineCount,
    required this.byteCount,
  });

  final int characterCount;
  final int wordCount;
  final int lineCount;
  final int byteCount;
}

final class TextAnalyzer {
  const TextAnalyzer({this.maxInputCodeUnits})
    : assert(
        maxInputCodeUnits == null || maxInputCodeUnits >= 0,
        'maxInputCodeUnits must not be negative',
      );

  static final RegExp _wordPattern = RegExp(
    r"[\p{L}\p{N}\p{M}]+(?:['’][\p{L}\p{N}\p{M}]+)*",
    unicode: true,
  );

  final int? maxInputCodeUnits;

  TextAnalyzeResult analyze(String input) {
    if (maxInputCodeUnits case final maximum? when input.length > maximum) {
      _throwResourceLimit();
    }

    try {
      return TextAnalyzeResult(
        characterCount: input.characters.length,
        wordCount: _wordPattern.allMatches(input).length,
        lineCount: _lineCount(input),
        byteCount: utf8.encode(input).length,
      );
    } on TextAnalyzeException {
      rethrow;
    } on OutOfMemoryError {
      _throwResourceLimit();
    }
  }

  int _lineCount(String input) {
    if (input.isEmpty) return 0;
    var count = 1;
    for (var index = 0; index < input.length; index++) {
      final codeUnit = input.codeUnitAt(index);
      if (codeUnit == 0x0A) {
        count++;
      } else if (codeUnit == 0x0D) {
        count++;
        if (index + 1 < input.length && input.codeUnitAt(index + 1) == 0x0A) {
          index++;
        }
      }
    }
    return count;
  }

  Never _throwResourceLimit() => throw const TextAnalyzeException(
    kind: TextAnalyzeFailureKind.resource,
    code: 'text-analyze.resource-limit',
    field: 'input',
    reason: 'character-limit',
  );
}
