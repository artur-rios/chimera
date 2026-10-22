import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

void main() {
  test('GivenInvalidRemote_WhenTagRequested_ThenNoGitCommandRuns', () async {
    final runner = _Runner([]);
    final result = await DotnetTagService(
      projects: _Project(),
      runner: runner,
    ).execute(const DotnetTagRequest(remote: '--force'));
    expect((result as ChimeraFailure).kind, FailureKind.validation);
    expect(runner.commands, isEmpty);
  });
  test('GivenInvalidVersion_WhenTagRequested_ThenNoGitCommandRuns', () async {
    final runner = _Runner([]);
    final result = await DotnetTagService(
      projects: _Project(version: 'not-a-version'),
      runner: runner,
    ).execute(const DotnetTagRequest());
    expect((result as ChimeraFailure).code, 'dotnetTag.version');
    expect(runner.commands, isEmpty);
  });
  test(
    'GivenAccessFailure_WhenProjectRead_ThenTypedAccessFailureWithoutGit',
    () async {
      final runner = _Runner([]);
      final result = await DotnetTagService(
        projects: _Project(accessFailure: true),
        runner: runner,
      ).execute(const DotnetTagRequest());
      expect((result as ChimeraFailure).kind, FailureKind.access);
      expect(runner.commands, isEmpty);
    },
  );
  test('GivenConcurrentTagCreation_WhenTagCommandFails_ThenConflictDoesNotClaimCreatedTag', () async {
    final runner = _Runner([
      _repo,
      _missing,
      const NativeCommandResult(exitCode: 128),
      const NativeCommandResult(exitCode: 0),
    ]);
    final result = await DotnetTagService(
      projects: _Project(),
      runner: runner,
    ).execute(const DotnetTagRequest());
    final failure = result as ChimeraFailure;
    expect(failure.code, 'dotnetTag.conflict');
    expect(failure.details['localCreated'], isFalse);
  });
  test('GivenCancelledPush_WhenTagAlreadyCreated_ThenRetainedLocalTagAndUnconfirmedRemote', () async {
    final runner = _Runner([
      _repo,
      _missing,
      const NativeCommandResult(exitCode: 0),
      const NativeCommandResult(exitCode: 130, cancelled: true),
    ]);
    final result = await DotnetTagService(
      projects: _Project(),
      runner: runner,
    ).execute(const DotnetTagRequest(push: true));
    final failure = result as ChimeraFailure;
    expect(failure.code, 'dotnetTag.cancelled');
    expect(failure.details['localCreated'], isTrue);
    expect(failure.details['remoteOutcome'], 'unconfirmed');
    expect(runner.commands.last.arguments, [
      'push',
      '--no-follow-tags',
      '--recurse-submodules=no',
      '--',
      'origin',
      'refs/tags/v1.2.3:refs/tags/v1.2.3',
    ]);
  });
  test('GivenMissingGit_WhenTagRequested_ThenDependencyFailure', () async {
    final runner = _Runner([
      const NativeCommandResult(exitCode: 127, unavailable: true),
    ]);
    final result = await DotnetTagService(
      projects: _Project(),
      runner: runner,
    ).execute(const DotnetTagRequest());
    expect((result as ChimeraFailure).kind, FailureKind.resource);
  });
  test(
    'GivenPreCancelledOperation_WhenTagRequested_ThenNoGitCommandRuns',
    () async {
      final runner = _Runner([]);
      final cancellation = OperationCancellation()..cancel();
      final result = await DotnetTagService(
        projects: _Project(),
        runner: runner,
      ).execute(const DotnetTagRequest(), cancellation: cancellation);
      expect((result as ChimeraFailure).code, 'dotnetTag.cancelled');
      expect(runner.commands, isEmpty);
    },
  );
  test(
    'GivenUnexpectedPushFailure_WhenTagWasCreated_ThenLocalTagStatusIsRetained',
    () async {
      final runner = _Runner([
        _repo,
        _missing,
        const NativeCommandResult(exitCode: 0),
        StateError('transport stopped'),
      ]);
      final result = await DotnetTagService(
        projects: _Project(),
        runner: runner,
      ).execute(const DotnetTagRequest(push: true));
      expect((result as ChimeraFailure).details['localCreated'], isTrue);
      expect((result as ChimeraFailure).details['tag'], 'v1.2.3');
    },
  );
}

const _repo = NativeCommandResult(exitCode: 0, diagnostics: 'true\n');
const _missing = NativeCommandResult(exitCode: 1);

final class _Project implements DotnetTagProjectGateway {
  _Project({this.version = '1.2.3', this.accessFailure = false});
  final String version;
  final bool accessFailure;
  @override
  Future<DotnetTagProject> resolve(String? selection) async {
    if (accessFailure) throw const DotnetBumpBoundaryException('access');
    return DotnetTagProject(
      path: '/repo/src/Library.csproj',
      directory: '/repo/src',
      bytes: utf8.encode(
        '<Project><PropertyGroup><Version>$version</Version></PropertyGroup></Project>',
      ),
    );
  }
}

final class _Runner implements NativeCommandRunner {
  _Runner(this.results);
  final List<Object> results;
  final commands = <NativeCommand>[];
  @override
  Future<NativeCommandResult> run(
    NativeCommand command, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  }) async {
    commands.add(command);
    final result = results.removeAt(0);
    if (result is NativeCommandResult) return result;
    throw result;
  }
}
