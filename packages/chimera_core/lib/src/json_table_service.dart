import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class JsonTableOperationRequest {
  const JsonTableOperationRequest({
    required this.source,
    required this.includeRowNumbers,
  });

  final String source;
  final bool includeRowNumbers;
}

final class JsonTableOutput {
  const JsonTableOutput(this.table);

  final JsonTable table;

  Map<String, Object?> toJson() => <String, Object?>{
    'columns': table.columns,
    'rows': table.rows,
    'includeRowNumbers': table.includeRowNumbers,
    'rowCount': table.rows.length,
  };
}

final class JsonTableService
    implements OperationService<JsonTableOperationRequest, JsonTableOutput> {
  const JsonTableService({this.converter = const JsonTableConverter()});

  final JsonTableConverter converter;

  @override
  Future<ChimeraResult<JsonTableOutput>> execute(
    JsonTableOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<JsonTableOutput>(
        JsonTableOutput(
          converter.convert(
            JsonTableRequest(
              source: request.source,
              includeRowNumbers: request.includeRowNumbers,
            ),
          ),
        ),
      );
    } on JsonTableException catch (error) {
      final details = <String, Object?>{};
      if (error.offset case final offset?) details['offset'] = offset;
      if (error.path case final path?) details['path'] = path;
      return ChimeraFailure<JsonTableOutput>(
        kind: switch (error.kind) {
          JsonTableFailureKind.validation => FailureKind.validation,
          JsonTableFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          JsonTableFailureKind.validation => 'error.jsonTable.validation',
          JsonTableFailureKind.resource => 'error.jsonTable.resource',
        },
        details: details,
      );
    }
  }
}
