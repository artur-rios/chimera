import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';
import 'scaffold_service.dart';

final class DotnetProjectRequest {
  const DotnetProjectRequest({
    required this.name,
    this.parentDirectory = '.',
    this.minimal = false,
    this.nuget = false,
  });
  final String name;
  final String parentDirectory;
  final bool minimal;
  final bool nuget;
}

final class DotnetProjectOutput {
  const DotnetProjectOutput({required this.mode, required this.scaffold});
  final String mode;
  final ScaffoldOutput scaffold;
  Map<String, Object?> toJson() => {
    ...scaffold.toJson(),
    'mode': mode,
    'projectPath': scaffold.createdPaths.single,
  };
}

typedef DotnetProjectOperationService =
    OperationService<DotnetProjectRequest, DotnetProjectOutput>;

final class DotnetProjectService implements DotnetProjectOperationService {
  const DotnetProjectService(this.writer);
  final ScaffoldWriter writer;

  @override
  Future<ChimeraResult<DotnetProjectOutput>> execute(
    DotnetProjectRequest request,
  ) async {
    final name = request.name;
    final reserved = RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
      caseSensitive: false,
    );
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_.-]{0,99}$').hasMatch(name) ||
        name.endsWith('.') ||
        reserved.hasMatch(name) ||
        name.contains('..') ||
        request.parentDirectory.trim().isEmpty ||
        (request.minimal && request.nuget)) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'dotnet-project-invalid-options',
        messageKey: 'error.dotnetProject.validation',
      );
    }
    final bundle = renderDotnetProject(name, nuget: request.nuget);
    final result = await ScaffoldService(
      writer,
      template: bundle,
    ).execute(ScaffoldRequest(destination: '${request.parentDirectory}/$name'));
    return result.fold<ChimeraResult<DotnetProjectOutput>>(
      onSuccess: (value) => ChimeraSuccess(
        DotnetProjectOutput(
          mode: request.nuget ? 'nuget' : 'minimal',
          scaffold: value,
        ),
      ),
      onFailure: (failure) => ChimeraFailure(
        kind: failure.kind,
        code: failure.code,
        messageKey: failure.messageKey,
        details: failure.details,
      ),
    );
  }
}

final class UnsupportedDotnetProjectService
    implements DotnetProjectOperationService {
  const UnsupportedDotnetProjectService();
  @override
  Future<ChimeraResult<DotnetProjectOutput>> execute(
    DotnetProjectRequest request,
  ) async => const ChimeraFailure(
    kind: FailureKind.validation,
    code: 'dotnet-project-unsupported',
    messageKey: 'error.scaffold.unsupported',
  );
}
