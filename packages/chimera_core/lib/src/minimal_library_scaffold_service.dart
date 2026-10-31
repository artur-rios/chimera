import 'package:chimera_utilities/chimera_utilities.dart';

import 'dotnet_library_scaffold_service.dart';
import 'result.dart';
import 'scaffold_service.dart';

final class MinimalLibraryScaffoldService
    implements DotnetScaffoldOperationService {
  MinimalLibraryScaffoldService(
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
        nuget: false,
      );
    } on DotnetParameterException catch (error) {
      return ChimeraFailure(
        kind: FailureKind.validation,
        code: 'dotnet-minimal-validation',
        messageKey: 'error.dotnetMinimal.validation',
        details: {'fields': error.fields},
      );
    }
    try {
      final year = currentYear();
      final bundle =
          renderTemplate?.call(parameters, year) ??
          renderer.renderMinimalLibrary(parameters, year: year);
      return await ScaffoldService(
        writer,
        template: bundle,
      ).execute(ScaffoldRequest(destination: parameters.rootFolder));
    } on Object {
      return const ChimeraFailure(
        kind: FailureKind.processing,
        code: 'dotnet-minimal-render-failed',
        messageKey: 'error.dotnetMinimal.render',
      );
    }
  }
}
