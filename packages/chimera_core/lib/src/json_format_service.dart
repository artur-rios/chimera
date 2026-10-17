import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class JsonFormatOperationRequest {
  const JsonFormatOperationRequest({
    required this.source,
    required this.indent,
  });

  final String source;
  final int indent;
}

final class JsonFormatOutput {
  const JsonFormatOutput(this.result);

  final JsonFormatResult result;

  String get formatted => result.formatted;

  Map<String, Object?> toJson() => <String, Object?>{
    'formatted': result.formatted,
    'indent': result.indent,
  };
}

final class JsonFormatService
    implements OperationService<JsonFormatOperationRequest, JsonFormatOutput> {
  const JsonFormatService({this.formatter = const JsonFormatter()});

  final JsonFormatter formatter;

  @override
  Future<ChimeraResult<JsonFormatOutput>> execute(
    JsonFormatOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<JsonFormatOutput>(
        JsonFormatOutput(
          formatter.format(
            JsonFormatRequest(source: request.source, indent: request.indent),
          ),
        ),
      );
    } on JsonFormatException catch (error) {
      return ChimeraFailure<JsonFormatOutput>(
        kind: switch (error.kind) {
          JsonFormatFailureKind.validation => FailureKind.validation,
          JsonFormatFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          JsonFormatFailureKind.validation => 'error.jsonFormat.validation',
          JsonFormatFailureKind.resource => 'error.jsonFormat.resource',
        },
        details: <String, Object?>{
          'offset': ?error.offset,
          'reason': ?error.reason,
        },
      );
    }
  }
}
