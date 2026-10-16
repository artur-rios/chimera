import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class JsonCsvOperationRequest {
  const JsonCsvOperationRequest({
    required this.source,
    required this.delimiter,
    required this.includeHeaders,
  });

  final String source;
  final String delimiter;
  final bool includeHeaders;
}

final class JsonCsvOutput {
  const JsonCsvOutput(this.result);

  final JsonCsvResult result;

  String get csv => result.csv;

  Map<String, Object?> toJson() => <String, Object?>{
    'csv': result.csv,
    'columns': result.columns,
    'delimiter': result.delimiter.id,
    'includeHeaders': result.includeHeaders,
    'rowCount': result.rowCount,
  };
}

final class JsonCsvService
    implements OperationService<JsonCsvOperationRequest, JsonCsvOutput> {
  const JsonCsvService({this.converter = const JsonCsvConverter()});

  final JsonCsvConverter converter;

  @override
  Future<ChimeraResult<JsonCsvOutput>> execute(
    JsonCsvOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<JsonCsvOutput>(
        JsonCsvOutput(
          converter.convert(
            JsonCsvRequest(
              source: request.source,
              delimiter: request.delimiter,
              includeHeaders: request.includeHeaders,
            ),
          ),
        ),
      );
    } on JsonCsvException catch (error) {
      final details = <String, Object?>{};
      if (error.offset case final offset?) details['offset'] = offset;
      if (error.path case final path?) details['path'] = path;
      return ChimeraFailure<JsonCsvOutput>(
        kind: switch (error.kind) {
          JsonCsvFailureKind.validation => FailureKind.validation,
          JsonCsvFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          JsonCsvFailureKind.validation => 'error.jsonCsv.validation',
          JsonCsvFailureKind.resource => 'error.jsonCsv.resource',
        },
        details: details,
      );
    }
  }
}
