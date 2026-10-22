import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';
import 'scaffold_service.dart';

final class DotnetScaffoldRequest {
  const DotnetScaffoldRequest({this.fields = const {}, this.parametersJson});
  final Map<String, String> fields;
  final String? parametersJson;
}

typedef DotnetScaffoldOperationService =
    OperationService<DotnetScaffoldRequest, ScaffoldOutput>;
typedef DotnetTemplateRender = TemplateBundle Function(
  DotnetRepositoryParameters parameters,
  int year,
);

final class NugetLibraryScaffoldService
    implements DotnetScaffoldOperationService {
  NugetLibraryScaffoldService(
    this.writer, {
    this.renderer = const DotnetRepositoryRenderer(),
    int Function()? currentYear,
    this.renderTemplate,
  }) : currentYear = currentYear ?? _currentYear;
  final ScaffoldWriter writer;
  final DotnetRepositoryRenderer renderer;
  final int Function() currentYear;
  final DotnetTemplateRender? renderTemplate;
  static int _currentYear() => DateTime.now().year;

  @override
  Future<ChimeraResult<ScaffoldOutput>> execute(
    DotnetScaffoldRequest request,
  ) async {
    final DotnetRepositoryParameters parameters;
    try {
      parameters = DotnetRepositoryParameters.parse(
        fields: request.fields,
        parametersJson: request.parametersJson,
      );
    } on DotnetParameterException catch (error) {
      return ChimeraFailure(
        kind: FailureKind.validation,
        code: 'dotnet-scaffold-validation',
        messageKey: 'error.dotnetScaffold.validation',
        details: {'fields': error.fields},
      );
    }
    try {
      final year = currentYear();
      final bundle =
          renderTemplate?.call(parameters, year) ??
          renderer.renderNugetLibrary(parameters, year: year);
      return await ScaffoldService(
        writer,
        template: bundle,
      ).execute(ScaffoldRequest(destination: parameters.rootFolder));
    } on Object {
      return const ChimeraFailure(
        kind: FailureKind.processing,
        code: 'dotnet-scaffold-render-failed',
        messageKey: 'error.dotnetScaffold.render',
      );
    }
  }
}

final class UnsupportedDotnetScaffoldService
    implements DotnetScaffoldOperationService {
  const UnsupportedDotnetScaffoldService();
  @override
  Future<ChimeraResult<ScaffoldOutput>> execute(
    DotnetScaffoldRequest request,
  ) async => const ChimeraFailure(
    kind: FailureKind.validation,
    code: 'scaffold-unsupported',
    messageKey: 'error.scaffold.unsupported',
  );
}
