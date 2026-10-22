import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

class Workspace implements DotnetTestWorkspace {
  List<String> projects = ['/root/tests/One.csproj', '/root/tests/Two.csproj'];
  bool prepared = false;
  bool collector = true;
  bool report = true;
  int coverageChecks = 0;
  List<int>? snapshots;
  @override
  Future<ChimeraResult<DotnetTestLayout>> resolve(
    DotnetTestRequest request,
  ) async => ChimeraSuccess(
    DotnetTestLayout(
      projectScope: '/root',
      searchDirectory: '/root/tests',
      resultsDirectory: '/root/tests/TestResults',
      reportDirectory: '/root/docs/coverage-report',
      projects: projects,
    ),
  );
  @override
  Future<ChimeraResult<bool>> prepare(DotnetTestLayout layout) async {
    prepared = true;
    return const ChimeraSuccess(true);
  }

  @override
  Future<DotnetCoverageSnapshot> coverageSnapshot(
    DotnetTestLayout layout,
  ) async {
    final count =
        snapshots?.removeAt(0) ?? (collector ? (coverageChecks + 1) ~/ 2 : 0);
    coverageChecks++;
    return DotnetCoverageSnapshot(json: count, lcov: count, cobertura: count);
  }

  @override
  Future<bool> hasHtmlReport(DotnetTestLayout layout) async => report;
}

class Runner implements NativeCommandRunner {
  final commands = <NativeCommand>[];
  int failAt = -1;
  int cancelAt = -1;
  bool sdk = true;
  @override
  Future<NativeCommandResult> run(
    NativeCommand command, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  }) async {
    commands.add(command);
    return NativeCommandResult(
      exitCode: commands.length == failAt ? 29 : 0,
      cancelled: commands.length == cancelAt,
      diagnostics: command.arguments.first == '--list-sdks' && sdk
          ? '10.0.100 [/sdk]'
          : '',
    );
  }
}

void main() {
  test('GivenNoSdk_WhenRun_ThenDependencyFailureBeforeCleanup', () async {
    final workspace = Workspace();
    final runner = Runner()..sdk = false;
    final result = await DotnetTestService(
      runner: runner,
      workspace: workspace,
    ).test(const DotnetTestRequest()) as ChimeraFailure<DotnetTestOutput>;
    expect(result.code, 'dotnet.sdkUnavailable');
    expect(workspace.prepared, false);
    expect(runner.commands.length, 1);
  });
  test('GivenCancelledProject_WhenRun_ThenStopBeforeFurtherTools', () async {
    final runner = Runner()..cancelAt = 3;
    final result = await DotnetTestService(
      runner: runner,
      workspace: Workspace(),
    ).test(const DotnetTestRequest()) as ChimeraFailure<DotnetTestOutput>;
    expect(result.code, 'dotnet.cancelled');
    expect(runner.commands.length, 3);
  });
  test('GivenFailedReport_WhenRun_ThenRetainArtifactPathsAndStatus', () async {
    final runner = Runner()..failAt = 5;
    final result = await DotnetTestService(
      runner: runner,
      workspace: Workspace(),
    ).test(const DotnetTestRequest()) as ChimeraFailure<DotnetTestOutput>;
    expect(result.code, 'dotnet.reportFailed');
    expect(result.details['exitCode'], 29);
    expect(result.details['resultsDirectory'], '/root/tests/TestResults');
    expect(result.details['reportDirectory'], '/root/docs/coverage-report');
  });
  test(
    'GivenNoTests_WhenRun_ThenSuccessfulNoopWithoutToolsOrCleanup',
    () async {
      final workspace = Workspace()..projects = [];
      final runner = Runner();
      final result = await DotnetTestService(
        runner: runner,
        workspace: workspace,
      ).test(const DotnetTestRequest());
      expect((result as ChimeraSuccess<DotnetTestOutput>).value.noTests, true);
      expect(runner.commands, isEmpty);
      expect(workspace.prepared, false);
    },
  );
  test(
    'GivenProjects_WhenRun_ThenCoverageAndHtmlCommandsMatchSource',
    () async {
      final workspace = Workspace();
      final runner = Runner();
      final result = await DotnetTestService(
        runner: runner,
        workspace: workspace,
      ).test(const DotnetTestRequest());
      expect(result, isA<ChimeraSuccess<DotnetTestOutput>>());
      expect(workspace.prepared, true);
      expect(runner.commands.map((c) => c.executable), [
        'dotnet',
        'reportgenerator',
        'dotnet',
        'dotnet',
        'reportgenerator',
      ]);
      expect(runner.commands[2].arguments, [
        'test',
        '/root/tests/One.csproj',
        '--collect:XPlat Code Coverage;Format=json,lcov,cobertura',
        '--results-directory',
        '/root/tests/TestResults',
      ]);
      expect(runner.commands.last.arguments, [
        '-reports:/root/tests/TestResults/**/coverage.cobertura.xml',
        '-targetdir:/root/docs/coverage-report',
        '-reporttypes:Html',
      ]);
    },
  );
  test('GivenFailedTest_WhenRun_ThenStopBeforeNextProjectOrReport', () async {
    final runner = Runner()..failAt = 3;
    final result = await DotnetTestService(
      runner: runner,
      workspace: Workspace(),
    ).test(const DotnetTestRequest()) as ChimeraFailure<DotnetTestOutput>;
    expect(result.details['exitCode'], 29);
    expect(runner.commands.length, 3);
  });
  test('GivenMissingReportGenerator_WhenRun_ThenNoCleanup', () async {
    final workspace = Workspace();
    final result = await DotnetTestService(
      runner: Runner()..failAt = 2,
      workspace: workspace,
    ).test(const DotnetTestRequest()) as ChimeraFailure<DotnetTestOutput>;
    expect(result.code, 'dotnet.reportGeneratorUnavailable');
    expect(workspace.prepared, false);
  });
  test('GivenMissingCollector_WhenRun_ThenDependencyFailure', () async {
    final runner = Runner();
    final result = await DotnetTestService(
      runner: runner,
      workspace: Workspace()..collector = false,
    ).test(const DotnetTestRequest()) as ChimeraFailure<DotnetTestOutput>;
    expect(result.code, 'dotnet.collectorUnavailable');
    expect(runner.commands.length, 3);
  });
  test('GivenMultiTargetFirstProjectAndMissingSecondCollector_WhenRun_ThenRejectOldCoverage', () async {
    final workspace = Workspace()..snapshots = [0, 2, 2, 2];
    final result = await DotnetTestService(
      runner: Runner(),
      workspace: workspace,
    ).test(const DotnetTestRequest()) as ChimeraFailure<DotnetTestOutput>;
    expect(result.code, 'dotnet.collectorUnavailable');
  });
  test('GivenReportWithoutHtml_WhenRun_ThenFailure', () async {
    final result = await DotnetTestService(
      runner: Runner(),
      workspace: Workspace()..report = false,
    ).test(const DotnetTestRequest()) as ChimeraFailure<DotnetTestOutput>;
    expect(result.code, 'dotnet.reportFailed');
  });
}
