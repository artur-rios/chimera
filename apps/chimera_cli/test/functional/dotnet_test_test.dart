import 'dart:convert';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_cli/src/dotnet_test.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

class Workspace implements DotnetTestWorkspace {
  @override
  Future<ChimeraResult<DotnetTestLayout>> resolve(
    DotnetTestRequest request,
  ) async => const ChimeraSuccess(
    DotnetTestLayout(
      projectScope: '/root',
      searchDirectory: '/root/tests',
      resultsDirectory: '/root/tests/TestResults',
      reportDirectory: '/root/docs/coverage-report',
      projects: [],
    ),
  );
  @override
  Future<ChimeraResult<bool>> prepare(DotnetTestLayout layout) async =>
      const ChimeraSuccess(true);
  @override
  Future<DotnetCoverageSnapshot> coverageSnapshot(
    DotnetTestLayout layout,
  ) async => const DotnetCoverageSnapshot();
  @override
  Future<bool> hasHtmlReport(DotnetTestLayout layout) async => true;
}

class Runner implements NativeCommandRunner {
  @override
  Future<NativeCommandResult> run(
    NativeCommand command, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  }) => throw StateError('No external tools for no-op');
}

void main() {
  test('GivenDotnetTestHelp_WhenCli_ThenLocalizedUsage', () async {
    final out = StringBuffer();
    expect(
      await runChimera(
        ['dotnet', 'test', '--help'],
        localeTag: 'pt-BR',
        out: out,
        err: StringBuffer(),
      ),
      0,
    );
    expect(out.toString(), contains('Uso: chimera dotnet test'));
  });
  test('GivenNoProjects_WhenJson_ThenDocumentedNoop', () async {
    final out = StringBuffer();
    expect(
      await runDotnetTest(
        ['--json'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        service: DotnetTestService(runner: Runner(), workspace: Workspace()),
      ),
      0,
    );
    final result = jsonDecode(out.toString()) as Map;
    expect(result['noTests'], true);
    expect(result['projectsTested'], 0);
    expect(result['reportDirectory'], '/root/docs/coverage-report');
  });
  test('GivenUnknownOptionsOrMultiplePaths_WhenCli_ThenReject', () async {
    for (final args in [
      ['--bad'],
      ['one', 'two'],
    ]) {
      expect(
        await runDotnetTest(
          args,
          localeTag: 'en',
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        64,
      );
    }
  });
}
