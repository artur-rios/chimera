import 'dart:io';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_platform/dotnet_test_workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('chimera coverage ');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  Future<void> project(String path) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString('<Project/>');
  }

  test('GivenExcludedNameInAncestor_WhenResolvingSelectedTests_ThenDiscoverProjects', () async {
    for (final ancestor in [
      'setup',
      'bin',
      'obj',
      'TestResults',
      'coverage-report',
    ]) {
      await project('$ancestor/repository/tests/Real.Tests.csproj');
      await project('$ancestor/repository/tests/Setup/Fixture.csproj');
      final workspace = NativeDotnetTestWorkspace(
        currentDirectory: p.join(root.path, ancestor, 'repository'),
      );
      final result = await workspace.resolve(
        const DotnetTestRequest(),
      ) as ChimeraSuccess<DotnetTestLayout>;
      expect(result.value.projects.map(p.basename), ['Real.Tests.csproj']);
    }
  });

  Future<bool> linkDirectory(String link, String target) async {
    if (Platform.isWindows) {
      final result = await Process.run('cmd.exe', [
        '/d',
        '/c',
        'mklink',
        '/J',
        link,
        target,
      ]);
      return result.exitCode == 0;
    }
    await Link(link).create(target);
    return true;
  }

  test('GivenDefaultAndExplicitRoots_WhenResolve_ThenSourceCompatiblePathsAndSetupExclusion', () async {
    await project('tests/Nested/Test.csproj');
    await project('tests/sEtUp/Ignore.csproj');
    await project('tests/TestResults/Ignore.csproj');
    final workspace = NativeDotnetTestWorkspace(currentDirectory: root.path);
    final layout = (await workspace.resolve(
      const DotnetTestRequest(),
    ) as ChimeraSuccess<DotnetTestLayout>).value;
    expect(layout.projects.single, endsWith('Test.csproj'));
    expect(layout.resultsDirectory, p.join(root.path, 'tests', 'TestResults'));
    expect(
      layout.reportDirectory,
      p.join(root.path, 'docs', 'coverage-report'),
    );
    expect(await Directory('${root.path}/docs').exists(), false);
    final explicit = (await workspace.resolve(
      const DotnetTestRequest(baseDirectory: 'tests'),
    ) as ChimeraSuccess<DotnetTestLayout>).value;
    expect(
      explicit.reportDirectory,
      p.join(root.path, 'tests', 'coverage-report'),
    );
  });
  test(
    'GivenValidatedOutputs_WhenPrepare_ThenClearOnlyScopedContents',
    () async {
      await project('tests/Test.csproj');
      final workspace = NativeDotnetTestWorkspace(currentDirectory: root.path);
      final layout = (await workspace.resolve(
        const DotnetTestRequest(),
      ) as ChimeraSuccess<DotnetTestLayout>).value;
      for (final path in [layout.resultsDirectory, layout.reportDirectory]) {
        await Directory(path).create(recursive: true);
        await File('$path/old').writeAsString('old');
      }
      expect(await workspace.prepare(layout), isA<ChimeraSuccess<bool>>());
      expect(await Directory(layout.resultsDirectory).list().toList(), isEmpty);
      expect(await File('${root.path}/tests/Test.csproj').exists(), true);
    },
  );
  test('GivenOutsideOutput_WhenPrepare_ThenDeleteNothing', () async {
    final marker = File('${root.path}/keep');
    await marker.writeAsString('keep');
    final layout = DotnetTestLayout(
      projectScope: '${root.path}/tests',
      searchDirectory: '${root.path}/tests',
      resultsDirectory: root.path,
      reportDirectory: p.join(root.path, 'tests', 'coverage-report'),
      projects: [],
    );
    expect(
      await NativeDotnetTestWorkspace(currentDirectory: root.path)
          .prepare(layout),
      isA<ChimeraFailure<bool>>(),
    );
    expect(await marker.exists(), true);
  });
  test(
    'GivenEscapingOutputLink_WhenResolve_ThenRetainOutsideContent',
    () async {
      await project('tests/Test.csproj');
      final external = await Directory.systemTemp.createTemp(
        'chimera outside ',
      );
      try {
        final marker = File('${external.path}/keep');
        await marker.writeAsString('keep');
        if (!await linkDirectory(p.join(root.path, 'docs'), external.path)) {
          markTestSkipped('Directory junction creation is unavailable');
          return;
        }
        expect(
          await NativeDotnetTestWorkspace(currentDirectory: root.path)
              .resolve(const DotnetTestRequest()),
          isA<ChimeraFailure<DotnetTestLayout>>(),
        );
        expect(await marker.exists(), true);
      } finally {
        await external.delete(recursive: true);
      }
    },
  );
  test(
    'GivenCoverageFormats_WhenValidate_ThenRequireNewArtifactsForEveryProject',
    () async {
      await project('tests/Test.csproj');
      final workspace = NativeDotnetTestWorkspace(currentDirectory: root.path);
      final layout = (await workspace.resolve(
        const DotnetTestRequest(),
      ) as ChimeraSuccess<DotnetTestLayout>).value;
      await workspace.prepare(layout);
      final result = await Directory('${layout.resultsDirectory}/one').create();
      for (final name in [
        'coverage.cobertura.xml',
        'coverage.json',
        'coverage.info',
      ]) {
        await File('${result.path}/$name').writeAsString('coverage');
      }
      final snapshot = await workspace.coverageSnapshot(layout);
      expect(snapshot.hasNewFormatsSince(const DotnetCoverageSnapshot()), true);
      expect(snapshot.hasNewFormatsSince(snapshot), false);
      expect(await workspace.hasHtmlReport(layout), false);
      await File('${layout.reportDirectory}/index.html').writeAsString('html');
      expect(await workspace.hasHtmlReport(layout), true);
    },
  );
}
