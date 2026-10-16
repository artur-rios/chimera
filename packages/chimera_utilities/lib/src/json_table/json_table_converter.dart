import 'dart:convert';

enum JsonTableFailureKind { validation, resource }

final class JsonTableException implements Exception {
  const JsonTableException({
    required this.kind,
    required this.code,
    this.offset,
    this.path,
  });

  final JsonTableFailureKind kind;
  final String code;
  final int? offset;
  final String? path;
}

final class JsonTableRequest {
  const JsonTableRequest({
    required this.source,
    required this.includeRowNumbers,
  });

  final String source;
  final bool includeRowNumbers;
}

final class JsonTable {
  const JsonTable({
    required this.columns,
    required this.rows,
    required this.includeRowNumbers,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final bool includeRowNumbers;
}

final class JsonTableConverter {
  const JsonTableConverter({this.maxCells = 1000000})
    : assert(maxCells >= 0, 'maxCells must not be negative');

  final int maxCells;

  JsonTable convert(JsonTableRequest request) {
    final Object? decoded;
    try {
      decoded = jsonDecode(request.source);
    } on FormatException catch (error) {
      throw JsonTableException(
        kind: JsonTableFailureKind.validation,
        code: 'json-table.invalid-json',
        offset: error.offset,
      );
    }
    if (decoded is! List<Object?>) {
      throw const JsonTableException(
        kind: JsonTableFailureKind.validation,
        code: 'json-table.not-array',
        path: r'$',
      );
    }

    final objectRows = <Map<String, Object?>>[];
    final columns = <String>[];
    final seenColumns = <String>{};
    for (var index = 0; index < decoded.length; index++) {
      final value = decoded[index];
      if (value is! Map<String, Object?>) {
        throw JsonTableException(
          kind: JsonTableFailureKind.validation,
          code: 'json-table.not-object',
          path: '\$[$index]',
        );
      }
      objectRows.add(value);
      for (final key in value.keys) {
        if (seenColumns.add(key)) columns.add(key);
      }
    }
    _validateNumbers(request.source);

    if (columns.isNotEmpty && decoded.length > maxCells ~/ columns.length) {
      throw const JsonTableException(
        kind: JsonTableFailureKind.resource,
        code: 'json-table.resource-limit',
      );
    }

    final rows = objectRows
        .map(
          (row) => columns
              .map(
                (column) => row.containsKey(column) ? _render(row[column]) : '',
              )
              .toList(growable: false),
        )
        .toList(growable: false);
    return JsonTable(
      columns: List.unmodifiable(columns),
      rows: List.unmodifiable(rows),
      includeRowNumbers: request.includeRowNumbers,
    );
  }

  String _render(Object? value) => switch (value) {
    String() => value,
    List<Object?>() || Map<String, Object?>() => jsonEncode(value),
    _ => jsonEncode(value),
  };

  void _validateNumbers(String source) {
    var inString = false;
    var escaped = false;
    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (character == '\\') {
          escaped = true;
        } else if (character == '"') {
          inString = false;
        }
        continue;
      }
      if (character == '"') {
        inString = true;
        continue;
      }
      if (character != '-' && !_isDigit(character)) continue;

      final start = index;
      if (character == '-') index++;
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
      if (index < source.length && source[index] == '.') {
        index++;
        while (index < source.length && _isDigit(source[index])) {
          index++;
        }
      }
      if (index < source.length &&
          (source[index] == 'e' || source[index] == 'E')) {
        index++;
        if (index < source.length &&
            (source[index] == '+' || source[index] == '-')) {
          index++;
        }
        while (index < source.length && _isDigit(source[index])) {
          index++;
        }
      }
      final lexeme = source.substring(start, index);
      if (!_isSupportedNumber(lexeme)) {
        throw JsonTableException(
          kind: JsonTableFailureKind.validation,
          code: 'json-table.unsupported-number',
          offset: start,
        );
      }
      index--;
    }
  }

  bool _isSupportedNumber(String lexeme) {
    if (!lexeme.contains('.') &&
        !lexeme.contains('e') &&
        !lexeme.contains('E')) {
      final integer = BigInt.parse(lexeme);
      const maximumSafeInteger = 9007199254740991;
      return integer.abs() <= BigInt.from(maximumSafeInteger);
    }
    final value = double.parse(lexeme);
    if (!value.isFinite) return false;
    final coefficient = lexeme
        .split(RegExp('[eE]'))
        .first
        .replaceAll(RegExp(r'[-+.]'), '')
        .replaceFirst(RegExp(r'^0+'), '');
    if (value == 0 && coefficient.contains(RegExp('[1-9]'))) return false;
    return coefficient.length <= 15;
  }

  bool _isDigit(String character) =>
      character.codeUnitAt(0) >= 48 && character.codeUnitAt(0) <= 57;
}
