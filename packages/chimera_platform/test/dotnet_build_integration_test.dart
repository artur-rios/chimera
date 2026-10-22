import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_commands.dart';
import 'package:test/test.dart';

void main() {
  test('GivenTemporarySolution_WhenRealSdkBuilds_ThenBothConfigurationsAndFailureStatus', () async {
    ProcessResult sdk;
    try {
      // Match the SDK selected by the build runner, rather than the
      // oldest installed SDK, whose offline reference packs may be absent.
      sdk = await Process.run('dotnet', ['--version']);
    } on ProcessException {
      markTestSkipped('.NET SDK unavailable');
      return;
    }
    final major = RegExp(
      r'^(\d+)\.',
      multiLine: true,
    ).firstMatch(sdk.stdout.toString())?.group(1);
    if (major == null) {
      markTestSkipped('.NET SDK unavailable');
      return;
    }
    final directory = await Directory.systemTemp.createTemp(
      'chimera actual solution ',
    );
    try {
      await File('${directory.path}/NuGet.Config').writeAsString(
        '<configuration><packageSources><clear /></packageSources></configuration>',
      );
      await File('${directory.path}/Example.csproj').writeAsString(
        '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net$major.0</TargetFramework></PropertyGroup></Project>',
      );
      await File('${directory.path}/Example.cs')
          .writeAsString('public class Example { public int Value => 42; }');
      await File('${directory.path}/Example.sln').writeAsString(
        '''Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Example", "Example.csproj", "{CE4CBED0-8F82-4FC4-9451-2A70041B9149}"
EndProject
Global
  GlobalSection(SolutionConfigurationPlatforms) = preSolution
    Debug|Any CPU = Debug|Any CPU
    Release|Any CPU = Release|Any CPU
  EndGlobalSection
  GlobalSection(ProjectConfigurationPlatforms) = postSolution
    {CE4CBED0-8F82-4FC4-9451-2A70041B9149}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
    {CE4CBED0-8F82-4FC4-9451-2A70041B9149}.Debug|Any CPU.Build.0 = Debug|Any CPU
    {CE4CBED0-8F82-4FC4-9451-2A70041B9149}.Release|Any CPU.ActiveCfg = Release|Any CPU
    {CE4CBED0-8F82-4FC4-9451-2A70041B9149}.Release|Any CPU.Build.0 = Release|Any CPU
  EndGlobalSection
EndGlobal
''',
      );
      const service = DotnetBuildService(
        runner: NativeProcessRunner(),
        discovery: NativeProjectDiscovery(),
      );
      final result = await service.build(
        DotnetBuildRequest(sourceDirectory: directory.path),
      );
      expect(
        result,
        isA<ChimeraSuccess<DotnetBuildOutput>>(),
        reason: result is ChimeraFailure<DotnetBuildOutput>
            ? result.details.toString()
            : null,
      );
      expect(
        await File('${directory.path}/bin/Debug/net$major.0/Example.dll')
            .exists(),
        isTrue,
      );
      expect(
        await File('${directory.path}/bin/Release/net$major.0/Example.dll')
            .exists(),
        isTrue,
      );
      await File('${directory.path}/Example.cs')
          .writeAsString('invalid csharp!');
      final failed = await service.build(
        DotnetBuildRequest(
          sourceDirectory: directory.path,
          noRestore: true,
          configuration: 'Debug',
        ),
      ) as ChimeraFailure<DotnetBuildOutput>;
      expect(failed.code, 'dotnet.commandFailed');
      expect(failed.details['exitCode'], isNot(0));
      expect(failed.details['diagnostics'], contains('error'));
    } finally {
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
