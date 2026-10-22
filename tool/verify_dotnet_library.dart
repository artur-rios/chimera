import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_scaffolding.dart';

/// Build acceptance only; normal scaffold operations never invoke dotnet.
Future<void> main() async {
  final temporary = await Directory.systemTemp.createTemp(
    'chimera-nuget-build-',
  );
  try {
    final destination = '${temporary.path}/ExampleRepository';
    final result =
        await NugetLibraryScaffoldService(
          const NativeScaffoldWriter(),
          currentYear: () => 2026,
        ).execute(
          DotnetScaffoldRequest(
            fields: {
              'RootFolder': destination,
              'SolutionName': 'Example',
              'ProjectName': 'Example.Library',
              'Author': 'Jane Doe',
              'Company': 'Example & Co',
              'Description': 'A <useful> library',
              'Version': '1.2.3-beta.1',
              'PackageId': 'Example.Library',
              'RepositoryUrl': 'https://example.com/repository',
            },
          ),
        );
    if (result is! ChimeraSuccess<ScaffoldOutput>) {
      throw StateError('Scaffold failed');
    }
    Future<void> dotnet(List<String> args) async {
      final process = await Process.run(
        'dotnet',
        args,
        workingDirectory: destination,
        environment: {
          'DOTNET_NOLOGO': '1',
          'DOTNET_SKIP_FIRST_TIME_EXPERIENCE': '1',
          'DOTNET_CLI_TELEMETRY_OPTOUT': '1',
        },
      );
      if (process.exitCode != 0) {
        stderr.write(process.stdout);
        stderr.write(process.stderr);
        throw StateError('dotnet ${args.first} failed');
      }
      stdout.write(process.stdout);
    }

    final source = Platform.environment['CHIMERA_DOTNET_RESTORE_SOURCE'];
    await dotnet([
      'restore',
      'src/Example.sln',
      '-p:NuGetAudit=false',
      if (source != null) ...['--source', source],
    ]);
    await dotnet([
      'build',
      'src/Example.sln',
      '--no-restore',
      '--configuration',
      'Release',
    ]);
    await dotnet([
      'test',
      'src/Example.sln',
      '--no-build',
      '--no-restore',
      '--configuration',
      'Release',
    ]);
    await dotnet([
      'pack',
      'src/Example.Library.csproj',
      '--no-build',
      '--no-restore',
      '--configuration',
      'Release',
      '--output',
      'artifacts',
    ]);
    final packages = Directory('$destination/artifacts')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.nupkg'));
    if (packages.length != 1) throw StateError('Expected one NuGet package');
    stdout.writeln('UC-54 generated solution restore/build/test/pack passed.');
  } finally {
    await temporary.delete(recursive: true);
  }
}
