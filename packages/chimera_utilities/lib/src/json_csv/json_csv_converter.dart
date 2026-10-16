import 'package:csv/csv.dart';

import '../json_table/json_table_converter.dart';

enum JsonCsvFailureKind { validation, resource }

final class JsonCsvException implements Exception {
  const JsonCsvException({
    required this.kind,
    required this.code,
    this.offset,
    this.path,
  });

  final JsonCsvFailureKind kind;
  final String code;
  final int? offset;
  final String? path;
}

enum JsonCsvDelimiter {
  comma('comma', ','),
  semicolon('semicolon', ';'),
  tab('tab', '\t'),
  pipe('pipe', '|');

  const JsonCsvDelimiter(this.id, this.character);

  final String id;
  final String character;

  static JsonCsvDelimiter? tryParse(String value) {
    for (final delimiter in values) {
      if (delimiter.id == value) return delimiter;
    }
    return null;
  }
}

final class JsonCsvRequest {
  const JsonCsvRequest({
    required this.source,
    required this.delimiter,
    required this.includeHeaders,
  });

  final String source;
  final String delimiter;
  final bool includeHeaders;
}

final class JsonCsvResult {
  const JsonCsvResult({
    required this.csv,
    required this.columns,
    required this.rowCount,
    required this.delimiter,
    required this.includeHeaders,
  });

  final String csv;
  final List<String> columns;
  final int rowCount;
  final JsonCsvDelimiter delimiter;
  final bool includeHeaders;
}

final class JsonCsvConverter {
  const JsonCsvConverter({this.maxCells = 1000000})
    : assert(maxCells >= 0, 'maxCells must not be negative');

  final int maxCells;

  JsonCsvResult convert(JsonCsvRequest request) {
    final delimiter = JsonCsvDelimiter.tryParse(request.delimiter);
    if (delimiter == null) {
      throw const JsonCsvException(
        kind: JsonCsvFailureKind.validation,
        code: 'json-csv.invalid-delimiter',
      );
    }

    final JsonTable table;
    try {
      table = JsonTableConverter(maxCells: maxCells).convert(
        JsonTableRequest(source: request.source, includeRowNumbers: false),
      );
    } on JsonTableException catch (error) {
      throw JsonCsvException(
        kind: switch (error.kind) {
          JsonTableFailureKind.validation => JsonCsvFailureKind.validation,
          JsonTableFailureKind.resource => JsonCsvFailureKind.resource,
        },
        code: error.code.replaceFirst('json-table.', 'json-csv.'),
        offset: error.offset,
        path: error.path,
      );
    }

    final records = <List<String>>[
      if (request.includeHeaders && table.columns.isNotEmpty) table.columns,
      ...table.rows,
    ];
    final encoder = Csv(
      fieldDelimiter: delimiter.character,
      lineDelimiter: '\r\n',
    );
    final serialized = records
        .map(
          (record) =>
              record.isEmpty || (record.length == 1 && record.single.isEmpty)
              ? '""'
              : encoder.encode(<List<String>>[record]),
        )
        .join('\r\n');
    return JsonCsvResult(
      csv: serialized,
      columns: List<String>.unmodifiable(table.columns),
      rowCount: table.rows.length,
      delimiter: delimiter,
      includeHeaders: request.includeHeaders,
    );
  }
}
