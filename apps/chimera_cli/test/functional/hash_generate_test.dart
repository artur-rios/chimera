import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenAbc_WhenHashCommandRuns_ThenHumanDigest', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    expect(
      await runChimera(
        ['hash', 'generate', '--input=abc'],
        out: out,
        err: err,
        localeTag: 'en',
      ),
      0,
    );
    expect(
      out.toString(),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad\n',
    );
    expect(err.toString(), isEmpty);
  });
  for (final locale in ['en', 'pt-BR']) {
    for (final algorithm in ['sha256', 'sha384', 'sha512', 'md5', 'sha1']) {
      test(
        'Given$locale${algorithm}_WhenJsonCommandRuns_ThenStableLocalizedWarning',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          expect(
            await runChimera(
              [
                'hash',
                'generate',
                '--input=abc',
                '--algorithm=$algorithm',
                '--json',
              ],
              out: out,
              err: err,
              localeTag: locale,
            ),
            0,
          );
          final value = jsonDecode(out.toString()) as Map<String, dynamic>;
          expect(value.keys.toList(), [
            'algorithm',
            'digest',
            'legacy',
            'warning',
          ]);
          expect(value['algorithm'], algorithm);
          final legacy = algorithm == 'md5' || algorithm == 'sha1';
          expect(value['legacy'], legacy);
          expect(
            value['warning'],
            legacy
                ? contains(
                    locale == 'en'
                        ? 'unsuitable for security decisions'
                        : 'inadequados para decisões de segurança',
                  )
                : isNull,
          );
          expect(err.toString(), isEmpty);
        },
      );
    }
  }
  for (final flags in [
    <String>[],
    ['--input=a', '--stdin'],
    ['--algorithm=SECRET', '--stdin'],
    ['--file='],
    ['--input=a', '--output='],
    ['--input=a', '--unknown'],
    ['--input=a', 'trailing'],
  ]) {
    test(
      'GivenInvalid${flags.join()}Options_WhenRun_ThenRejectsBeforeIo',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        var reads = 0;
        expect(
          await runChimera(
            ['hash', 'generate', ...flags, '--json'],
            out: out,
            err: err,
            localeTag: 'en',
            readStandardInputBytes: () async {
              reads++;
              return [];
            },
            readFileBytes: (_) async {
              reads++;
              return [];
            },
          ),
          64,
        );
        expect(out.toString(), isEmpty);
        expect(reads, 0);
        expect(
          (jsonDecode(err.toString()) as Map<String, dynamic>)['error'],
          isNotNull,
        );
        expect(err.toString(), isNot(contains('SECRET')));
      },
    );
  }
  for (final source in ['stdin', 'file']) {
    for (final resource in [false, true]) {
      test(
        'Given$source${resource ? 'Resource' : 'Access'}Failure_WhenRun_ThenNoPartialOutput',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          Future<List<int>> fail() async =>
              resource ? throw OutOfMemoryError() : throw StateError('SECRET');
          expect(
            await runChimera(
              [
                'hash',
                'generate',
                source == 'stdin' ? '--stdin' : '--file=fixture',
                '--json',
              ],
              out: out,
              err: err,
              localeTag: 'en',
              readStandardInputBytes: fail,
              readFileBytes: (_) => fail(),
            ),
            resource ? 75 : 74,
          );
          expect(out.toString(), isEmpty);
          expect(err.toString(), isNot(contains('SECRET')));
        },
      );
    }
  }
  test(
    'GivenBinaryFile_WhenSubprocessReadsFileAndStdin_ThenExactKnownDigest',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimera-hash-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/input.bin');
      await file.writeAsBytes([0, 255, 128, 239, 187, 191, 0, 10]);
      final library = (await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_cli/chimera_cli.dart'),
      ))!;
      final entrypoint = File.fromUri(library.resolve('../bin/chimera.dart'))
          .path;
      final executable =
          '${directory.path}/chimera-hash${Platform.isWindows ? '.exe' : ''}';
      final compilation = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        entrypoint,
        '-o',
        executable,
      ]);
      expect(compilation.exitCode, 0, reason: compilation.stderr.toString());
      final fixture =
          (jsonDecode(
                File.fromUri(
                  library.resolve(
                    '../../../tests/fixtures/hashes/vectors.json',
                  ),
                ).readAsStringSync(),
              ) as List<dynamic>)[2]
              as Map<String, dynamic>;
      for (final algorithm in ['sha256', 'sha384', 'sha512', 'md5', 'sha1']) {
        final process = await Process.start(executable, [
          'hash',
          'generate',
          '--stdin',
          '--algorithm=$algorithm',
          '--json',
        ]);
        process.stdin.add(await file.readAsBytes());
        await process.stdin.close();
        final stdout = await process.stdout.transform(utf8.decoder).join();
        final stderr = await process.stderr.transform(utf8.decoder).join();
        expect(await process.exitCode, 0, reason: stderr);
        expect(
          (jsonDecode(stdout) as Map<String, dynamic>)['digest'],
          (fixture['digests'] as Map<String, dynamic>)[algorithm],
        );
        final saved = File('${directory.path}/$algorithm.txt');
        await saved.writeAsString('previous');
        final result = await Process.run(executable, [
          'hash',
          'generate',
          '--file=${file.path}',
          '--algorithm=$algorithm',
          '--output=${saved.path}',
          '--json',
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          await saved.readAsString(),
          '${(fixture['digests'] as Map<String, dynamic>)[algorithm]}\n',
        );
        expect(
          directory.listSync().where((e) => e.path.contains('.tmp')),
          isEmpty,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  for (final failure in ['writer', 'json', 'resource']) {
    test(
      'Given${failure}Failure_WhenOutputPrepared_ThenNoSuccessOrPartialOutput',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        var writes = 0;
        expect(
          await runChimera(
            ['hash', 'generate', '--input=abc', '--output=output', '--json'],
            out: out,
            err: err,
            localeTag: 'en',
            writeOutputFile: (_, _) async {
              writes++;
              throw StateError('SECRET');
            },
            hashGenerateJsonEncoder: failure == 'writer'
                ? null
                : (_) => failure == 'resource'
                      ? throw OutOfMemoryError()
                      : throw StateError('SECRET'),
          ),
          failure == 'resource' ? 75 : 74,
        );
        expect(writes, failure == 'writer' ? 1 : 0);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('SECRET')));
      },
    );
  }
  test('GivenServiceResourceFailure_WhenRun_ThenResourceExit', () async {
    expect(
      await runChimera(
        ['hash', 'generate', '--input=abc'],
        out: StringBuffer(),
        err: StringBuffer(),
        localeTag: 'en',
        hashGenerateService: HashGenerateService(
          generator: HashGenerator.forTesting(
            hash: (_, _) => throw OutOfMemoryError(),
          ),
        ),
      ),
      75,
    );
  });
  for (final failure in ['partial', 'reserve', 'replace']) {
    test(
      'Given${failure}TransactionFailure_WhenHashSaved_ThenOldTargetAndNoArtifacts',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'chimera-hash-transaction-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/hash.txt');
        await target.writeAsString('previous private result');
        final out = StringBuffer();
        final err = StringBuffer();
        var triggered = false;
        Never fail() => throw const FileSystemException('SECRET', 'SECRET');
        final exit = await runChimera(
          [
            'hash',
            'generate',
            '--input=abc',
            '--output=${target.path}',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
          writeOutputStage: failure == 'partial'
              ? (path, bytes) async {
                  await File(path).writeAsBytes([bytes.first]);
                  triggered = true;
                  fail();
                }
              : null,
          outputFileOperations: TransactionalFileOperations(
            tryReserve: (candidate) async {
              if (failure == 'reserve') {
                triggered = true;
                fail();
              }
              await candidate.create(exclusive: true);
              return true;
            },
            rename: (source, path) async {
              if (failure == 'replace' &&
                  source.path.contains('.chimera-stage-')) {
                triggered = true;
                fail();
              }
              await source.rename(path);
            },
          ),
        );
        expect(exit, 74);
        expect(triggered, isTrue);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('SECRET')));
        expect(await target.readAsString(), 'previous private result');
        expect(directory.listSync().length, 1);
      },
    );
  }
  for (final locale in ['en', 'pt-BR']) {
    for (final algorithm in ['md5', 'sha1']) {
      for (final save in [false, true]) {
        test(
          'Given$locale$algorithm${save}HumanOutput_WhenGenerated_ThenLegacyWarningAlwaysVisible',
          () async {
            final out = StringBuffer();
            final err = StringBuffer();
            expect(
              await runChimera(
                [
                  'hash',
                  'generate',
                  '--input=',
                  '--algorithm=$algorithm',
                  if (save) '--output=result.txt',
                ],
                localeTag: locale,
                out: out,
                err: err,
                writeOutputFile: (_, _) async {},
              ),
              0,
            );
            expect(
              out.toString(),
              contains(
                locale == 'en'
                    ? 'unsuitable for security decisions'
                    : 'inadequados para decisões de segurança',
              ),
            );
            expect(err.toString(), isEmpty);
          },
        );
      }
    }
  }
}
