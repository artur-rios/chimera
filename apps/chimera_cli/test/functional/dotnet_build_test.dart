import 'dart:convert';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_cli/src/dotnet_build.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

class Discovery implements ProjectDiscovery {
  @override
  Future<ChimeraResult<String>> find(
    String root, {
    required String extension,
    String? selection,
  }) async => const ChimeraSuccess('/tmp/Project.sln');
}

class Runner implements NativeCommandRunner {
  @override
  Future<NativeCommandResult> run(
    NativeCommand command, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  }) async => NativeCommandResult(
    exitCode: command.arguments.first == 'build' ? 37 : 0,
    diagnostics: command.arguments.first == '--list-sdks'
        ? '10.0.100 [/sdk]'
        : '',
  );
}

void main() {
  test('GivenDotnetBuildHelp_WhenCli_ThenLocalizedUsage', () async {
    final out = StringBuffer();
    expect(
      await runChimera(
        ['dotnet', 'build', '--help'],
        localeTag: 'pt-BR',
        out: out,
        err: StringBuffer(),
      ),
      0,
    );
    expect(out.toString(), contains('Uso: chimera dotnet build'));
  });
  test('GivenUnknownOrInvalidFlags_WhenCli_ThenValidation', () async {
    for (final args in [
      ['--configuration', 'bad'],
      ['--unknown'],
      ['one', 'two'],
      ['--solution'],
    ]) {
      expect(
        await runDotnetBuild(
          args,
          localeTag: 'en',
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        64,
      );
    }
  });
  test('GivenExternalFailure_WhenJson_ThenStructuredFailureAndExit', () async {
    final out = StringBuffer();
    expect(
      await runDotnetBuild(
        ['--json'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
        service: DotnetBuildService(runner: Runner(), discovery: Discovery()),
      ),
      37,
    );
    final json = jsonDecode(out.toString()) as Map;
    expect(json['success'], false);
    expect(json['exitCode'], 37);
  });
}
