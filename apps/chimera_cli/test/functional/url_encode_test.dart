import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const source = 'https://example.test/ação 😀?a=1&b=%20\r\n';
  const answers = {
    'component': 'https%3A%2F%2Fexample.test%2Fa%C3%A7%C3%A3o%20%F0%9F%98%80%3Fa%3D1%26b%3D%2520%0D%0A',
    'full':
        'https://example.test/a%C3%A7%C3%A3o%20%F0%9F%98%80?a=1&b=%2520%0D%0A',
  };
  for (final locale in ['en', 'pt-BR']) {
    for (final sourceKind in ['stdin', 'file']) {
      for (final json in [false, true]) {
        test('Given${locale}Empty$sourceKind$json'
            '_WhenUrlEncoded_ThenEmptySharedResultReturns', () async {
          final out = StringBuffer();
          final err = StringBuffer();
          final exit = await runChimera(
            [
              'url',
              'encode',
              if (sourceKind == 'stdin') '--stdin' else '--file=private',
              if (json) '--json',
            ],
            localeTag: locale,
            out: out,
            err: err,
            readStandardInputBytes: () async => [],
            readFileBytes: (_) async => [],
          );
          expect(exit, 0);
          expect(err.toString(), isEmpty);
          expect(
            out.toString(),
            json ? '{"encoded":"","mode":"component"}\n' : '',
          );
        });
      }
    }
    for (final entry in answers.entries) {
      for (final kind in ['argument', 'stdin', 'file', 'empty']) {
        for (final json in [false, true]) {
          test('Given$locale${entry.key}$kind$json'
              '_WhenUrlEncoded_ThenExactSharedResultReturns', () async {
            final out = StringBuffer();
            final err = StringBuffer();
            final exit = await runChimera(
              [
                'url',
                'encode',
                '--mode=${entry.key}',
                if (kind == 'argument') '--input=$source',
                if (kind == 'empty') '--input=',
                if (kind == 'stdin') '--stdin',
                if (kind == 'file') '--file=private',
                if (json) '--json',
              ],
              localeTag: locale,
              out: out,
              err: err,
              readStandardInputBytes: () async => utf8.encode(source),
              readFileBytes: (_) async => utf8.encode(source),
            );
            expect(exit, 0);
            expect(err.toString(), isEmpty);
            final encoded = kind == 'empty' ? '' : entry.value;
            expect(
              out.toString(),
              json
                  ? '${jsonEncode({'encoded': encoded, 'mode': entry.key})}\n'
                  : encoded,
            );
          });
        }
      }
    }
    test(
      'Given${locale}Help_WhenRequested_ThenModesDefaultAndExitCodesAreDocumented',
      () async {
        final out = StringBuffer();
        expect(
          await runChimera(
            ['--help', 'url', 'encode'],
            localeTag: locale,
            out: out,
            err: StringBuffer(),
          ),
          0,
        );
        expect(out.toString(), contains('chimera url encode'));
        expect(out.toString(), contains('--mode=component|full'));
        expect(
          out.toString(),
          contains(
            locale == 'en'
                ? 'Default mode: component.'
                : 'Modo padrão: component.',
          ),
        );
        for (final code in ['64', '74', '75']) {
          expect(out.toString(), contains(code));
        }
      },
    );
    for (final outputJson in [false, true]) {
      test(
        'Given${locale}ExistingFile${outputJson}_WhenSaved_ThenExactUtf8ReplacesTargetBeforeSuccess',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'chimera-url-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final target = File('${directory.path}/result.txt');
          await target.writeAsString('prior');
          final out = StringBuffer();
          final err = StringBuffer();
          expect(
            await runChimera(
              [
                'url',
                'encode',
                '--input=á /',
                '-o',
                target.path,
                if (outputJson) '--json',
              ],
              localeTag: locale,
              out: out,
              err: err,
              writeOutputStage: (path, bytes) async {
                expect(out.toString(), isEmpty);
                expect(await target.readAsString(), 'prior');
                await File(path).writeAsBytes(bytes, flush: true);
              },
            ),
            0,
          );
          expect(await target.readAsString(), '%C3%A1%20%2F');
          expect(
            out.toString(),
            outputJson
                ? '{"encoded":"%C3%A1%20%2F","mode":"component"}\n'
                : locale == 'en'
                ? 'URL encoded text saved.\n'
                : 'Texto codificado em URL salvo.\n',
          );
          expect(err.toString(), isEmpty);
          expect(await directory.list().length, 1);
        },
      );
    }
  }
  for (final fixture in <(List<String>, String)>[
    ([], 'missing-source'),
    (['--input=x', '--stdin'], 'conflicting-sources'),
    (['--stdin', '--file=private'], 'conflicting-sources'),
    (['--input=x', '--file=private'], 'conflicting-sources'),
    (['--stdin', '--unknown=private'], 'invalid-options'),
    (['--stdin', 'private'], 'invalid-options'),
    (['--stdin', '--output='], 'invalid-options'),
    (['--file='], 'invalid-options'),
    for (final mode in [
      '',
      'FULL',
      'Component',
      ' full',
      'component ',
      'private',
    ])
      (['--stdin', '--mode=$mode'], 'invalid-mode'),
  ]) {
    test(
      'GivenInvalidOptions${fixture.$1}_WhenParsed_ThenValidationPrecedesIo',
      () async {
        var reads = 0;
        final out = StringBuffer();
        final err = StringBuffer();
        expect(
          await runChimera(
            ['url', 'encode', ...fixture.$1, '--json'],
            localeTag: 'en',
            out: out,
            err: err,
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
        expect(reads, 0);
        expect(out.toString(), isEmpty);
        final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
        expect(error['code'], 'url-encode.${fixture.$2}');
        expect(error['kind'], 'validation');
        if (fixture.$2 == 'invalid-mode') {
          expect(error['location'], {
            'field': 'mode',
            'reason': 'unsupported-mode',
          });
        }
        expect(err.toString(), isNot(contains('private')));
      },
    );
  }
  for (final fixture in <(List<String>, List<int>, String)>[
    (['--input=private\uD800'], [], 'invalid-unicode'),
    (['--input=private\uDC00'], [], 'invalid-unicode'),
    (['--stdin'], [0xc0, 0xaf], 'invalid-utf8'),
    (['--file=private'], [0xed, 0xa0, 0x80], 'invalid-utf8'),
  ]) {
    test(
      'GivenMalformed${fixture.$3}${fixture.$1}_WhenEncoded_ThenRedactedValidationReturns',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        expect(
          await runChimera(
            ['url', 'encode', ...fixture.$1, '--json'],
            localeTag: 'en',
            out: out,
            err: err,
            readStandardInputBytes: () async => fixture.$2,
            readFileBytes: (_) async => fixture.$2,
          ),
          64,
        );
        expect(out.toString(), isEmpty);
        expect((jsonDecode(err.toString()) as Map)['error'], {
          'kind': 'validation',
          'code': 'url-encode.invalid-input',
          'message': 'The URL encoding request is invalid.',
          'location': {'field': 'input', 'reason': fixture.$3},
        });
        expect(err.toString(), isNot(contains('private')));
      },
    );
  }
  for (final locale in ['en', 'pt-BR']) {
    for (final boundary in ['stdin', 'file', 'save', 'json', 'stdout']) {
      for (final allocation in [false, true]) {
        test('Given$locale$boundary$allocation'
            '_WhenAccessFails_ThenSafeErrorWithNoSuccessReturns', () async {
          Object error() => allocation
              ? OutOfMemoryError()
              : StateError('private-input-output');
          final out = boundary == 'stdout'
              ? _DeniedSink(error())
              : StringBuffer();
          final err = StringBuffer();
          var saves = 0;
          final exit = await runChimera(
            [
              'url',
              'encode',
              if (boundary == 'stdin')
                '--stdin'
              else if (boundary == 'file')
                '--file=private'
              else
                '--input=private',
              if (boundary == 'save' || boundary == 'json') '--output=private',
              '--json',
            ],
            localeTag: locale,
            out: out,
            err: err,
            readStandardInputBytes: () async => throw error(),
            readFileBytes: (_) async => throw error(),
            writeOutputFile: (_, _) async {
              saves++;
              throw error();
            },
            urlEncodeJsonEncoder: boundary == 'json'
                ? (_) => throw error()
                : null,
          );
          expect(exit, allocation ? 75 : 74);
          if (out is StringBuffer) expect(out.toString(), isEmpty);
          expect(saves, boundary == 'save' ? 1 : 0);
          final result = (jsonDecode(err.toString()) as Map)['error'] as Map;
          expect(result['kind'], allocation ? 'resource' : 'access');
          expect(
            result['code'],
            allocation
                ? 'url-encode.resource-limit'
                : 'url-encode.${boundary == 'stdin'
                      ? 'input-access'
                      : boundary == 'file'
                      ? 'file-access'
                      : 'output-access'}',
          );
          expect(err.toString(), isNot(contains('private')));
        });
      }
    }
  }
  test('GivenServiceResourceFailure_WhenEncoded_ThenNoOutputIsSaved', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    var saves = 0;
    expect(
      await runChimera(
        ['url', 'encode', '--input=😀', '--output=private', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        urlEncodeService: const UrlEncodeService(
          encoder: UrlEncoder(maxOutputCharacters: 1),
        ),
        writeOutputFile: (_, _) async {
          saves++;
        },
      ),
      75,
    );
    expect(saves, 0);
    expect(out.toString(), isEmpty);
    final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
    expect(error['location'], {'field': 'encoded', 'reason': 'output-limit'});
  });
  for (final existing in [false, true]) {
    for (final boundary in ['stage', 'rename']) {
      test('GivenOutput$existing$boundary'
          '_WhenTransactionFails_ThenPriorStateAndNoArtifactsRemain', () async {
        final directory = await Directory.systemTemp.createTemp(
          'chimera-url-transaction-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/result.txt');
        if (existing) await target.writeAsString('prior');
        final out = StringBuffer();
        final err = StringBuffer();
        expect(
          await runChimera(
            [
              'url',
              'encode',
              '--input=private',
              '--output=${target.path}',
              '--json',
            ],
            localeTag: 'en',
            out: out,
            err: err,
            writeOutputStage: boundary == 'stage'
                ? (path, bytes) async {
                    await File(path).writeAsBytes([1]);
                    throw StateError('private');
                  }
                : null,
            outputFileOperations: TransactionalFileOperations(
              rename: boundary == 'rename'
                  ? (source, path) async {
                      if (source.path.contains('.chimera-stage-')) {
                        throw StateError('private');
                      }
                      await source.rename(path);
                    }
                  : null,
            ),
          ),
          74,
        );
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('private')));
        if (existing) {
          expect(await target.readAsString(), 'prior');
        } else {
          expect(await target.exists(), isFalse);
        }
        expect(await directory.list().length, existing ? 1 : 0);
      });
    }
  }
  test(
    'GivenExecutableStdinAndFile_WhenEncoded_ThenOfflineExactBytesReturn',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-url-process-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = File('${directory.path}/source.txt');
      await source.writeAsBytes([239, 187, 191, 97, 32, 47, 0]);
      final output = File('${directory.path}/out.txt');
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_cli/chimera_cli.dart'),
      );
      final entryPoint = library!.resolve('../bin/chimera.dart').toFilePath();
      final process = await Process.start(Platform.resolvedExecutable, [
        entryPoint,
        'url',
        'encode',
        '--stdin',
        '--json',
      ]);
      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      process.stdin.add(utf8.encode('a /ação'));
      await process.stdin.close();
      expect(await process.exitCode, 0);
      expect(
        await stdout,
        '{"encoded":"a%20%2Fa%C3%A7%C3%A3o","mode":"component"}\n',
      );
      expect(await stderr, '');
      final file = await Process.run(Platform.resolvedExecutable, [
        entryPoint,
        'url',
        'encode',
        '--file=${source.path}',
        '--output=${output.path}',
        '--json',
      ]);
      expect(file.exitCode, 0);
      expect(file.stderr, '');
      expect(await output.readAsString(), '%EF%BB%BFa%20%2F%00');
      expect(jsonDecode(file.stdout as String), {
        'encoded': '%EF%BB%BFa%20%2F%00',
        'mode': 'component',
      });
    },
  );
}

final class _DeniedSink implements StringSink {
  _DeniedSink(this.error);
  final Object error;
  @override
  void write(Object? object) => throw error;
  @override
  void writeln([Object? object = '']) => throw error;
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      throw error;
  @override
  void writeCharCode(int charCode) => throw error;
}
