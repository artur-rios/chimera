import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/src/runner.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late File project;
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('bump-cli-');
    project = await File('${sandbox.path}${Platform.pathSeparator}App.csproj')
        .writeAsString(
          '<Project><PropertyGroup><Version>1.2.3</Version></PropertyGroup></Project>',
        );
  });
  tearDown(() async {
    await sandbox.delete(recursive: true);
  });
  for (final locale in ['en', 'pt-BR']) {
    test(
      'Given$locale explicit version_WhenBumped_ThenOldNewAndProjectReported',
      () async {
        final out = StringBuffer();
        final code = await runChimera(
          ['dotnet', 'bump', '--project', project.path, '--version=4.5.6'],
          localeTag: locale,
          out: out,
          err: StringBuffer(),
        );
        expect(code, 0);
        expect(out.toString(), contains('1.2.3'));
        expect(out.toString(), contains('4.5.6'));
        expect(out.toString(), contains(project.path));
        expect(
          await project.readAsString(),
          contains('<Version>4.5.6</Version>'),
        );
      },
    );
  }
  for (final mode in ['major', 'minor', 'patch']) {
    test(
      'Given$mode increment_WhenJsonRequested_ThenStructuredResult',
      () async {
        final out = StringBuffer();
        final code = await runChimera(
          ['dotnet', 'bump', '--project', project.path, '--$mode', '--json'],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
        );
        expect(code, 0);
        final value = jsonDecode(out.toString()) as Map<String, dynamic>;
        expect(value['previousVersion'], '1.2.3');
        expect(
          value['version'],
          {'major': '2.0.0', 'minor': '1.3.0', 'patch': '1.2.4'}[mode],
        );
      },
    );
  }
  test(
    'GivenInvalidOrMixedOptions_WhenBumped_ThenNoModificationOrBackup',
    () async {
      final original = await project.readAsString();
      for (final options in [
        <String>[],
        ['--major', '--minor'],
        ['--version=2.0.0', '--patch'],
        ['--version=abc'],
        ['--wat'],
        ['--version=1.0.0', '--version=2.0.0'],
      ]) {
        final code = await runChimera(
          ['dotnet', 'bump', '--project', project.path, ...options],
          localeTag: 'en',
          out: StringBuffer(),
          err: StringBuffer(),
        );
        expect(code, isNot(0));
        expect(await project.readAsString(), original);
        expect(sandbox.listSync().length, 1);
      }
    },
  );
  test(
    'GivenAmbiguousDiscovery_WhenJsonRequested_ThenCandidatesReported',
    () async {
      final second = await File(
        '${sandbox.path}${Platform.pathSeparator}Other.csproj',
      ).writeAsString('<Project/>');
      final err = StringBuffer();
      expect(
        await runChimera(
          ['dotnet', 'bump', '--project', sandbox.path, '--major', '--json'],
          localeTag: 'en',
          out: StringBuffer(),
          err: err,
        ),
        isNot(0),
      );
      final value = jsonDecode(err.toString()) as Map<String, dynamic>;
      expect(
        (value['details'] as Map<String, dynamic>)['candidates'],
        containsAll([project.path, second.path]),
      );
    },
  );
  test(
    'GivenHelp_WhenRequested_ThenSourceDefaultsAndModesDocumented',
    () async {
      final out = StringBuffer();
      expect(
        await runChimera(
          ['dotnet', 'bump', '--help'],
          localeTag: 'en',
          out: out,
          err: StringBuffer(),
        ),
        0,
      );
      expect(out.toString(), contains('./src'));
      expect(out.toString(), contains('--major'));
      expect(out.toString(), contains('--version'));
    },
  );
}
