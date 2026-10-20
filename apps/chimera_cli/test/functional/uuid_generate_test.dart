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
    test(
      'Given${locale}Help_WhenRequested_ThenLocalizedContractWithoutGeneration',
      () async {
        final out = StringBuffer(), err = StringBuffer();

        final code = await runChimera(
          ['uuid', 'generate', '--help'],
          localeTag: locale,
          out: out,
          err: err,
          uuidService: UuidService(
            generator: UuidGenerator.forTesting(
              randomBytes: () => throw StateError('must not generate'),
              nowMilliseconds: () => throw StateError('must not read time'),
            ),
          ),
        );

        expect(code, 0);
        expect(
          out.toString(),
          '${const MessageCatalog().lookup(locale, 'cli.uuidUsage')}\n',
        );
        expect(err.toString(), isEmpty);
      },
    );
  }

  test('GivenDefaults_WhenGenerated_ThenCanonicalV4Returns', () async {
    final out = StringBuffer(), err = StringBuffer();

    final code = await runChimera(
      ['uuid', 'generate'],
      localeTag: 'en',
      out: out,
      err: err,
      uuidService: _deterministicService(),
    );

    expect(code, 0);
    expect(out.toString(), '00000000-0000-4000-8000-000000000000');
    expect(err.toString(), isEmpty);
  });

  test(
    'GivenV7GuidCountTwoAndJson_WhenGenerated_ThenStableMachineResult',
    () async {
      final out = StringBuffer(), err = StringBuffer();

      final code = await runChimera(
        [
          'uuid',
          'generate',
          '--version=v7',
          '--representation=guid',
          '--count=2',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        uuidService: _deterministicService(),
      );

      expect(code, 0);
      expect(err.toString(), isEmpty);
      expect(jsonDecode(out.toString()), {
        'version': 'v7',
        'representation': 'guid',
        'count': 2,
        'values': [
          '{01234567-89AB-7000-8000-000000000000}',
          '{01234567-89AB-7101-8101-010101010101}',
        ],
      });
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    for (final args in [
      ['--version=v1'],
      ['--representation=urn'],
      ['--count=0'],
      ['unexpected'],
    ]) {
      test(
        'Given$locale${args}_WhenInvalid_Then64AndLocalizedFailure',
        () async {
          final out = StringBuffer(), err = StringBuffer();

          final code = await runChimera(
            ['uuid', 'generate', ...args],
            localeTag: locale,
            out: out,
            err: err,
            uuidService: _deterministicService(),
          );

          expect(code, 64);
          expect(out.toString(), isEmpty);
          expect(
            err.toString(),
            contains(
              const MessageCatalog().lookup(locale, 'error.uuid.validation'),
            ),
          );
        },
      );
    }
  }

  test(
    'GivenUnknownOptionAndJson_WhenParsed_ThenStableValidationJson',
    () async {
      final out = StringBuffer(), err = StringBuffer();

      final code = await runChimera(
        ['uuid', 'generate', '--private', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(code, 64);
      expect(out.toString(), isEmpty);
      final error =
          (jsonDecode(err.toString()) as Map<String, Object?>)['error']
              as Map<String, Object?>;
      expect(error['code'], 'uuid.invalid-options');
      expect(error['kind'], 'validation');
    },
  );

  test(
    'GivenEntropyFailure_WhenGenerated_Then70WithoutSecretDiagnostic',
    () async {
      final out = StringBuffer(), err = StringBuffer();

      final code = await runChimera(
        ['uuid', 'generate', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        uuidService: UuidService(
          generator: UuidGenerator.forTesting(
            randomBytes: () => throw StateError('PRIVATE IDENTIFIER'),
            nowMilliseconds: () => 0,
          ),
        ),
      );

      expect(code, 70);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('uuid.random-unavailable'));
      expect(err.toString(), isNot(contains('PRIVATE')));
    },
  );

  test(
    'GivenV7ClockFailureMidBatch_WhenGenerated_Then70WithoutPartialOutput',
    () async {
      final out = StringBuffer(), err = StringBuffer();
      var randomCall = 0;
      var clockCall = 0;

      final code = await runChimera(
        ['uuid', 'generate', '--version=v7', '--count=2', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        uuidService: UuidService(
          generator: UuidGenerator.forTesting(
            randomBytes: () => List<int>.filled(16, randomCall++),
            nowMilliseconds: () {
              if (clockCall++ == 1) throw StateError('PRIVATE TIME');
              return 0x0123456789ab;
            },
          ),
        ),
      );

      expect(code, 70);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('uuid.time-unavailable'));
      expect(err.toString(), isNot(contains('PRIVATE')));
    },
  );

  test(
    'GivenOutputPath_WhenGenerated_ThenExactBatchAndLocalizedNotice',
    () async {
      final out = StringBuffer(), err = StringBuffer();
      List<int>? written;

      final code = await runChimera(
        ['uuid', 'generate', '--count=2', '--output=result.txt'],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        uuidService: _deterministicService(),
        writeOutputFile: (path, bytes) async {
          expect(path, 'result.txt');
          written = bytes;
        },
      );

      expect(code, 0);
      expect(err.toString(), isEmpty);
      expect(
        utf8.decode(written!),
        '00000000-0000-4000-8000-000000000000\n01010101-0101-4101-8101-010101010101',
      );
      expect(
        out.toString(),
        '${const MessageCatalog().lookup('pt-BR', 'uuid.saved')}\n',
      );
    },
  );

  test(
    'GivenOutputWriterFailure_WhenGenerated_Then74WithoutSecretDiagnostic',
    () async {
      final out = StringBuffer(), err = StringBuffer();

      final code = await runChimera(
        ['uuid', 'generate', '--output=PRIVATE', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        uuidService: _deterministicService(),
        writeOutputFile: (_, _) async =>
            throw const FileSystemException('PRIVATE'),
      );

      expect(code, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('PRIVATE')));
    },
  );

  test(
    'GivenStdoutFailure_WhenGenerated_Then74WithoutIdentifierDiagnostic',
    () async {
      final err = StringBuffer();

      final code = await runChimera(
        ['uuid', 'generate'],
        localeTag: 'en',
        out: const _DeniedSink(),
        err: err,
        uuidService: _deterministicService(),
      );

      expect(code, 74);
      expect(
        err.toString(),
        contains(
          const MessageCatalog().lookup('en', 'error.uuid.outputAccess'),
        ),
      );
      expect(err.toString(), isNot(contains('PRIVATE')));
    },
  );

  for (final resource in [false, true]) {
    test(
      'Given${resource}SerializationFailure_WhenJsonRequested_ThenTypedFailure',
      () async {
        final out = StringBuffer(), err = StringBuffer();

        final code = await runChimera(
          ['uuid', 'generate', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          uuidService: _deterministicService(),
          uuidJsonEncoder: (_) {
            if (resource) throw OutOfMemoryError();
            throw StateError('PRIVATE');
          },
        );

        expect(code, resource ? 75 : 74);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('PRIVATE')));
      },
    );
  }

  test(
    'GivenNativeExecutable_WhenUuidCommandsRun_ThenProductionContractsHold',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-uuid-executable-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final library = (await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_cli/chimera_cli.dart'),
      ))!;
      final entrypoint = File.fromUri(library.resolve('../bin/chimera.dart'));
      final executable =
          '${directory.path}/chimera-uuid${Platform.isWindows ? '.exe' : ''}';
      final compilation = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        entrypoint.path,
        '-o',
        executable,
      ]);
      expect(compilation.exitCode, 0, reason: compilation.stderr.toString());

      final defaults = await Process.run(executable, ['uuid', 'generate']);
      expect(defaults.exitCode, 0, reason: defaults.stderr.toString());
      expect(defaults.stderr, isEmpty);
      expect(
        defaults.stdout.toString(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );

      final jsonResult = await Process.run(executable, [
        'uuid',
        'generate',
        '--version=v7',
        '--representation=guid',
        '--count=2',
        '--json',
      ]);
      expect(jsonResult.exitCode, 0, reason: jsonResult.stderr.toString());
      final json =
          jsonDecode(jsonResult.stdout.toString()) as Map<String, Object?>;
      expect(json['version'], 'v7');
      expect(json['representation'], 'guid');
      expect((json['values'] as List<Object?>).toSet(), hasLength(2));

      final saved = File('${directory.path}/result.txt');
      await saved.writeAsString('previous');
      final saveResult = await Process.run(executable, [
        'uuid',
        'generate',
        '--count=2',
        '--output=${saved.path}',
      ]);
      expect(saveResult.exitCode, 0, reason: saveResult.stderr.toString());
      expect((await saved.readAsLines()).toSet(), hasLength(2));
      final remainingNames = directory
          .listSync()
          .map((entry) => entry.uri.pathSegments.last)
          .toList();
      expect(
        remainingNames,
        unorderedEquals([File(executable).uri.pathSegments.last, 'result.txt']),
      );
      expect(
        remainingNames.where(
          (name) =>
              name.startsWith('.chimera-stage-') ||
              name.startsWith('.chimera-backup-'),
        ),
        isEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

UuidService _deterministicService() {
  var call = 0;
  return UuidService(
    generator: UuidGenerator.forTesting(
      randomBytes: () => List<int>.filled(16, call++),
      nowMilliseconds: () => 0x0123456789ab,
    ),
  );
}

final class _DeniedSink implements StringSink {
  const _DeniedSink();

  Never _fail() => throw StateError('PRIVATE stdout failure');

  @override
  void write(Object? object) => _fail();
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) => _fail();
  @override
  void writeCharCode(int charCode) => _fail();
  @override
  void writeln([Object? object = '']) => _fail();
}
