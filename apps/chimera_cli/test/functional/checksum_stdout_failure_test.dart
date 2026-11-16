import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

import '../support/compiled_program.dart';

void main() {
  group(
    'Real full stdout',
    () {
      final executables = <String, String>{};
      // Compiled once per run, outside each test's deadline: compiling
      // the CLI from source within it took most of the minute on a busy
      // agent.
      setUpAll(() async {
        for (final locale in ['en', 'pt-BR']) {
          executables[locale] = await compiledChimeraIn(locale);
        }
      });
      for (final json in [false, true]) {
        for (final locale in ['en', 'pt-BR']) {
          test(
            'Given$locale${json}RealFullStdout_WhenChecksumRuns_ThenLocalizedAccess74WithoutStack',
            () async {
              final result = await Process.run('/bin/sh', [
                '-c',
                r'exec "$@" > /dev/full',
                'chimera-full',
                executables[locale]!,
                'checksum',
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
                  'checksum-generate.output-access',
                );
              }
              expect(
                diagnostic,
                contains(
                  locale == 'en'
                      ? 'The checksum could not be saved or written.'
                      : 'Não foi possível salvar ou gravar a soma de verificação.',
                ),
              );
            },
            timeout: const Timeout(Duration(minutes: 1)),
          );
        }
      }
    },
    skip: !Platform.isLinux,
    timeout: compilationTimeout,
  );
  test('GivenRealFileIosink_WhenChecksumOutputRuns_ThenFlushCompletesBeforeSuccess', () async {
    final directory = await Directory.systemTemp.createTemp('chimera-flush-');
    addTearDown(() => directory.delete(recursive: true));
    final target = File('${directory.path}/stdout.txt');
    final sink = target.openWrite();
    final result = await runChimera(
      ['checksum', 'generate', '--input=abc'],
      localeTag: 'en',
      out: sink,
      err: StringBuffer(),
    );
    expect(result, 0);
    expect(await target.readAsString(), '352441c2\n');
    await sink.close();
  });
}
