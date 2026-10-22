import 'package:chimera_utilities/chimera_utilities.dart';

import 'dotnet_bump_service.dart';
import 'native_commands.dart';
import 'result.dart';
import 'update_service.dart';

final class DotnetTagProject {
  const DotnetTagProject({
    required this.path,
    required this.directory,
    required this.bytes,
  });
  final String path, directory;
  final List<int> bytes;
}

abstract interface class DotnetTagProjectGateway {
  Future<DotnetTagProject> resolve(String? selection);
}

final class DotnetTagRequest {
  const DotnetTagRequest({
    this.project,
    this.push = false,
    this.remote = 'origin',
  });
  final String? project;
  final bool push;
  final String remote;
}

final class DotnetTagOutput {
  const DotnetTagOutput({
    required this.project,
    required this.tag,
    required this.pushed,
    required this.remote,
  });
  final String project, tag, remote;
  final bool pushed;
  Map<String, Object?> toJson() => {
    'project': project,
    'tag': tag,
    'localCreated': true,
    'pushed': pushed,
    'remote': pushed ? remote : null,
  };
}

abstract interface class DotnetTagOperationService {
  Future<ChimeraResult<DotnetTagOutput>> execute(
    DotnetTagRequest request, {
    OperationCancellation? cancellation,
  });
}

final class DotnetTagService implements DotnetTagOperationService {
  const DotnetTagService({required this.projects, required this.runner});
  final DotnetTagProjectGateway projects;
  final NativeCommandRunner runner;

  @override
  Future<ChimeraResult<DotnetTagOutput>> execute(
    DotnetTagRequest request, {
    OperationCancellation? cancellation,
  }) async {
    ChimeraFailure<DotnetTagOutput> fail(
      String code, {
      FailureKind kind = FailureKind.processing,
      Map<String, Object?> details = const {},
    }) => ChimeraFailure(
      kind: kind,
      code: code,
      messageKey: 'error.$code',
      details: details,
    );
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]*$').hasMatch(request.remote) ||
        request.remote.contains('..') ||
        request.remote.contains('//')) {
      return fail('dotnetTag.validation', kind: FailureKind.validation);
    }
    if (cancellation?.isCancelled ?? false) return fail('dotnetTag.cancelled');
    String? attemptedTag;
    var localCreated = false;
    try {
      final project = await projects.resolve(request.project);
      final version = const DotnetVersionEditor().readVersion(project.bytes);
      if (version == null || SemanticVersion.tryParse(version) == null) {
        return fail('dotnetTag.version', kind: FailureKind.validation);
      }
      final tag = 'v$version';
      attemptedTag = tag;
      Future<NativeCommandResult> run(
        List<String> args, {
        bool cancellable = true,
      }) => runner.run(
        NativeCommand('git', args, workingDirectory: project.directory),
        cancellation: cancellable ? cancellation : null,
      );
      final repo = await run(['rev-parse', '--is-inside-work-tree']);
      if (repo.cancelled) return fail('dotnetTag.cancelled');
      if (repo.unavailable) {
        return fail('dotnetTag.gitUnavailable', kind: FailureKind.resource);
      }
      if (repo.exitCode != 0 || repo.diagnostics.trim() != 'true') {
        return fail('dotnetTag.repository', kind: FailureKind.validation);
      }
      final existing = await run([
        'show-ref',
        '--verify',
        '--quiet',
        'refs/tags/$tag',
      ]);
      if (existing.cancelled) return fail('dotnetTag.cancelled');
      if (existing.exitCode == 0) {
        return fail(
          'dotnetTag.conflict',
          details: {'tag': tag, 'localCreated': false},
        );
      }
      if (existing.exitCode != 1) {
        return fail(
          'dotnetTag.command',
          details: {'exitCode': existing.exitCode},
        );
      }
      final created = await run(['tag', '-a', tag, '-m', 'Release $version']);
      if (created.cancelled || created.exitCode != 0) {
        final retained = await run([
          'show-ref',
          '--verify',
          '--quiet',
          'refs/tags/$tag',
        ], cancellable: false);
        return fail(
          created.cancelled
              ? 'dotnetTag.cancelled'
              : retained.exitCode == 0
              ? 'dotnetTag.conflict'
              : 'dotnetTag.command',
          details: {
            'tag': tag,
            'localCreated': created.cancelled ? null : false,
            'localTagPresent': retained.exitCode == 0,
            'pushed': false,
            'exitCode': created.exitCode,
            'diagnostics': created.diagnostics,
          },
        );
      }
      localCreated = true;
      if (request.push) {
        final pushed = await run([
          'push',
          '--no-follow-tags',
          '--recurse-submodules=no',
          '--',
          request.remote,
          'refs/tags/$tag:refs/tags/$tag',
        ]);
        if (pushed.exitCode != 0 || pushed.cancelled) {
          return fail(
            pushed.cancelled ? 'dotnetTag.cancelled' : 'dotnetTag.pushFailed',
            details: {
              'tag': tag,
              'localCreated': true,
              'pushed': false,
              'remoteOutcome': 'unconfirmed',
              'exitCode': pushed.exitCode,
              'diagnostics': pushed.diagnostics,
            },
          );
        }
      }
      return ChimeraSuccess(
        DotnetTagOutput(
          project: project.path,
          tag: tag,
          pushed: request.push,
          remote: request.remote,
        ),
      );
    } on DotnetBumpBoundaryException catch (error) {
      return fail(
        error.code == 'access' ? 'dotnetTag.access' : 'dotnetTag.discovery',
        kind: error.code == 'access'
            ? FailureKind.access
            : FailureKind.validation,
        details: error.details,
      );
    } on DotnetVersionException {
      return fail('dotnetTag.version', kind: FailureKind.validation);
    } on Object {
      return fail(
        'dotnetTag.command',
        details: {
          'tag': ?attemptedTag,
          'localCreated': localCreated,
          'pushed': false,
          if (localCreated && request.push) 'remoteOutcome': 'unconfirmed',
        },
      );
    }
  }
}

final class UnsupportedDotnetTagService implements DotnetTagOperationService {
  const UnsupportedDotnetTagService();
  @override
  Future<ChimeraResult<DotnetTagOutput>> execute(
    DotnetTagRequest request, {
    OperationCancellation? cancellation,
  }) async => const ChimeraFailure(
    kind: FailureKind.validation,
    code: 'dotnetTag.unsupported',
    messageKey: 'error.dotnetTag.unsupported',
  );
}
