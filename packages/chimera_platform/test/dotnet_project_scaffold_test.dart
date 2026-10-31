import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/native_scaffolding.dart';
import 'package:test/test.dart';

void main() {
  late Directory parent;
  setUp(
    () async => parent = await Directory.systemTemp.createTemp(
      'chimera-dotnet-scaffold-',
    ),
  );
  tearDown(() async => parent.delete(recursive: true));
  for (final nuget in [false, true]) {
    test(
      'Given${nuget}Project_WhenScaffolded_ThenGoldenAndRealSdkEvaluationAgree',
      () async {
        final result = await const DotnetProjectService(NativeScaffoldWriter())
            .execute(
              DotnetProjectRequest(
                name: 'Sample',
                parentDirectory: parent.path,
                nuget: nuget,
              ),
            );
        expect(result, isA<ChimeraSuccess<DotnetProjectOutput>>());
        final project = File('${parent.path}/Sample/Sample.csproj');
        final fixture = _fixture(
          'project.${nuget ? 'nuget' : 'minimal'}.csproj',
        );
        expect(await project.readAsBytes(), await fixture.readAsBytes());
        final evaluation = await Process.run('dotnet', [
          'msbuild',
          project.path,
          '-nologo',
          '-getProperty:TargetFramework',
        ]);
        expect(
          evaluation.exitCode,
          0,
          reason: '${evaluation.stderr}\n${evaluation.stdout}',
        );
        expect(evaluation.stdout.toString().trim(), 'net10.0');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
  for (final name in [
    'CON',
    'con.txt',
    'aux',
    'LPT1',
    '../out',
    'foo/bar',
    'bad&xml',
    'trailing.',
    '',
    'a..b',
  ]) {
    test(
      'GivenInvalidName${name}_WhenScaffolded_ThenValidationCreatesNothing',
      () async {
        final result = await const DotnetProjectService(NativeScaffoldWriter())
            .execute(
              DotnetProjectRequest(name: name, parentDirectory: parent.path),
            );
        expect((result as ChimeraFailure).kind, FailureKind.validation);
        expect(parent.listSync(), isEmpty);
      },
    );
  }
  test(
    'GivenWriterFailure_WhenScaffolded_ThenTypedFailureAndRollback',
    () async {
      final service = DotnetProjectService(
        NativeScaffoldWriter(
          writeFile: (file, bytes) async {
            throw const FileSystemException('denied');
          },
        ),
      );
      final result = await service.execute(
        DotnetProjectRequest(name: 'Example', parentDirectory: parent.path),
      );
      expect((result as ChimeraFailure).code, 'scaffold-write-failed');
      expect(parent.listSync(), isEmpty);
    },
  );
}

File _fixture(String name) {
  var root = Directory.current.absolute;
  while (!File('${root.path}/tests/fixtures/scaffolding/$name').existsSync()) {
    if (root.parent.path == root.path) {
      throw StateError('Missing scaffold fixture');
    }
    root = root.parent;
  }
  return File('${root.path}/tests/fixtures/scaffolding/$name');
}
