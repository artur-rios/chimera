import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class JsonYamlOperationRequest {
  const JsonYamlOperationRequest({
    required this.source,
    required this.indent,
    required this.quoteStrings,
  });

  final String source;
  final int indent;
  final bool quoteStrings;
}

final class JsonYamlOutput {
  const JsonYamlOutput(this.result);

  final JsonYamlResult result;

  String get yaml => result.yaml;

  Map<String, Object?> toJson() => <String, Object?>{
    'yaml': result.yaml,
    'indent': result.indent,
    'quoteStrings': result.quoteStrings,
  };
}

final class JsonYamlService
    implements OperationService<JsonYamlOperationRequest, JsonYamlOutput> {
  const JsonYamlService({this.converter = const JsonYamlConverter()});

  final JsonYamlConverter converter;

  @override
  Future<ChimeraResult<JsonYamlOutput>> execute(
    JsonYamlOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<JsonYamlOutput>(
        JsonYamlOutput(
          converter.convert(
            JsonYamlRequest(
              source: request.source,
              indent: request.indent,
              quoteStrings: request.quoteStrings,
            ),
          ),
        ),
      );
    } on JsonYamlException catch (error) {
      return ChimeraFailure<JsonYamlOutput>(
        kind: switch (error.kind) {
          JsonYamlFailureKind.validation => FailureKind.validation,
          JsonYamlFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          JsonYamlFailureKind.validation => 'error.jsonYaml.validation',
          JsonYamlFailureKind.resource => 'error.jsonYaml.resource',
        },
        details: <String, Object?>{'offset': ?error.offset},
      );
    }
  }
}
