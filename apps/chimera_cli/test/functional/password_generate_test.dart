import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  PasswordService deterministic() =>
      PasswordService(generator: _coveringGenerator());

  for (final locale in ['en', 'pt-BR']) {
    test(
      'Given${locale}Help_WhenRequested_ThenLocalizedContractReturnsWithoutEntropy',
      () async {
        final out = StringBuffer(), err = StringBuffer();

        final code = await runChimera(
          ['password', 'generate', '--help'],
          localeTag: locale,
          out: out,
          err: err,
          passwordService: PasswordService(
            generator: PasswordGenerator.forTesting(
              randomInt: (_) => throw StateError('must not request entropy'),
            ),
          ),
        );

        expect(code, 0);
        expect(
          out.toString(),
          '${const MessageCatalog().lookup(locale, 'cli.passwordUsage')}\n',
        );
        expect(err.toString(), isEmpty);
      },
    );
  }

  test(
    'GivenDefaults_WhenGenerated_ThenHumanPasswordSatisfiesEveryClass',
    () async {
      final out = StringBuffer(), err = StringBuffer();

      final code = await runChimera(
        ['password', 'generate'],
        localeTag: 'en',
        out: out,
        err: err,
        passwordService: deterministic(),
      );

      expect(code, 0);
      expect(err.toString(), isEmpty);
      expect(out.length, 16);
      expect(out.toString(), matches(RegExp('[a-z]')));
      expect(out.toString(), matches(RegExp('[A-Z]')));
      expect(out.toString(), matches(RegExp('[0-9]')));
      expect(out.toString(), matches(RegExp(r'[!@#$%^&*()\-_=+\[\]{}:,.?]')));
    },
  );

  test(
    'GivenOnlyDigitsAndJson_WhenGenerated_ThenStableMachineResult',
    () async {
      final out = StringBuffer(), err = StringBuffer();

      final code = await runChimera(
        [
          'password',
          'generate',
          '--length=4',
          '--no-lowercase',
          '--no-uppercase',
          '--no-symbols',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        passwordService: deterministic(),
      );

      expect(code, 0);
      expect(err.toString(), isEmpty);
      expect(jsonDecode(out.toString()), {
        'length': 4,
        'characterClasses': ['digits'],
        'password': '0622',
      });
    },
  );

  for (final locale in ['en', 'pt-BR']) {
    for (final args in [
      ['--length=0'],
      ['--length=3'],
      ['--no-lowercase', '--no-uppercase', '--no-digits', '--no-symbols'],
      ['unexpected'],
    ]) {
      test(
        'Given$locale${args}_WhenInvalid_Then64AndLocalizedFailure',
        () async {
          final out = StringBuffer(), err = StringBuffer();

          final code = await runChimera(
            ['password', 'generate', ...args],
            localeTag: locale,
            out: out,
            err: err,
            passwordService: deterministic(),
          );

          expect(code, 64);
          expect(out.toString(), isEmpty);
          expect(
            err.toString(),
            contains(
              const MessageCatalog().lookup(
                locale,
                'error.password.validation',
              ),
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
        ['password', 'generate', '--private', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(code, 64);
      expect(out.toString(), isEmpty);
      final error =
          (jsonDecode(err.toString()) as Map<String, Object?>)['error']
              as Map<String, Object?>;
      expect(error['code'], 'password.invalid-options');
      expect(error['kind'], 'validation');
    },
  );

  test(
    'GivenEntropyFailure_WhenGenerated_Then70WithoutSecretDiagnostic',
    () async {
      final out = StringBuffer(), err = StringBuffer();

      final code = await runChimera(
        ['password', 'generate', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        passwordService: PasswordService(
          generator: PasswordGenerator.forTesting(
            randomInt: (_) => throw StateError('PRIVATE PASSWORD MATERIAL'),
          ),
        ),
      );

      expect(code, 70);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('password.random-unavailable'));
      expect(err.toString(), isNot(contains('PRIVATE')));
    },
  );

  test(
    'GivenOutputPath_WhenGenerated_ThenExactBytesAndLocalizedNotice',
    () async {
      final out = StringBuffer(), err = StringBuffer();
      List<int>? written;

      final code = await runChimera(
        ['password', 'generate', '--output=result.txt'],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        passwordService: deterministic(),
        writeOutputFile: (path, bytes) async {
          expect(path, 'result.txt');
          written = bytes;
        },
      );

      expect(code, 0);
      expect(err.toString(), isEmpty);
      expect(utf8.decode(written!), hasLength(16));
      expect(
        out.toString(),
        '${const MessageCatalog().lookup('pt-BR', 'password.saved')}\n',
      );
    },
  );

  test('GivenExistingOutput_WhenGenerated_ThenTransactionalReplaceLeavesNoArtifacts', () async {
    final directory = await Directory.systemTemp.createTemp('password-');
    addTearDown(() => directory.delete(recursive: true));
    final target = File('${directory.path}/result.txt');
    await target.writeAsString('previous');
    final out = StringBuffer(), err = StringBuffer();

    final code = await runChimera(
      ['password', 'generate', '--output=${target.path}'],
      localeTag: 'en',
      out: out,
      err: err,
      passwordService: deterministic(),
    );

    expect(code, 0);
    expect(err.toString(), isEmpty);
    expect(await target.readAsBytes(), hasLength(16));
    expect(
      out.toString(),
      '${const MessageCatalog().lookup('en', 'password.saved')}\n',
    );
    expect(await directory.list().toList(), [isA<File>()]);
  });

  test(
    'GivenOutputWriterFailure_WhenGenerated_Then74WithoutSecretDiagnostic',
    () async {
      final out = StringBuffer(), err = StringBuffer();

      final code = await runChimera(
        ['password', 'generate', '--output=PRIVATE', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        passwordService: deterministic(),
        writeOutputFile: (_, _) async =>
            throw const FileSystemException('PRIVATE'),
      );

      expect(code, 74);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('PRIVATE')));
      expect(
        (jsonDecode(err.toString()) as Map<String, Object?>)['error'],
        containsPair('kind', 'access'),
      );
    },
  );

  test(
    'GivenStdoutFailure_WhenGenerated_Then74WithoutPasswordDiagnostic',
    () async {
      final err = StringBuffer();

      final code = await runChimera(
        ['password', 'generate'],
        localeTag: 'en',
        out: const _DeniedSink(),
        err: err,
        passwordService: deterministic(),
      );

      expect(code, 74);
      expect(err.toString(), isNot(contains('PRIVATE')));
      expect(
        err.toString(),
        contains(
          const MessageCatalog().lookup('en', 'error.password.outputAccess'),
        ),
      );
    },
  );

  for (final resource in [false, true]) {
    test(
      'Given${resource}SerializationFailure_WhenJsonRequested_ThenTypedFailure',
      () async {
        final out = StringBuffer(), err = StringBuffer();

        final code = await runChimera(
          ['password', 'generate', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          passwordService: deterministic(),
          passwordJsonEncoder: (_) {
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

  test('GivenNativeExecutable_WhenPasswordCommandsRun_ThenProductionEntropyAndOutputContractsHold', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-password-executable-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final library = (await Isolate.resolvePackageUri(
      Uri.parse('package:chimera_cli/chimera_cli.dart'),
    ))!;
    final entrypoint = File.fromUri(library.resolve('../bin/chimera.dart'));
    final executable =
        '${directory.path}/chimera-password${Platform.isWindows ? '.exe' : ''}';
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      entrypoint.path,
      '-o',
      executable,
    ]);
    expect(compilation.exitCode, 0, reason: compilation.stderr.toString());

    final defaults = await Process.run(executable, ['password', 'generate']);
    expect(defaults.exitCode, 0, reason: defaults.stderr.toString());
    expect(defaults.stderr, isEmpty);
    final defaultPassword = defaults.stdout.toString();
    expect(defaultPassword, hasLength(16));
    expect(defaultPassword, matches(RegExp('[a-z]')));
    expect(defaultPassword, matches(RegExp('[A-Z]')));
    expect(defaultPassword, matches(RegExp('[0-9]')));
    expect(defaultPassword, matches(RegExp(r'[!@#$%^&*()\-_=+\[\]{}:,.?]')));

    final jsonResult = await Process.run(executable, [
      'password',
      'generate',
      '--length=8',
      '--no-lowercase',
      '--no-uppercase',
      '--no-symbols',
      '--json',
    ]);
    expect(jsonResult.exitCode, 0, reason: jsonResult.stderr.toString());
    final json = jsonDecode(jsonResult.stdout.toString());
    expect(json, {
      'length': 8,
      'characterClasses': ['digits'],
      'password': (json as Map<String, Object?>)['password'],
    });
    expect(json['password'], matches(RegExp(r'^\d{8}$')));

    final invalid = await Process.run(executable, [
      'password',
      'generate',
      '--length=0',
    ]);
    expect(invalid.exitCode, 64);
    expect(invalid.stdout, isEmpty);
    expect(
      invalid.stderr.toString(),
      contains(
        const MessageCatalog().lookup('en', 'error.password.validation'),
      ),
    );

    final saved = File('${directory.path}/result.txt');
    await saved.writeAsString('previous');
    final saveResult = await Process.run(executable, [
      'password',
      'generate',
      '--length=8',
      '--no-lowercase',
      '--no-uppercase',
      '--no-symbols',
      '--output=${saved.path}',
    ]);
    expect(saveResult.exitCode, 0, reason: saveResult.stderr.toString());
    expect(saveResult.stderr, isEmpty);
    expect(await saved.readAsString(), matches(RegExp(r'^\d{8}$')));
    final remainingNames = directory
        .listSync()
        .map((entry) => entry.uri.pathSegments.last)
        .toList();
    expect(
      remainingNames,
      unorderedEquals([
        File(executable).uri.pathSegments.last,
        'result.txt',
      ]),
    );
    expect(
      remainingNames.where(
        (name) =>
            name.startsWith('.chimera-stage-') ||
            name.startsWith('.chimera-backup-'),
      ),
      isEmpty,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

PasswordGenerator _coveringGenerator() {
  const draws = <int>[0, 26, 52, 62];
  var index = 0;
  return PasswordGenerator.forTesting(
    randomInt: (upperBound) => draws[index++ % draws.length] % upperBound,
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
