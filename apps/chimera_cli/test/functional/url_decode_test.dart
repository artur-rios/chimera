import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('url decode', () {
    const source =
        '\uFEFF%26%3C%3E%22%27%27%C3%A9%F0%9F%98%80\r\n\u0000e\u0301';
    const expected = '\uFEFF&<>"\'\'é😀\r\n\u0000e\u0301';

    for (final locale in ['en', 'pt-BR']) {
      for (final sourceKind in ['direct', 'stdin', 'file']) {
        for (final json in [false, true]) {
          test('Given${locale}Source$sourceKind'
              '${json}_WhenUrlDecoded_ThenExactOutputReturns', () async {
            final out = StringBuffer();
            final err = StringBuffer();
            final exit = await runChimera(
              [
                'url',
                'decode',
                if (sourceKind == 'direct') ...['-i', source],
                if (sourceKind == 'stdin') '--stdin',
                if (sourceKind == 'file') ...['-f', 'private/path'],
                if (json) '--json',
              ],
              localeTag: locale,
              out: out,
              err: err,
              readStandardInputBytes: () async => utf8.encode(source),
              readFileBytes: (path) async {
                expect(path, 'private/path');
                return utf8.encode(source);
              },
              readStandardInput: () async => throw StateError('wrong reader'),
              readFile: (_) async => throw StateError('wrong reader'),
            );

            expect(exit, 0);
            expect(
              out.toString(),
              json ? '${jsonEncode({'decoded': expected})}\n' : expected,
            );
            expect(err.toString(), isEmpty);
          });
        }
      }

      for (final sourceKind in ['direct', 'stdin', 'file']) {
        test(
          'GivenEmpty$sourceKind${locale}_WhenUrlDecoded_ThenEmptyStdoutIsSuccess',
          () async {
            final out = StringBuffer();
            final err = StringBuffer();
            final exit = await runChimera(
              [
                'url',
                'decode',
                if (sourceKind == 'direct') '--input=',
                if (sourceKind == 'stdin') '--stdin',
                if (sourceKind == 'file') '--file=private/path',
              ],
              localeTag: locale,
              out: out,
              err: err,
              readStandardInputBytes: () async => <int>[],
              readFileBytes: (_) async => <int>[],
            );

            expect(exit, 0);
            expect(out.toString(), isEmpty);
            expect(err.toString(), isEmpty);
          },
        );
      }

      for (final json in [false, true]) {
        test('GivenUrlDecodeSave$json'
            '${locale}_WhenSaved_ThenExactUtf8WritesBeforeSuccess', () async {
          final out = StringBuffer();
          final err = StringBuffer();
          var saves = 0;
          final exit = await runChimera(
            [
              'url',
              'decode',
              '--input=%3Cé%3E\r\n',
              '--output=private/output',
              if (json) '--json',
            ],
            localeTag: locale,
            out: out,
            err: err,
            writeOutputFile: (path, bytes) async {
              expect(out.toString(), isEmpty);
              expect(path, 'private/output');
              expect(bytes, <int>[60, 195, 169, 62, 13, 10]);
              saves += 1;
            },
          );

          expect(exit, 0);
          expect(saves, 1);
          expect(
            out.toString(),
            json
                ? '{"decoded":"<é>\\r\\n"}\n'
                : locale == 'en'
                ? 'URL decoded text saved.\n'
                : 'Texto decodificado de URL salvo.\n',
          );
          expect(err.toString(), isEmpty);
        });
      }

      test(
        'GivenUrlDecodeHelp${locale}_WhenRequested_ThenLocalizedContractReturns',
        () async {
          final out = StringBuffer();
          final exit = await runChimera(
            ['--help', 'url', 'decode'],
            localeTag: locale,
            out: out,
            err: StringBuffer(),
          );

          expect(exit, 0);
          expect(
            out.toString(),
            locale == 'en'
                ? 'Usage: chimera url decode (--input=<text>|--stdin|--file=<path>) [--output=<path>] [--json]\nHuman stdout is exact text without a newline. Output saves UTF-8 text; JSON emits the result after saving. Exit codes: 64 validation, 74 access, 75 resource.\n'
                : 'Uso: chimera url decode (--input=<texto>|--stdin|--file=<caminho>) [--output=<caminho>] [--json]\nA saída de texto é exata, sem nova linha. O arquivo salva texto UTF-8; JSON emite o resultado após salvar. Códigos de saída: 64 validação, 74 acesso, 75 recursos.\n',
          );
        },
      );
    }

    for (final fixture in <(List<String>, String)>[
      (<String>[], 'missing-source'),
      (<String>['--input=', '--stdin'], 'conflicting-sources'),
      (<String>['--file=private/path', '--stdin'], 'conflicting-sources'),
      (<String>['--input=x', '--file=private/path'], 'conflicting-sources'),
      (<String>['--stdin', '--unknown=private'], 'invalid-options'),
      (<String>['--stdin', 'private'], 'invalid-options'),
      (<String>['--stdin', '--output='], 'invalid-options'),
      (<String>['--file='], 'invalid-options'),
    ]) {
      test(
        'GivenInvalidUrlDecode${fixture.$1}_WhenParsed_ThenValidationPrecedesIo',
        () async {
          var reads = 0;
          final out = StringBuffer();
          final err = StringBuffer();
          final exit = await runChimera(
            ['url', 'decode', ...fixture.$1, '--json'],
            localeTag: 'en',
            out: out,
            err: err,
            readStandardInputBytes: () async {
              reads += 1;
              return <int>[];
            },
            readFileBytes: (_) async {
              reads += 1;
              return <int>[];
            },
          );

          expect(exit, 64);
          expect(reads, 0);
          expect(out.toString(), isEmpty);
          final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
          expect(error['kind'], 'validation');
          expect(error['code'], 'url-decode.${fixture.$2}');
          expect(err.toString(), isNot(contains('private')));
        },
      );
    }

    for (final fixture in <(List<String>, List<int>, String, int)>[
      (<String>['--input=private-%'], <int>[], 'malformed-percent', 8),
      (<String>['--input=private-%GG'], <int>[], 'malformed-percent', 8),
      (<String>['--input=private-%C3%28'], <int>[], 'invalid-percent-utf8', 8),
      (
        <String>['--input=private-%ED%A0%80'],
        <int>[],
        'invalid-percent-utf8',
        8,
      ),
      (
        <String>['--input=private-%F4%90%80%80'],
        <int>[],
        'invalid-percent-utf8',
        8,
      ),
      (<String>['--stdin'], <int>[0x61, 0xc3, 0x28], 'invalid-utf8', 1),
      (
        <String>['--input=private-${String.fromCharCode(0xd800)}'],
        <int>[],
        'surrogate-scalar',
        8,
      ),
    ]) {
      test(
        'GivenMalformedUrlDecode${fixture.$3}_WhenExecuted_ThenRedactedValidationReturns',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          final exit = await runChimera(
            ['url', 'decode', ...fixture.$1, '--json'],
            localeTag: 'en',
            out: out,
            err: err,
            readStandardInputBytes: () async => fixture.$2,
          );

          expect(exit, 64);
          expect(out.toString(), isEmpty);
          expect((jsonDecode(err.toString()) as Map)['error'], {
            'kind': 'validation',
            'code': 'url-decode.malformed-input',
            'message': 'The URL decoding request is invalid.',
            'location': {
              'field': 'input',
              'reason': fixture.$3,
              'offset': fixture.$4,
            },
          });
          expect(err.toString(), isNot(contains('private')));
        },
      );
    }

    for (final sourceKind in ['stdin', 'file']) {
      for (final allocation in [false, true]) {
        test(
          'GivenUrlDecode$sourceKind${allocation}_WhenReadFails_ThenSafeFailureReturns',
          () async {
            Never fail() => allocation
                ? throw OutOfMemoryError()
                : throw StateError('private dependency private/path');
            final out = StringBuffer();
            final err = StringBuffer();
            final exit = await runChimera(
              [
                'url',
                'decode',
                sourceKind == 'stdin' ? '--stdin' : '--file=private/path',
                '--json',
              ],
              localeTag: 'en',
              out: out,
              err: err,
              readStandardInputBytes: () async => fail(),
              readFileBytes: (_) async => fail(),
            );

            expect(exit, allocation ? 75 : 74);
            expect(out.toString(), isEmpty);
            final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
            expect(error['kind'], allocation ? 'resource' : 'access');
            expect(
              error['code'],
              allocation
                  ? 'url-decode.resource-limit'
                  : 'url-decode.${sourceKind == 'stdin' ? 'input' : 'file'}-access',
            );
            if (allocation) {
              expect(error['location'], {
                'field': 'input',
                'reason': 'allocation-limit',
              });
            }
            expect(err.toString(), isNot(contains('private')));
          },
        );
      }
    }

    for (final fixture in <(UrlDecoder, String, String)>[
      (const UrlDecoder(maxInputCharacters: 1), 'input', 'input-limit'),
      (const UrlDecoder(maxOutputCharacters: 1), 'decoded', 'output-limit'),
      (
        UrlDecoder.forTesting(convert: (_) => throw OutOfMemoryError()),
        'decoded',
        'allocation-limit',
      ),
    ]) {
      test(
        'GivenUrlDecodeService${fixture.$3}_WhenExecuted_ThenNoSaveReturns',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          var saves = 0;
          final exit = await runChimera(
            [
              'url',
              'decode',
              '--input=private-source-marker',
              '--output=private/path',
              '--json',
            ],
            localeTag: 'en',
            out: out,
            err: err,
            urlDecodeService: UrlDecodeService(decoder: fixture.$1),
            writeOutputFile: (_, _) async => saves += 1,
          );

          expect(exit, 75);
          expect(saves, 0);
          expect(out.toString(), isEmpty);
          expect((jsonDecode(err.toString()) as Map)['error'], {
            'kind': 'resource',
            'code': 'url-decode.resource-limit',
            'message': 'URL decoding exceeded its resource limit.',
            'location': {'field': fixture.$2, 'reason': fixture.$3},
          });
        },
      );
    }

    for (final boundary in ['writer', 'json', 'stdout']) {
      for (final allocation in [false, true]) {
        test('GivenUrlDecodeOutput$boundary'
            '${allocation}_WhenDenied_ThenNoSuccessReturns', () async {
          Never fail() => allocation
              ? throw OutOfMemoryError()
              : throw StateError('private dependency private/path');
          final deniedOut = boundary == 'stdout'
              ? allocation
                    ? _OutOfMemoryStringSink()
                    : _UrlDeniedStringSink(
                        StateError('private dependency private/path'),
                      )
              : null;
          final out = deniedOut ?? StringBuffer();
          final err = StringBuffer();
          var saves = 0;
          final exit = await runChimera(
            [
              'url',
              'decode',
              '--input=%3Cprivate%3E',
              if (boundary == 'writer') '--output=private/output',
              '--json',
            ],
            localeTag: 'en',
            out: out,
            err: err,
            urlDecodeJsonEncoder: boundary == 'json' ? (_) => fail() : null,
            writeOutputFile: (_, _) async {
              saves += 1;
              fail();
            },
          );

          expect(exit, allocation ? 75 : 74);
          expect(saves, boundary == 'writer' ? 1 : 0);
          if (out case final _OutOfMemoryStringSink sink) {
            expect(sink.contents, isEmpty);
          } else if (out case final _UrlDeniedStringSink sink) {
            expect(sink.emissionCalls, 1);
          } else {
            expect(out.toString(), isEmpty);
          }
          final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
          expect(error['kind'], allocation ? 'resource' : 'access');
          expect(
            error['code'],
            allocation
                ? 'url-decode.resource-limit'
                : 'url-decode.output-access',
          );
          expect(err.toString(), isNot(contains('private')));
        });
      }
    }

    for (final failure in ['reserve', 'partial', 'replace', 'restore']) {
      test(
        'GivenUrlDecodeTransaction${failure}_WhenSaveFails_ThenPriorStateRemains',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'chimera-url-decode-transaction-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final target = File('${directory.path}/private.txt');
          await target.writeAsBytes(<int>[7, 8, 9], flush: true);
          final out = StringBuffer();
          final err = StringBuffer();
          var triggered = false;
          var restoreFailed = false;
          Never fail() => throw const FileSystemException(
            'private dependency',
            'private/path',
          );

          final exit = await runChimera(
            [
              'url',
              'decode',
              '--input=%3Cprivate%3E',
              '--output=${target.path}',
              '--json',
            ],
            localeTag: 'en',
            out: out,
            err: err,
            writeOutputStage: failure == 'partial'
                ? (path, bytes) async {
                    await File(path).writeAsBytes(<int>[bytes.first]);
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
              copy: (source, destination) => source.copy(destination.path),
              rename: (source, path) async {
                if (['replace', 'restore'].contains(failure) &&
                    source.path.contains('.chimera-stage-')) {
                  triggered = true;
                  fail();
                }
                if (failure == 'restore' &&
                    !restoreFailed &&
                    source.path.contains('.chimera-backup-')) {
                  restoreFailed = true;
                  fail();
                }
                await source.rename(path);
              },
              delete: (file) => file.delete(),
            ),
          );

          expect(triggered, isTrue);
          if (failure == 'restore') expect(restoreFailed, isTrue);
          expect(exit, 74);
          expect(out.toString(), isEmpty);
          expect(await target.readAsBytes(), <int>[7, 8, 9]);
          expect(await _chimeraTransactionArtifacts(directory), isEmpty);
          expect(err.toString(), isNot(contains('private')));
        },
      );
    }
  });
}

final class _OutOfMemoryStringSink implements StringSink {
  var emissionCalls = 0;
  final StringBuffer _contents = StringBuffer();

  String get contents => _contents.toString();

  Never _fail() {
    emissionCalls++;
    throw OutOfMemoryError();
  }

  @override
  void write(Object? object) => _fail();

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _fail();

  @override
  void writeCharCode(int charCode) => _fail();

  @override
  void writeln([Object? object = '']) => _fail();
}

final class _UrlDeniedStringSink implements StringSink {
  _UrlDeniedStringSink(this.error);

  final Object error;
  var emissionCalls = 0;

  Never _fail() {
    emissionCalls++;
    throw error;
  }

  @override
  void write(Object? object) => _fail();
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _fail();
  @override
  void writeCharCode(int charCode) => _fail();
  @override
  void writeln([Object? object = '']) => _fail();
}

Future<List<File>> _chimeraTransactionArtifacts(Directory directory) async =>
    directory
        .list()
        .where(
          (entry) => entry.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('.chimera-'),
        )
        .map((entry) => File(entry.path))
        .toList();
