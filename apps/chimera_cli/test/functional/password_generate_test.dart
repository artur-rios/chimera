import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  PasswordService deterministic() => PasswordService(
    generator: PasswordGenerator.forTesting(randomInt: (_) => 0),
  );

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
        'password': '0000',
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
