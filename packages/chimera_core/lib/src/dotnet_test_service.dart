import 'native_commands.dart';
import 'result.dart';

final class DotnetTestRequest {
  const DotnetTestRequest({this.baseDirectory});

  /// Null uses ./tests and ./docs/coverage-report. An explicit base contains both outputs.
  final String? baseDirectory;
}

final class DotnetTestLayout {
  const DotnetTestLayout({
    required this.projectScope,
    required this.searchDirectory,
    required this.resultsDirectory,
    required this.reportDirectory,
    required this.projects,
  });
  final String projectScope;
  final String searchDirectory;
  final String resultsDirectory;
  final String reportDirectory;
  final List<String> projects;
}

final class DotnetCoverageSnapshot {
  const DotnetCoverageSnapshot({
    this.json = 0,
    this.lcov = 0,
    this.cobertura = 0,
  });
  final int json;
  final int lcov;
  final int cobertura;
  bool hasNewFormatsSince(DotnetCoverageSnapshot before) =>
      json > before.json && lcov > before.lcov && cobertura > before.cobertura;
}

abstract interface class DotnetTestWorkspace {
  Future<ChimeraResult<DotnetTestLayout>> resolve(DotnetTestRequest request);

  /// Validate both output roots before clearing either directory.
  Future<ChimeraResult<bool>> prepare(DotnetTestLayout layout);
  Future<DotnetCoverageSnapshot> coverageSnapshot(DotnetTestLayout layout);
  Future<bool> hasHtmlReport(DotnetTestLayout layout);
}

final class DotnetTestOutput {
  const DotnetTestOutput({
    required this.resultsDirectory,
    required this.reportDirectory,
    required this.projectsTested,
    required this.noTests,
    this.diagnostics = '',
    this.exitCode = 0,
  });
  final String resultsDirectory;
  final String reportDirectory;
  final int projectsTested;
  final bool noTests;
  final String diagnostics;
  final int exitCode;
}

final class DotnetTestService {
  const DotnetTestService({required this.runner, required this.workspace});
  final NativeCommandRunner runner;
  final DotnetTestWorkspace workspace;
  Future<ChimeraResult<DotnetTestOutput>> test(
    DotnetTestRequest request, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  }) async {
    ChimeraFailure<DotnetTestOutput> fail(
      String code, {
      FailureKind kind = FailureKind.processing,
      Map<String, Object?> details = const {},
    }) => ChimeraFailure(
      kind: kind,
      code: code,
      messageKey: code == 'dotnet.cancelled'
          ? 'error.dotnet.testCancelled'
          : 'error.$code',
      details: details,
    );
    if (cancellation?.isCancelled ?? false) return fail('dotnet.cancelled');
    final resolved = await workspace.resolve(request);
    if (resolved is ChimeraFailure<DotnetTestLayout>) {
      return ChimeraFailure(
        kind: resolved.kind,
        code: resolved.code,
        messageKey: resolved.messageKey,
        details: resolved.details,
      );
    }
    final layout = (resolved as ChimeraSuccess<DotnetTestLayout>).value;
    DotnetTestOutput output({bool noTests = false, String diagnostics = ''}) =>
        DotnetTestOutput(
          resultsDirectory: layout.resultsDirectory,
          reportDirectory: layout.reportDirectory,
          projectsTested: noTests ? 0 : layout.projects.length,
          noTests: noTests,
          diagnostics: diagnostics,
        );
    if (layout.projects.isEmpty) return ChimeraSuccess(output(noTests: true));
    final diagnostics = StringBuffer();
    void record(String value) {
      final remaining = 65536 - diagnostics.length;
      if (remaining <= 0) return;
      final bounded = value.length > remaining
          ? value.substring(0, remaining)
          : value;
      diagnostics.write(bounded);
      onDiagnostic?.call(bounded);
    }

    Map<String, Object?> details([NativeCommandResult? result]) => {
      'resultsDirectory': layout.resultsDirectory,
      'reportDirectory': layout.reportDirectory,
      'diagnostics': diagnostics.toString(),
      if (result != null) 'exitCode': result.exitCode,
    };
    Future<NativeCommandResult> run(
      String executable,
      List<String> args, {
      bool report = true,
    }) async {
      var streamed = false;
      final result = await runner.run(
        NativeCommand(executable, args),
        cancellation: cancellation,
        onDiagnostic: report
            ? (text) {
                streamed = true;
                record(text);
              }
            : null,
      );
      if (report && !streamed) record(result.diagnostics);
      return result;
    }

    final sdk = await run('dotnet', ['--list-sdks'], report: false);
    if (sdk.cancelled || (cancellation?.isCancelled ?? false)) {
      return fail('dotnet.cancelled', details: details(sdk));
    }
    if (sdk.unavailable ||
        sdk.exitCode != 0 ||
        !RegExp(
          r'^\d+\.\d+\.\S+\s+\[',
          multiLine: true,
        ).hasMatch(sdk.diagnostics)) {
      return fail(
        'dotnet.sdkUnavailable',
        kind: FailureKind.resource,
        details: details(sdk),
      );
    }
    final reportGenerator = await run('reportgenerator', [
      '-help',
    ], report: false);
    if (reportGenerator.cancelled || (cancellation?.isCancelled ?? false)) {
      return fail('dotnet.cancelled', details: details(reportGenerator));
    }
    if (reportGenerator.unavailable || reportGenerator.exitCode != 0) {
      return fail(
        'dotnet.reportGeneratorUnavailable',
        kind: FailureKind.resource,
        details: details(reportGenerator),
      );
    }
    final prepared = await workspace.prepare(layout);
    if (prepared is ChimeraFailure<bool>) {
      return ChimeraFailure(
        kind: prepared.kind,
        code: prepared.code,
        messageKey: prepared.messageKey,
        details: {...details(), ...prepared.details},
      );
    }
    for (final project in layout.projects) {
      if (cancellation?.isCancelled ?? false) {
        return fail('dotnet.cancelled', details: details());
      }
      final before = await workspace.coverageSnapshot(layout);
      final result = await run('dotnet', [
        'test',
        project,
        '--collect:XPlat Code Coverage;Format=json,lcov,cobertura',
        '--results-directory',
        layout.resultsDirectory,
      ]);
      if (result.cancelled) {
        return fail('dotnet.cancelled', details: details(result));
      }
      if (result.exitCode != 0 || result.unavailable) {
        return fail('dotnet.testFailed', details: details(result));
      }
      final after = await workspace.coverageSnapshot(layout);
      if (!after.hasNewFormatsSince(before)) {
        return fail(
          'dotnet.collectorUnavailable',
          kind: FailureKind.resource,
          details: details(result),
        );
      }
    }
    if (cancellation?.isCancelled ?? false) {
      return fail('dotnet.cancelled', details: details());
    }
    final generated = await run('reportgenerator', [
      '-reports:${layout.resultsDirectory}/**/coverage.cobertura.xml',
      '-targetdir:${layout.reportDirectory}',
      '-reporttypes:Html',
    ]);
    if (generated.cancelled) {
      return fail('dotnet.cancelled', details: details(generated));
    }
    if (generated.exitCode != 0 ||
        generated.unavailable ||
        !await workspace.hasHtmlReport(layout)) {
      return fail('dotnet.reportFailed', details: details(generated));
    }
    return ChimeraSuccess(output(diagnostics: diagnostics.toString()));
  }
}
