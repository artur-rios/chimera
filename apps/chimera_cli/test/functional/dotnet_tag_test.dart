import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  Future<ProcessResult> git(List<String> args) =>
      Process.run('git', args, workingDirectory: root.path);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('chimera-tag-test-');
    Directory('${root.path}/src/Library').createSync(recursive: true);
    File('${root.path}/src/Library/Example.csproj').writeAsStringSync(
      '<Project><PropertyGroup><Version>1.2.3</Version></PropertyGroup></Project>',
    );
    for (final args in [
      ['init'],
      ['config', 'user.name', 'Chimera Tests'],
      ['config', 'user.email', 'chimera@example.invalid'],
      ['add', '.'],
      ['commit', '-m', 'initial'],
    ]) {
      final result = await git(args);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    }
  });
  tearDown(() async => root.delete(recursive: true));
  for (final locale in ['en', 'pt-BR']) {
    test(
      'GivenProject${locale}_WhenTagged_ThenAnnotatedLocalTagWithoutPush',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['dotnet', 'tag', '--project', '${root.path}/src', '--json'],
          localeTag: locale,
          out: out,
          err: err,
        );
        expect(code, 0, reason: err.toString());
        final value = jsonDecode(out.toString()) as Map<String, dynamic>;
        expect(value['tag'], 'v1.2.3');
        expect(value['pushed'], isFalse);
        expect(value['localCreated'], isTrue);
        expect(
          (await git(['cat-file', '-t', 'refs/tags/v1.2.3'])).stdout
              .toString()
              .trim(),
          'tag',
        );
        expect(
          (await git(['tag', '-l', '--format=%(contents:subject)', 'v1.2.3']))
              .stdout
              .toString()
              .trim(),
          'Release 1.2.3',
        );
      },
    );
  }
  test(
    'GivenExistingTag_WhenTaggedAgain_ThenConflictPreservesObject',
    () async {
      await git(['tag', '-a', 'v1.2.3', '-m', 'original']);
      final original = (await git(['rev-parse', 'refs/tags/v1.2.3'])).stdout;
      final code = await runChimera(
        ['dotnet', 'tag', '--project', '${root.path}/src', '--json'],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
      );
      expect(code, 73);
      expect((await git(['rev-parse', 'refs/tags/v1.2.3'])).stdout, original);
    },
  );
  test('GivenMissingRemote_WhenPushed_ThenFailureRetainsLocalTag', () async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runChimera(
      [
        'dotnet',
        'tag',
        '--project',
        '${root.path}/src',
        '--push',
        '--remote',
        'missing',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );
    expect(code, isNot(0));
    final error = jsonDecode(out.toString()) as Map<String, dynamic>;
    final details = error['details'] as Map<String, dynamic>;
    expect(details['localCreated'], isTrue);
    expect(
      (await git(['show-ref', '--verify', '--quiet', 'refs/tags/v1.2.3']))
          .exitCode,
      0,
    );
  });
  test(
    'GivenExplicitLocalRemote_WhenPushed_ThenOnlySelectedTagIsPublished',
    () async {
      final remote = await Directory.systemTemp.createTemp('chimera-tag-bare-');
      addTearDown(() => remote.delete(recursive: true));
      expect(
        (await Process.run('git', ['init', '--bare', remote.path])).exitCode,
        0,
      );
      await git(['remote', 'add', 'local-test', remote.path]);
      await git(['tag', 'unrelated']);
      final code = await runChimera(
        [
          'dotnet',
          'tag',
          '--project',
          '${root.path}/src',
          '--push',
          '--remote',
          'local-test',
        ],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
      );
      expect(code, 0);
      final refs = await Process.run('git', [
        '--git-dir',
        remote.path,
        'for-each-ref',
        '--format=%(refname)',
      ]);
      expect(refs.stdout.toString().trim(), 'refs/tags/v1.2.3');
    },
  );
}
