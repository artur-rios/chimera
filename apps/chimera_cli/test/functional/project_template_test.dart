import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory parent;
  setUp(
    () async => parent = await Directory.systemTemp.createTemp(
      'chimera-template-test-',
    ),
  );
  tearDown(() async => parent.delete(recursive: true));

  for (final locale in ['en', 'pt-BR']) {
    test(
      'GivenNewUnicodeDestination${locale}_WhenTemplateCreated_ThenDotfilesAndSnapshotAreWritten',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final path = '${parent.path}/Novo projeto ç';
        final code = await runChimera(
          ['project', 'from-template', path, '--json'],
          localeTag: locale,
          out: out,
          err: err,
        );
        expect(code, 0, reason: err.toString());
        final result = jsonDecode(out.toString()) as Map<String, dynamic>;
        expect(
          result['templateVersion'],
          'b4921f53c3fe1c304953ee5a6c4cbef3f0e57635',
        );
        expect(File('$path/.editorconfig').existsSync(), isTrue);
        expect(File('$path/.gitignore').existsSync(), isTrue);
        expect(File('$path/src/.gitkeep').lengthSync(), 0);
        expect(Directory('$path/.git').existsSync(), isFalse);
        expect(err.toString(), isEmpty);
      },
    );
    test(
      'GivenExistingDestination${locale}_WhenTemplateRequested_ThenContentSurvivesConflict',
      () async {
        final path = '${parent.path}/existing';
        Directory(path).createSync();
        File('$path/sentinel').writeAsStringSync('keep');
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['project', 'from-template', path, '--json'],
          localeTag: locale,
          out: out,
          err: err,
        );
        expect(code, 74);
        expect(File('$path/sentinel').readAsStringSync(), 'keep');
        expect(Directory(path).listSync().length, 1);
        expect(err.toString(), isNotEmpty);
      },
    );
  }
  test('GivenMissingDestination_WhenTemplateRequested_ThenValidationCreatesNothing', () async {
    final code = await runChimera(
      ['project', 'from-template'],
      localeTag: 'en',
      out: StringBuffer(),
      err: StringBuffer(),
    );
    expect(code, 64);
    expect(parent.listSync(), isEmpty);
  });
  test(
    'GivenHelp_WhenTemplateRequested_ThenUsageDoesNotCreateAnything',
    () async {
      final out = StringBuffer();
      final code = await runChimera(
        ['project', 'from-template', '--help'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      );
      expect(code, 0);
      expect(out.toString(), contains('from-template'));
      expect(parent.listSync(), isEmpty);
    },
  );
}
