import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_test_workspace.dart';
import 'package:chimera_platform/native_commands.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenRealXunitCollector_WhenRun_ThenAllCoverageFormatsAndHtml',
    () async {
      try {
        final sdk = await Process.run('dotnet', ['--list-sdks']);
        final generator = await Process.run('reportgenerator', ['-help']);
        if (!RegExp(
              r'^10\.',
              multiLine: true,
            ).hasMatch(sdk.stdout.toString()) ||
            generator.exitCode != 0) {
          markTestSkipped('Requires .NET 10 SDK and ReportGenerator');
          return;
        }
      } on ProcessException {
        markTestSkipped('Requires .NET 10 SDK and ReportGenerator');
        return;
      }
      final root = await Directory.systemTemp.createTemp(
        'chimera actual coverage ',
      );
      try {
        final tests = await Directory('${root.path}/tests').create();
        await File('${tests.path}/Example.Tests.csproj').writeAsString(
          '''<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><IsTestProject>true</IsTestProject><IsPackable>false</IsPackable></PropertyGroup><ItemGroup><PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.14.1"/><PackageReference Include="xunit" Version="2.9.3"/><PackageReference Include="xunit.runner.visualstudio" Version="3.1.4"/><PackageReference Include="coverlet.collector" Version="6.0.4"/></ItemGroup></Project>''',
        );
        await File('${tests.path}/Example.cs').writeAsString(
          'public static class Example { public static int Add(int a,int b) => a+b; } public class ExampleTests { [Xunit.Fact] public void Adds() { Xunit.Assert.Equal(3,Example.Add(1,2)); } }',
        );
        final service = DotnetTestService(
          runner: const NativeProcessRunner(),
          workspace: NativeDotnetTestWorkspace(currentDirectory: root.path),
        );
        final result = await service.test(const DotnetTestRequest());
        expect(
          result,
          isA<ChimeraSuccess<DotnetTestOutput>>(),
          reason: result is ChimeraFailure<DotnetTestOutput>
              ? result.details.toString()
              : null,
        );
        final output = (result as ChimeraSuccess<DotnetTestOutput>).value;
        expect(output.projectsTested, 1);
        expect(
          await File('${output.reportDirectory}/index.html').exists(),
          true,
        );
        final files = await Directory(output.resultsDirectory)
            .list(recursive: true)
            .map((entry) => entry.path)
            .toList();
        for (final suffix in [
          'coverage.json',
          'coverage.info',
          'coverage.cobertura.xml',
        ]) {
          expect(files.any((path) => path.endsWith(suffix)), true);
        }
        await File('${tests.path}/Example.cs').writeAsString(
          'public class ExampleTests { [Xunit.Fact] public void Fails() { Xunit.Assert.True(false); } }',
        );
        final failed = await service.test(
          const DotnetTestRequest(),
        ) as ChimeraFailure<DotnetTestOutput>;
        expect(failed.code, 'dotnet.testFailed');
        expect(failed.details['exitCode'], isNot(0));
        expect(await Directory(output.resultsDirectory).exists(), true);
      } finally {
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
