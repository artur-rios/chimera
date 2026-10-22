import 'package:chimera_core/chimera_core.dart';
import 'package:test/test.dart';

class FakeRunner implements NativeCommandRunner {
  final commands = <List<String>>[];
  int failAt = -1;
  bool sdk = true;
  @override
  Future<NativeCommandResult> run(
    NativeCommand command, {
    OperationCancellation? cancellation,
    void Function(String)? onDiagnostic,
  }) async {
    commands.add(command.arguments);
    return NativeCommandResult(
      exitCode: commands.length == failAt ? 42 : 0,
      diagnostics: command.arguments.first == '--list-sdks' && sdk
          ? '10.0.100 [/sdk]'
          : '',
    );
  }
}

class FakeDiscovery implements ProjectDiscovery {
  @override
  Future<ChimeraResult<String>> find(
    String root, {
    required String extension,
    String? selection,
  }) async => const ChimeraSuccess('/source/My Solution.sln');
}

void main() {
  test('GivenDefaults_WhenBuild_ThenRestoreDebugRelease', () async {
    final runner = FakeRunner();
    final result = await DotnetBuildService(
      runner: runner,
      discovery: FakeDiscovery(),
    ).build(const DotnetBuildRequest());
    expect(result, isA<ChimeraSuccess<DotnetBuildOutput>>());
    expect(runner.commands, [
      ['--list-sdks'],
      ['restore', '/source/My Solution.sln'],
      ['build', '/source/My Solution.sln', '-c', 'Debug'],
      ['build', '/source/My Solution.sln', '-c', 'Release'],
    ]);
  });
  test('GivenNoRestoreAndRelease_WhenBuild_ThenOnlyRelease', () async {
    final runner = FakeRunner();
    await DotnetBuildService(runner: runner, discovery: FakeDiscovery()).build(
      const DotnetBuildRequest(noRestore: true, configuration: 'Release'),
    );
    expect(runner.commands.last, [
      'build',
      '/source/My Solution.sln',
      '-c',
      'Release',
      '--no-restore',
    ]);
    expect(runner.commands.length, 2);
  });
  test('GivenInvalidConfiguration_WhenBuild_ThenNoCommand', () async {
    final runner = FakeRunner();
    expect(
      await DotnetBuildService(
        runner: runner,
        discovery: FakeDiscovery(),
      ).build(const DotnetBuildRequest(configuration: 'Other')),
      isA<ChimeraFailure<DotnetBuildOutput>>(),
    );
    expect(runner.commands, isEmpty);
  });
  test('GivenRestoreFailure_WhenBuild_ThenStopAndKeepExitStatus', () async {
    final runner = FakeRunner()..failAt = 2;
    final result = await DotnetBuildService(
      runner: runner,
      discovery: FakeDiscovery(),
    ).build(const DotnetBuildRequest());
    expect(
      (result as ChimeraFailure<DotnetBuildOutput>).details['exitCode'],
      42,
    );
    expect(runner.commands.length, 2);
  });
  test('GivenNoSdk_WhenBuild_ThenDependencyFailure', () async {
    final runner = FakeRunner()..sdk = false;
    final result = await DotnetBuildService(
      runner: runner,
      discovery: FakeDiscovery(),
    ).build(const DotnetBuildRequest());
    expect(
      (result as ChimeraFailure<DotnetBuildOutput>).code,
      'dotnet.sdkUnavailable',
    );
    expect(runner.commands.length, 1);
  });
  test('GivenCancelled_WhenBuild_ThenNoCommand', () async {
    final runner = FakeRunner();
    final token = OperationCancellation()..cancel();
    final result = await DotnetBuildService(
      runner: runner,
      discovery: FakeDiscovery(),
    ).build(const DotnetBuildRequest(), cancellation: token);
    expect(
      (result as ChimeraFailure<DotnetBuildOutput>).code,
      'dotnet.cancelled',
    );
    expect(runner.commands, isEmpty);
  });
}
