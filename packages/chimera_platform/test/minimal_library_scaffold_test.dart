import 'dart:convert';
import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_scaffolding.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory parent;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('chimera minimal library ');
  });
  tearDown(() async {
    await parent.delete(recursive: true);
  });
  Map<String, String> fields(String destination) => {
    'RootFolder': destination,
    'SolutionName': 'Example.Solution',
    'ProjectName': 'Example.Library',
    'Author': 'Jane Doe',
    'Description': 'A minimal library',
  };
  test(
    'GivenOfflineScaffold_WhenCreated_ThenReportEveryFileAndPlaceholder',
    () async {
      final destination = p.join(parent.path, 'created');
      final result =
          await MinimalLibraryScaffoldService(const NativeScaffoldWriter())
                  .execute(
                    DotnetScaffoldRequest(
                      parametersJson: jsonEncode(fields(destination)),
                    ),
                  )
              as ChimeraSuccess<ScaffoldOutput>;
      final files = await Directory(destination)
          .list(recursive: true)
          .where((entity) => entity is File)
          .map((entity) => entity.path)
          .toList();
      expect(result.value.createdPaths, unorderedEquals(files));
      expect(files, hasLength(10));
      expect(
        await File(p.join(destination, 'tests', '.gitkeep')).exists(),
        true,
      );
      expect(
        await File(p.join(destination, 'docs', '.gitkeep')).exists(),
        true,
      );
      expect(files.where((file) => file.endsWith('.csproj')), hasLength(1));
    },
  );
  test('GivenExistingDestination_WhenRequested_ThenPreserveIt', () async {
    final destination = await Directory(p.join(parent.path, 'existing'))
        .create();
    final marker = File(p.join(destination.path, 'keep'));
    await marker.writeAsString('original');
    final result =
        await MinimalLibraryScaffoldService(
              const NativeScaffoldWriter(),
            ).execute(DotnetScaffoldRequest(fields: fields(destination.path)))
            as ChimeraFailure<ScaffoldOutput>;
    expect(result.kind, FailureKind.access);
    expect(await marker.readAsString(), 'original');
    expect(await destination.list().length, 1);
  });
  test(
    'GivenMissingParent_WhenRequested_ThenTypedAccessWithoutNewOutput',
    () async {
      final destination = p.join(parent.path, 'missing', 'new');
      final result =
          await MinimalLibraryScaffoldService(const NativeScaffoldWriter())
                  .execute(DotnetScaffoldRequest(fields: fields(destination)))
              as ChimeraFailure<ScaffoldOutput>;
      expect(result.kind, FailureKind.access);
      expect(await Directory(destination).exists(), false);
    },
  );
  test(
    'GivenWriteFailure_WhenScaffolding_ThenSharedWriterRollsBackOwnedOutput',
    () async {
      var writes = 0;
      final destination = p.join(parent.path, 'new');
      final writer = NativeScaffoldWriter(
        writeFile: (file, bytes) async {
          if (++writes == 8) {
            throw const FileSystemException('simulated');
          }
          await file.writeAsBytes(bytes);
        },
      );
      final result = await MinimalLibraryScaffoldService(writer).execute(
        DotnetScaffoldRequest(fields: fields(destination)),
      ) as ChimeraFailure<ScaffoldOutput>;
      expect(result.kind, FailureKind.processing);
      expect(await Directory(destination).exists(), false);
    },
  );
  test('GivenGeneratedMinimalSolution_WhenRealSdkBuilds_ThenDebugAndReleaseSucceed', () async {
    try {
      final sdk = await Process.run('dotnet', ['--list-sdks']);
      if (!RegExp(r'^10\.', multiLine: true).hasMatch(sdk.stdout.toString())) {
        markTestSkipped('Requires .NET 10 SDK');
        return;
      }
    } on ProcessException {
      markTestSkipped('Requires .NET 10 SDK');
      return;
    }
    final destination = p.join(parent.path, 'build');
    final result = await MinimalLibraryScaffoldService(
      const NativeScaffoldWriter(),
    ).execute(DotnetScaffoldRequest(fields: fields(destination)));
    expect(result, isA<ChimeraSuccess<ScaffoldOutput>>());
    final nuget = File(p.join(parent.path, 'NuGet.Config'));
    await nuget.writeAsString(
      '<configuration><packageSources><clear /></packageSources></configuration>',
    );
    final solution = p.join(destination, 'src', 'Example.Solution.sln');
    final restored = await Process.run('dotnet', [
      'restore',
      solution,
      '--configfile',
      nuget.path,
    ]);
    expect(
      restored.exitCode,
      0,
      reason: '${restored.stdout}\n${restored.stderr}',
    );
    for (final configuration in ['Debug', 'Release']) {
      final built = await Process.run('dotnet', [
        'build',
        solution,
        '--no-restore',
        '-c',
        configuration,
      ]);
      expect(built.exitCode, 0, reason: '${built.stdout}\n${built.stderr}');
      expect(
        await File(
          p.join(
            destination,
            'src',
            'Example.Library',
            'bin',
            configuration,
            'net10.0',
            'Example.Library.dll',
          ),
        ).exists(),
        true,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
