import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  for (final locale in ['en', 'pt-BR']) {
    for (final unit in ['words', 'sentences', 'paragraphs']) {
      test(
        'Given$locale${unit}_WhenGenerated_ThenStableJsonAndExactOutput',
        () async {
          final out = StringBuffer(), err = StringBuffer();
          final code = await runChimera(
            ['lorem', 'generate', '--unit=$unit', '--count=2', '--json'],
            localeTag: locale,
            out: out,
            err: err,
            readStandardInput: () => throw StateError('must not read'),
          );
          expect(code, 0);
          final data = jsonDecode(out.toString()) as Map<String, dynamic>;
          expect(data.keys, ['unit', 'count', 'text']);
          expect(data['unit'], unit);
          expect(data['count'], 2);
          expect(err.toString(), '');
        },
      );
    }
    for (final flags in [
      ['--count=0'],
      ['--unit=invalid'],
      ['--input=PRIVATE'],
      ['--file=PRIVATE'],
      ['--stdin'],
      ['extra'],
      ['--output='],
    ]) {
      test(
        'Given$locale${flags}_WhenGenerated_ThenValidationBeforeIo',
        () async {
          final out = StringBuffer(), err = StringBuffer();
          var written = false;
          final code = await runChimera(
            ['lorem', 'generate', ...flags, '--json'],
            localeTag: locale,
            out: out,
            err: err,
            writeOutputFile: (_, _) async {
              written = true;
            },
          );
          expect(code, 64);
          expect(written, false);
          expect(out.toString(), '');
          expect(_error(err.toString())['kind'], 'validation');
          expect(err.toString(), isNot(contains('PRIVATE')));
        },
      );
    }
    test(
      'Given${locale}OutputFile_WhenGenerated_ThenExactUtf8NoNewlineAndTransactionalDefault',
      () async {
        final directory = await Directory.systemTemp.createTemp('lorem-');
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/lorem.txt');
        await file.writeAsString('OLD');
        final out = StringBuffer();
        expect(
          await runChimera(
            [
              'lorem',
              'generate',
              '--unit=words',
              '--count=3',
              '--output=${file.path}',
            ],
            localeTag: locale,
            out: out,
            err: StringBuffer(),
          ),
          0,
        );
        expect(await file.readAsBytes(), utf8.encode('Lorem ipsum dolor'));
        expect(out.toString(), isNot(contains('Lorem ipsum')));
        expect((await directory.list().toList()).length, 1);
      },
    );
    test(
      'Given${locale}WriterFailure_WhenGenerated_ThenSafeAccessFailure',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        expect(
          await runChimera(
            ['lorem', 'generate', '--output=PRIVATE', '--json'],
            localeTag: locale,
            out: out,
            err: err,
            writeOutputFile: (_, _) async =>
                throw FileSystemException('PRIVATE'),
          ),
          74,
        );
        expect(out.toString(), '');
        expect(err.toString(), isNot(contains('PRIVATE')));
        expect(_error(err.toString())['kind'], 'access');
      },
    );
    for (final json in [false, true]) {
      test('Given$locale${json}RealFullStdout_WhenGenerated_ThenSafe74', () async {
        final library = (await Isolate.resolvePackageUri(
          Uri.parse('package:chimera_cli/chimera_cli.dart'),
        ))!;
        final config = File.fromUri(
          library.resolve('../../../.dart_tool/package_config.json'),
        ).path;
        final directory = await Directory.systemTemp.createTemp(
          'lorem-stdout-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final harness = File('${directory.path}/locale.dart');
        await harness.writeAsString(
          "import 'dart:io'; import 'package:chimera_cli/chimera_cli.dart'; Future<void> main(List<String> args) async { exitCode = await runChimera(args, localeTag: '$locale', out: stdout, err: stderr); }",
        );
        final result = await Process.run('/bin/sh', [
          '-c',
          r'exec "$@" > /dev/full',
          'lorem',
          Platform.resolvedExecutable,
          '--packages=$config',
          locale == 'en'
              ? File.fromUri(library.resolve('../bin/chimera.dart')).path
              : harness.path,
          'lorem',
          'generate',
          if (json) '--json',
        ]);
        expect(result.exitCode, 74);
        expect(result.stdout, '');
        expect(result.stderr, isNot(contains('Unhandled exception')));
        expect(result.stderr, isNot(contains('FileSystemException')));
        expect(
          result.stderr,
          contains(
            const MessageCatalog().lookup(locale, 'error.lorem.outputAccess'),
          ),
        );
        if (json) {
          expect(_error(result.stderr as String)['kind'], 'access');
        }
      }, skip: !Platform.isLinux);
    }
  }
  test('GivenInjectedResource_WhenGenerated_Then75WithoutOutput', () async {
    final out = StringBuffer(), err = StringBuffer();
    expect(
      await runChimera(
        ['lorem', 'generate', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        loremService: const LoremService(
          generator: LoremGenerator(maxOutputCharacters: 1),
        ),
      ),
      75,
    );
    expect(out.toString(), '');
    expect(_error(err.toString())['kind'], 'resource');
  });
  test('GivenRealIosink_WhenGenerated_ThenBytesFlushedBeforeSuccess', () async {
    final directory = await Directory.systemTemp.createTemp('lorem-flush-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/stdout.txt');
    final sink = file.openWrite();
    expect(
      await runChimera(
        ['lorem', 'generate', '--unit=words', '--count=3'],
        localeTag: 'en',
        out: sink,
        err: StringBuffer(),
      ),
      0,
    );
    expect(await file.readAsString(), 'Lorem ipsum dolor');
    await sink.close();
  });
  for (final resource in [false, true]) {
    test(
      'Given${resource}SerializationFailure_WhenJsonRequested_ThenTypedErrorBeforeFileWrite',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        var writes = 0;
        expect(
          await runChimera(
            ['lorem', 'generate', '--output=PRIVATE', '--json'],
            localeTag: 'en',
            out: out,
            err: err,
            loremJsonEncoder: (_) {
              if (resource) throw OutOfMemoryError();
              throw StateError('PRIVATE');
            },
            writeOutputFile: (_, _) async {
              writes++;
            },
          ),
          resource ? 75 : 74,
        );
        expect(writes, 0);
        expect(out.toString(), '');
        expect(err.toString(), isNot(contains('PRIVATE')));
      },
    );
  }
  for (final failure in ['stage', 'replace', 'reserve']) {
    test(
      'Given${failure}TransactionFailure_WhenOutputRequested_ThenOriginalBytesAndNoPartialText',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'lorem-transaction-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/result.txt');
        await target.writeAsString('previous');
        var reached = false;
        Never fail() {
          reached = true;
          throw const FileSystemException('PRIVATE');
        }

        final out = StringBuffer(), err = StringBuffer();
        expect(
          await runChimera(
            ['lorem', 'generate', '--output=${target.path}', '--json'],
            localeTag: 'en',
            out: out,
            err: err,
            writeOutputStage: failure == 'stage'
                ? (path, bytes) async {
                    await File(path).writeAsBytes([bytes.first]);
                    fail();
                  }
                : null,
            outputFileOperations: TransactionalFileOperations(
              tryReserve: failure == 'reserve' ? (_) async => fail() : null,
              rename: failure == 'replace'
                  ? (source, path) async {
                      if (source.path.contains('.chimera-stage-')) fail();
                      await source.rename(path);
                    }
                  : null,
            ),
          ),
          74,
        );
        expect(reached, isTrue);
        expect(out.toString(), '');
        expect(err.toString(), isNot(contains('PRIVATE')));
        expect(await target.readAsString(), 'previous');
        expect(directory.listSync().length, 1);
      },
    );
  }
  test('GivenDefaults_WhenGenerated_ThenHumanExactText', () async {
    final out = StringBuffer();
    expect(
      await runChimera(
        ['lorem', 'generate'],
        localeTag: 'en',
        out: out,
        err: StringBuffer(),
      ),
      0,
    );
    expect(
      out.toString(),
      'Lorem ipsum dolor sit amet. Consectetur adipiscing elit.',
    );
  });
}

Map<String, Object?> _error(String value) =>
    ((jsonDecode(value) as Map<String, Object?>)['error']
        as Map<String, Object?>);
