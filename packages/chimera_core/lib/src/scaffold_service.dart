import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class ScaffoldRequest {
  const ScaffoldRequest({required this.destination});
  final String destination;
}

final class ScaffoldOutput {
  const ScaffoldOutput({
    required this.destination,
    required this.templateVersion,
    required this.createdPaths,
  });
  final String destination;
  final String templateVersion;
  final List<String> createdPaths;
  Map<String, Object?> toJson() => {
    'destination': destination,
    'templateVersion': templateVersion,
    'createdPaths': createdPaths,
  };
}

abstract interface class ScaffoldWriter {
  Future<ChimeraResult<ScaffoldOutput>> write(
    ScaffoldRequest request,
    TemplateBundle template,
  );
}

typedef ScaffoldOperationService =
    OperationService<ScaffoldRequest, ScaffoldOutput>;

final class ScaffoldService implements ScaffoldOperationService {
  ScaffoldService(this.writer, {TemplateBundle? template})
    : template = template ?? projectTemplate;
  final ScaffoldWriter writer;
  final TemplateBundle template;

  @override
  Future<ChimeraResult<ScaffoldOutput>> execute(ScaffoldRequest request) async {
    if (request.destination.trim().isEmpty ||
        request.destination.contains('\u0000')) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'scaffold-invalid-destination',
        messageKey: 'error.scaffold.validation',
      );
    }
    if (!template.isValid) {
      return const ChimeraFailure(
        kind: FailureKind.processing,
        code: 'scaffold-invalid-template',
        messageKey: 'error.scaffold.template',
      );
    }
    try {
      return await writer.write(request, template);
    } on Object {
      return const ChimeraFailure(
        kind: FailureKind.processing,
        code: 'scaffold-failed',
        messageKey: 'error.scaffold.failed',
      );
    }
  }
}

final class UnsupportedScaffoldService implements ScaffoldOperationService {
  const UnsupportedScaffoldService();
  @override
  Future<ChimeraResult<ScaffoldOutput>> execute(
    ScaffoldRequest request,
  ) async => const ChimeraFailure(
    kind: FailureKind.validation,
    code: 'scaffold-unsupported',
    messageKey: 'error.scaffold.unsupported',
  );
}
