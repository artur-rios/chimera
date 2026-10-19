import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenAbc_WhenChecksumCommandRuns_ThenHumanChecksum', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    expect(
      await runChimera(
        ['checksum', 'generate', '--input=abc'],
        out: out,
        err: err,
        localeTag: 'en',
      ),
      0,
    );
    expect(out.toString(), '352441c2\n');
    expect(err.toString(), isEmpty);
  });
  for (final locale in ['en', 'pt-BR']) {
    for (final algorithm in ['crc32', 'adler32']) {
      test(
        'Given$locale${algorithm}_WhenJsonCommandRuns_ThenExactStableJson',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          expect(
            await runChimera(
              [
                'checksum',
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
          expect(value.keys.toList(), ['algorithm', 'checksum']);
          expect(value['algorithm'], algorithm);
          final checksum = algorithm == 'crc32' ? '352441c2' : '024d0127';
          expect(
            out.toString(),
            '{"algorithm":"$algorithm","checksum":"$checksum"}\n',
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
            ['checksum', 'generate', ...flags, '--json'],
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
                'checksum',
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
  test('GivenBinaryFile_WhenSubprocessReadsFileAndStdin_ThenExactKnownChecksum', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-checksum-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/input.bin');
    await file.writeAsBytes([0, 255, 128, 13, 10]);
    final library = (await Isolate.resolvePackageUri(
      Uri.parse('package:chimera_cli/chimera_cli.dart'),
    ))!;
    final entrypoint = File.fromUri(library.resolve('../bin/chimera.dart'))
        .path;
    final executable =
        '${directory.path}/chimera-checksum${Platform.isWindows ? '.exe' : ''}';
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
                  '../../../tests/fixtures/checksums/vectors.json',
                ),
              ).readAsStringSync(),
            ) as List<dynamic>)[3]
            as Map<String, dynamic>;
    for (final algorithm in ['crc32', 'adler32']) {
      final process = await Process.start(executable, [
        'checksum',
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
        (jsonDecode(stdout) as Map<String, dynamic>)['checksum'],
        (fixture['checksums'] as Map<String, dynamic>)[algorithm],
      );
      final saved = File('${directory.path}/$algorithm.txt');
      await saved.writeAsString('previous');
      final result = await Process.run(executable, [
        'checksum',
        'generate',
        '--file=${file.path}',
        '--algorithm=$algorithm',
        '--output=${saved.path}',
        '--json',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        await saved.readAsString(),
        '${(fixture['checksums'] as Map<String, dynamic>)[algorithm]}\n',
      );
      expect(
        directory.listSync().where((e) => e.path.contains('.tmp')),
        isEmpty,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
  for (final failure in ['writer', 'json', 'resource']) {
    test(
      'Given${failure}Failure_WhenOutputPrepared_ThenNoSuccessOrPartialOutput',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        var writes = 0;
        expect(
          await runChimera(
            [
              'checksum',
              'generate',
              '--input=abc',
              '--output=output',
              '--json',
            ],
            out: out,
            err: err,
            localeTag: 'en',
            writeOutputFile: (_, _) async {
              writes++;
              throw StateError('SECRET');
            },
            checksumGenerateJsonEncoder: failure == 'writer'
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
        ['checksum', 'generate', '--input=abc'],
        out: StringBuffer(),
        err: StringBuffer(),
        localeTag: 'en',
        checksumGenerateService: ChecksumGenerateService(
          generator: ChecksumGenerator.forTesting(
            checksum: (_, _) => throw OutOfMemoryError(),
          ),
        ),
      ),
      75,
    );
  });
  for (final failure in ['partial', 'reserve', 'replace']) {
    test(
      'Given${failure}TransactionFailure_WhenChecksumSaved_ThenOldTargetAndNoArtifacts',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'chimera-checksum-transaction-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/checksum.txt');
        await target.writeAsString('previous private result');
        final out = StringBuffer();
        final err = StringBuffer();
        var triggered = false;
        Never fail() => throw const FileSystemException('SECRET', 'SECRET');
        final exit = await runChimera(
          [
            'checksum',
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
    test(
      'Given${locale}Help_WhenRequested_ThenDocumentsAlgorithmsWithoutReadingInput',
      () async {
        final out = StringBuffer();
        expect(
          await runChimera(
            ['--help', 'checksum', 'generate'],
            localeTag: locale,
            out: out,
            err: StringBuffer(),
            readStandardInputBytes: () => throw StateError('must not read'),
          ),
          0,
        );
        expect(out.toString(), contains('crc32|adler32'));
        expect(out.toString(), contains('checksum'));
      },
    );
    for (final source in ['file', 'stdin']) {
      test(
        'Given$locale${source}InvalidBytes_WhenGenerated_ThenSafeTypedValidationWithoutOutput',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          expect(
            await runChimera(
              [
                'checksum',
                'generate',
                source == 'file' ? '--file=PRIVATE' : '--stdin',
                '--json',
              ],
              localeTag: locale,
              out: out,
              err: err,
              readFileBytes: (_) async => [256],
              readStandardInputBytes: () async => [-1],
            ),
            64,
          );
          expect(out.toString(), isEmpty);
          final diagnostic = jsonDecode(err.toString()) as Map<String, dynamic>;
          expect(
            (diagnostic['error'] as Map<String, dynamic>)['code'],
            'checksum-generate.invalid-input',
          );
          expect(err.toString(), isNot(contains('PRIVATE')));
        },
      );
    }
  }
  test(
    'GivenPartialResourceFailure_WhenFileStaged_ThenOldTargetAndNoArtifacts',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-checksum-resource-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final target = File('${directory.path}/checksum.txt');
      await target.writeAsString('previous');
      final out = StringBuffer();
      final err = StringBuffer();
      final result = await runChimera(
        [
          'checksum',
          'generate',
          '--input=PRIVATE',
          '--output=${target.path}',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        writeOutputStage: (path, bytes) async {
          await File(path).writeAsBytes([bytes.first]);
          throw OutOfMemoryError();
        },
      );
      expect(result, 75);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('PRIVATE')));
      expect(await target.readAsString(), 'previous');
      expect(directory.listSync().length, 1);
    },
  );
}
