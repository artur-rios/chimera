import 'native_commands.dart';
import 'result.dart';

final class DotnetBuildRequest {
  const DotnetBuildRequest({
    this.sourceDirectory = './src',
    this.solution,
    this.configuration,
    this.noRestore = false,
  });
  final String sourceDirectory;
  final String? solution;

  /// Null means Debug followed by Release.
  final String? configuration;
  final bool noRestore;
}

final class DotnetBuildOutput {
  const DotnetBuildOutput({
    required this.solution,
    required this.configurations,
    required this.diagnostics,
    this.exitCode = 0,
  });
  final String solution;
  final List<String> configurations;
  final String diagnostics;
  final int exitCode;
}

final class DotnetBuildService {
  const DotnetBuildService({required this.runner, required this.discovery});
  final NativeCommandRunner runner;
  final ProjectDiscovery discovery;

  Future<ChimeraResult<DotnetBuildOutput>> build(
    DotnetBuildRequest request, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  }) async {
    ChimeraFailure<DotnetBuildOutput> fail(
      String code, {
      FailureKind kind = FailureKind.processing,
      Map<String, Object?> details = const {},
    }) => ChimeraFailure(
      kind: kind,
      code: code,
      messageKey: 'error.$code',
      details: details,
    );
    if (request.sourceDirectory.trim().isEmpty ||
        (request.configuration != null &&
            !['Debug', 'Release'].contains(request.configuration))) {
      return fail('dotnet.validation', kind: FailureKind.validation);
    }
    if (cancellation?.isCancelled ?? false) return fail('dotnet.cancelled');
    final selected = await discovery.find(
      request.sourceDirectory,
      extension: '.sln',
      selection: request.solution,
    );
    if (selected is ChimeraFailure<String>) {
      return ChimeraFailure(
        kind: selected.kind,
        code: selected.code,
        messageKey: selected.messageKey,
        details: selected.details,
      );
    }
    final solution = (selected as ChimeraSuccess<String>).value;
    final diagnostics = StringBuffer();
    // Bound the entire workflow as well as each subprocess.
    void record(String text) {
      final remaining = 65536 - diagnostics.length;
      if (remaining <= 0) return;
      final safe = text.length > remaining
          ? text.substring(0, remaining)
          : text;
      diagnostics.write(safe);
      onDiagnostic?.call(safe);
    }

    Future<NativeCommandResult> run(
      List<String> args, {
      bool report = true,
    }) async {
      var streamed = false;
      final result = await runner.run(
        NativeCommand('dotnet', args),
        cancellation: cancellation,
        onDiagnostic: report
            ? (text) {
                streamed = true;
                record(text);
              }
            : null,
      );
      if (report && !streamed && result.diagnostics.isNotEmpty) {
        record(result.diagnostics);
      }
      return result;
    }

    final sdk = await run(['--list-sdks'], report: false);
    if (sdk.cancelled || (cancellation?.isCancelled ?? false)) {
      return fail('dotnet.cancelled');
    }
    if (sdk.unavailable ||
        sdk.exitCode != 0 ||
        !RegExp(
          r'^\d+\.\d+\.\S+\s+\[',
          multiLine: true,
        ).hasMatch(sdk.diagnostics)) {
      return fail('dotnet.sdkUnavailable', kind: FailureKind.resource);
    }
    final configs = request.configuration == null
        ? ['Debug', 'Release']
        : [request.configuration!];
    final commands = <List<String>>[
      if (!request.noRestore) ['restore', solution],
      for (final config in configs)
        [
          'build',
          solution,
          '-c',
          config,
          if (request.noRestore) '--no-restore',
        ],
    ];
    for (final args in commands) {
      if (cancellation?.isCancelled ?? false) {
        return fail(
          'dotnet.cancelled',
          details: {'diagnostics': diagnostics.toString()},
        );
      }
      final result = await run(args);
      if (result.cancelled) {
        return fail(
          'dotnet.cancelled',
          details: {
            'diagnostics': diagnostics.toString(),
            'exitCode': result.exitCode,
          },
        );
      }
      if (result.exitCode != 0 || result.unavailable) {
        return fail(
          'dotnet.commandFailed',
          details: {
            'exitCode': result.exitCode,
            'stage': args.first,
            'diagnostics': diagnostics.toString(),
          },
        );
      }
    }
    return ChimeraSuccess(
      DotnetBuildOutput(
        solution: solution,
        configurations: List.unmodifiable(configs),
        diagnostics: diagnostics.toString(),
      ),
    );
  }
}
