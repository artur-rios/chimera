import 'dart:io';

import 'package:chimera_cli/src/runner.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('clean-cli-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  for (final locale in ['en', 'pt-BR']) {
    test(
      'Given${locale}_WhenNoConfirmation_ThenPreviewAndNoDeletion',
      () async {
        final bin = await Directory('${root.path}${Platform.pathSeparator}bin')
            .create();
        final out = StringBuffer();
        final err = StringBuffer();
        final code = await runChimera(
          ['dotnet', 'clean', '--root', root.path],
          localeTag: locale,
          out: out,
          err: err,
          readStandardInput: () async => 'no',
        );
        expect(code, isNot(0));
        expect(out.toString(), contains(bin.path));
        expect(out.toString(), contains(root.path));
        expect(await bin.exists(), isTrue);
      },
    );
  }
  test('GivenYesFlag_WhenCleaned_ThenDeletionAndCount', () async {
    final bin = await Directory('${root.path}${Platform.pathSeparator}bin')
        .create();
    final out = StringBuffer();
    final code = await runChimera(
      ['dotnet', 'clean', '--root', root.path, '--yes'],
      localeTag: 'en',
      out: out,
      err: StringBuffer(),
    );
    expect(code, 0);
    expect(await bin.exists(), isFalse);
    expect(out.toString(), contains('1'));
  });
  test('GivenExplicitInteractiveYes_WhenCleaned_ThenDeletion', () async {
    final bin = await Directory('${root.path}${Platform.pathSeparator}bin')
        .create();
    final code = await runChimera(
      ['dotnet', 'clean', '--root', root.path],
      localeTag: 'en',
      out: StringBuffer(),
      err: StringBuffer(),
      readStandardInput: () async => 'yes',
    );
    expect(code, 0);
    expect(await bin.exists(), isFalse);
  });
  test('GivenUnknownOrDuplicateOption_WhenInvoked_ThenNoDeletion', () async {
    final bin = await Directory('${root.path}${Platform.pathSeparator}bin')
        .create();
    for (final extra in [
      ['--wat'],
      ['--root', root.path],
    ]) {
      final code = await runChimera(
        ['dotnet', 'clean', '--root', root.path, '--yes', ...extra],
        localeTag: 'en',
        out: StringBuffer(),
        err: StringBuffer(),
      );
      expect(code, isNot(0));
      expect(await bin.exists(), isTrue);
    }
  });
  test('GivenHelp_WhenRequested_ThenDocumentedYesAndDefaultScope', () async {
    final out = StringBuffer();
    expect(
      await runChimera(
        ['dotnet', 'clean', '--help'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      ),
      0,
    );
    expect(out.toString(), contains('--yes'));
    expect(out.toString(), contains('./src'));
  });
}
