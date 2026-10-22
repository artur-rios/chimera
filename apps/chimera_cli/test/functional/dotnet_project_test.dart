import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'chimera-dotnet-project-',
    ),
  );
  tearDown(() async => directory.delete(recursive: true));
  for (final locale in ['en', 'pt-BR']) {
    for (final mode in ['default', 'minimal', 'nuget']) {
      test(
        'Given$locale${mode}_WhenDotnetProjectScaffolded_ThenApprovedProjectIsCreated',
        () async {
          final out = StringBuffer(), err = StringBuffer();
          final code = await runChimera(
            [
              'dotnet',
              'init-project',
              '--name',
              'Example.Library',
              '--parent',
              directory.path,
              if (mode != 'default') '--$mode',
              '--json',
            ],
            localeTag: locale,
            out: out,
            err: err,
          );
          expect(code, 0, reason: err.toString());
          final value = jsonDecode(out.toString()) as Map<String, dynamic>;
          expect(value['mode'], mode == 'nuget' ? 'nuget' : 'minimal');
          final content = File(
            '${directory.path}/Example.Library/Example.Library.csproj',
          ).readAsStringSync();
          expect(
            content,
            contains('<TargetFramework>net10.0</TargetFramework>'),
          );
          expect(content, isNot(contains('__AUTHOR__')));
          if (mode == 'nuget') {
            for (final tag in [
              'Authors',
              'Company',
              'Description',
              'PackageId',
              'Version',
              'RepositoryUrl',
              'PackageLicenseFile',
              'PackageReadmeFile',
            ]) {
              expect(content, contains('<$tag></$tag>'));
            }
          } else {
            expect(content, isNot(contains('<PackageId>')));
          }
        },
      );
    }
  }
  for (final options in [
    <String>[],
    ['--name', '../escape'],
    ['--name', 'x', '--minimal', '--nuget'],
    ['--name', 'x', '--unknown'],
  ]) {
    test(
      'GivenInvalidOptions${options.join('_')}_WhenScaffolding_ThenNoOutputIsCreated',
      () async {
        final code = await runChimera(
          ['dotnet', 'init-project', '--parent', directory.path, ...options],
          localeTag: 'en',
          out: StringBuffer(),
          err: StringBuffer(),
        );
        expect(code, 64);
        expect(directory.listSync(), isEmpty);
      },
    );
  }
  test(
    'GivenExistingDestination_WhenScaffolding_ThenExistingProjectSurvives',
    () async {
      final existing = File('${directory.path}/Example/Example.csproj');
      existing.parent.createSync();
      existing.writeAsStringSync('keep');
      final code = await runChimera(
        [
          'dotnet',
          'init-project',
          '--name',
          'Example',
          '--parent',
          directory.path,
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
      );
      expect(code, 74);
      expect(existing.readAsStringSync(), 'keep');
    },
  );
}
