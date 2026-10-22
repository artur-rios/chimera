import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

abstract interface class DotnetBumpGateway {
  Future<String> resolveProject(String? selection);
  Future<List<int>> read(String path);
  Future<String> createBackup(String path, List<int> original);
  Future<void> replace(
    String path,
    List<int> expectedOriginal,
    List<int> updated,
  );

  /// Restore only while the target still contains the completed replacement.
  /// A mismatch must retain both the current target and original backup.
  Future<void> restore(
    String path,
    String backupPath,
    List<int> original, {
    required List<int> expectedCurrent,
  });
  Future<void> removeBackup(String path);
}

final class DotnetBumpBoundaryException implements Exception {
  const DotnetBumpBoundaryException(this.code, {this.details = const {}});
  final String code;
  final Map<String, Object?> details;
}

final class DotnetBumpRequest {
  const DotnetBumpRequest({this.project, this.version, this.increment});
  final String? project;
  final String? version;
  final String? increment;
}

final class DotnetBumpOutput {
  const DotnetBumpOutput({
    required this.project,
    required this.previousVersion,
    required this.version,
    this.backupPath,
  });
  final String project;
  final String? previousVersion;
  final String version;

  /// Present only when verification succeeded but backup cleanup was denied.
  final String? backupPath;
  Map<String, Object?> toJson() => {
    'project': project,
    'previousVersion': previousVersion,
    'version': version,
    'backupPath': backupPath,
  };
}

final class DotnetBumpService
    implements OperationService<DotnetBumpRequest, DotnetBumpOutput> {
  const DotnetBumpService(
    this.gateway, {
    this.editor = const DotnetVersionEditor(),
  });
  final DotnetBumpGateway gateway;
  final DotnetVersionEditor editor;
  static bool _equal(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  @override
  Future<ChimeraResult<DotnetBumpOutput>> execute(
    DotnetBumpRequest request,
  ) async {
    String? project;
    String? backup;
    List<int>? original;
    List<int>? replacement;
    var replacementCompleted = false;
    try {
      project = await gateway.resolveProject(request.project);
      original = List.unmodifiable(await gateway.read(project));
      final edit = editor.edit(
        original,
        version: request.version,
        increment: request.increment,
      );
      replacement = edit.bytes;
      backup = await gateway.createBackup(project, original);
      await gateway.replace(project, original, replacement);
      replacementCompleted = true;
      final verified = await gateway.read(project);
      if (!_equal(verified, edit.bytes) ||
          editor.readVersion(verified) != edit.version) {
        throw const DotnetBumpBoundaryException('verification');
      }
      String? retainedBackup;
      try {
        await gateway.removeBackup(backup);
      } on Object {
        retainedBackup = backup;
      }
      return ChimeraSuccess(
        DotnetBumpOutput(
          project: project,
          previousVersion: edit.previousVersion,
          version: edit.version,
          backupPath: retainedBackup,
        ),
      );
    } on Object catch (error) {
      if (backup != null && project != null && original != null) {
        var restored = false;
        try {
          // A staging/replacement error does not establish that this operation
          // changed the project. Never roll back an uncompleted replacement.
          if (replacementCompleted && replacement != null) {
            await gateway.restore(
              project,
              backup,
              original,
              expectedCurrent: replacement,
            );
          }
          restored = _equal(await gateway.read(project), original);
        } on Object {
          restored = false;
        }
        return ChimeraFailure(
          kind: FailureKind.access,
          code: 'dotnet-bump-transaction-failed',
          messageKey: 'dotnetBump.transactionFailed',
          details: {
            'project': project,
            'backupPath': backup,
            'restored': restored,
          },
        );
      }
      if (error is DotnetVersionException) {
        return ChimeraFailure(
          kind: FailureKind.validation,
          code: 'dotnet-bump-${error.code}',
          messageKey: 'dotnetBump.${error.code}',
          details: {'project': ?project},
        );
      }
      if (error is DotnetBumpBoundaryException) {
        return ChimeraFailure(
          kind: error.code == 'discovery'
              ? FailureKind.validation
              : FailureKind.access,
          code: 'dotnet-bump-${error.code}',
          messageKey: error.code == 'discovery'
              ? 'dotnetBump.discovery'
              : 'dotnetBump.access',
          details: error.details,
        );
      }
      return ChimeraFailure(
        kind: FailureKind.access,
        code: 'dotnet-bump-access',
        messageKey: 'dotnetBump.access',
        details: {'project': ?project},
      );
    }
  }
}
