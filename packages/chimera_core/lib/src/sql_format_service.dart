import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class SqlFormatOperationRequest {
  const SqlFormatOperationRequest({
    required this.source,
    required this.dialect,
    required this.indent,
    required this.keywordCase,
  });

  final String source;
  final SqlDialect dialect;
  final int indent;
  final SqlKeywordCase keywordCase;
}

final class SqlFormatOutput {
  const SqlFormatOutput(this.result);

  final SqlFormatResult result;

  String get formatted => result.formatted;

  Map<String, Object?> toJson() => <String, Object?>{
    'formatted': result.formatted,
    'dialect': result.dialect.value,
    'indent': result.indent,
    'keywordCase': result.keywordCase.value,
  };
}

final class SqlFormatService
    implements OperationService<SqlFormatOperationRequest, SqlFormatOutput> {
  const SqlFormatService({this.formatter = const SqlFormatter()});

  final SqlFormatter formatter;

  @override
  Future<ChimeraResult<SqlFormatOutput>> execute(
    SqlFormatOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<SqlFormatOutput>(
        SqlFormatOutput(
          formatter.format(
            SqlFormatRequest(
              source: request.source,
              dialect: request.dialect,
              indent: request.indent,
              keywordCase: request.keywordCase,
            ),
          ),
        ),
      );
    } on SqlFormatException catch (error) {
      return ChimeraFailure<SqlFormatOutput>(
        kind: switch (error.kind) {
          SqlFormatFailureKind.validation => FailureKind.validation,
          SqlFormatFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          SqlFormatFailureKind.validation => 'error.sqlFormat.validation',
          SqlFormatFailureKind.resource => 'error.sqlFormat.resource',
        },
        details: <String, Object?>{
          'offset': ?error.offset,
          'reason': ?error.reason,
        },
      );
    }
  }
}
