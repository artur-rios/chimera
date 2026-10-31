import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

void main() {
  for (final json in [false, true]) {
    for (final locale in ['en', 'pt-BR']) {
      test(
        'Given$locale${json}RealFullStdout_WhenHashRuns_ThenLocalizedAccess74WithoutStack',
        () async {
          final library = (await Isolate.resolvePackageUri(
            Uri.parse('package:chimera_cli/chimera_cli.dart'),
          ))!;
          final config = File.fromUri(
            library.resolve('../../../.dart_tool/package_config.json'),
          ).path;
          final directory = await Directory.systemTemp.createTemp(
            'chimera-stdout-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final harness = File('${directory.path}/locale.dart');
          await harness.writeAsString(
            "import 'dart:io'; import 'package:chimera_cli/chimera_cli.dart'; Future<void> main(List<String> args) async { exitCode = await runChimera(args, localeTag: '$locale', out: stdout, err: stderr); }",
          );
          final result = await Process.run('/bin/sh', [
            '-c',
            r'exec "$@" > /dev/full',
            'chimera-full',
            Platform.resolvedExecutable,
            '--packages=$config',
            locale == 'en'
                ? File.fromUri(library.resolve('../bin/chimera.dart')).path
                : harness.path,
            'hash',
            'generate',
            '--input=PRIVATE',
            if (json) '--json',
          ]);
          expect(result.exitCode, 74, reason: result.stderr.toString());
          final diagnostic = result.stderr as String;
          expect(diagnostic, isNot(contains('PRIVATE')));
          expect(diagnostic, isNot(contains('Unhandled exception')));
          expect(diagnostic, isNot(contains('FileSystemException')));
          expect(diagnostic, isNot(contains('#0')));
          if (json) {
            final value = jsonDecode(diagnostic) as Map<String, dynamic>;
            expect(value['error'], isA<Map<String, dynamic>>());
            expect(
              (value['error'] as Map<String, dynamic>)['code'],
              'hash-generate.output-access',
            );
          }
          expect(
            diagnostic,
            contains(
              locale == 'en'
                  ? 'The digest could not be saved or written.'
                  : 'Não foi possível salvar ou gravar o resumo.',
            ),
          );
        },
        skip: !Platform.isLinux,
        timeout: const Timeout(Duration(minutes: 1)),
      );
    }
  }
  test(
    'GivenRealFileIosink_WhenHashOutputRuns_ThenFlushCompletesBeforeSuccess',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimera-flush-');
      addTearDown(() => directory.delete(recursive: true));
      final target = File('${directory.path}/stdout.txt');
      final sink = target.openWrite();
      final result = await runChimera(
        ['hash', 'generate', '--input=abc'],
        localeTag: 'en',
        out: sink,
        err: StringBuffer(),
      );
      expect(result, 0);
      expect(
        await target.readAsString(),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\n',
      );
      await sink.close();
    },
  );
}
