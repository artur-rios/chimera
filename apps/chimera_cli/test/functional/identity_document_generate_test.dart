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
    test('Given${locale}Help_WhenRequested_ThenLocalizedContract', () async {
      final out = StringBuffer(), err = StringBuffer();
      final code = await runChimera(
        ['document', 'generate', '--help'],
        localeTag: locale,
        out: out,
        err: err,
        identityDocumentService: IdentityDocumentService(
          generator: IdentityDocumentGenerator.forTesting(
            candidate: (_, _, _) => throw StateError('must not generate'),
          ),
        ),
      );

      expect(code, 0);
      expect(
        out.toString(),
        '${const MessageCatalog().lookup(locale, 'cli.documentUsage')}\n',
      );
      expect(err.toString(), isEmpty);
    });
  }

  test('GivenDefaults_WhenGenerated_ThenLabeledSsnReturns', () async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runChimera(
      ['document', 'generate'],
      localeTag: 'en',
      out: out,
      err: err,
      identityDocumentService: _service('219099999'),
    );

    expect(code, 0);
    expect(
      out.toString(),
      'Synthetic identity test data - not proof of issuance\n219-09-9999',
    );
    expect(err.toString(), isEmpty);
  });

  final cases = <String, (List<String>, String)>{
    'ssn': (['--locale=us', '--type=ssn'], '219099999'),
    'itin': (['--locale=us', '--type=itin'], '900700000'),
    'ein': (['--locale=us', '--type=ein'], '200000000'),
    'cpf': (['--locale=br', '--type=cpf'], '28001238938'),
    'cnpjNumeric': (
      ['--locale=br', '--type=cnpj', '--cnpj-format=numeric'],
      '11222333000181',
    ),
    'cnpjAlphanumeric': (
      ['--locale=br', '--type=cnpj', '--cnpj-format=alphanumeric'],
      '12ABC34501DE35',
    ),
    'cnh': (['--locale=br', '--type=cnh'], '02650306461'),
    'cin': (['--locale=br', '--type=cin'], '28001238938'),
  };

  for (final entry in cases.entries) {
    test(
      'Given${entry.key}Json_WhenGenerated_ThenStableLabeledResult',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['document', 'generate', ...entry.value.$1, '--count=2', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          identityDocumentService: _service(entry.value.$2),
        );

        expect(code, 0);
        final json = jsonDecode(out.toString()) as Map<String, Object?>;
        expect(json['count'], 2);
        expect(json['synthetic'], isTrue);
        expect(json['label'], 'synthetic-test-data');
        expect(json['values'], hasLength(2));
        expect(err.toString(), isEmpty);
      },
    );
  }

  final invalidCases = <String, List<String>>{
    'locale': ['--locale=ca'],
    'type': ['--type=passport'],
    'mismatch': ['--locale=us', '--type=cpf'],
    'rg': ['--locale=br', '--type=rg'],
    'format': ['--locale=br', '--type=cnpj', '--cnpj-format=legacy'],
    'formatApplicability': [
      '--locale=br',
      '--type=cpf',
      '--cnpj-format=numeric',
    ],
    'count': ['--count=0'],
    'rest': ['PRIVATE'],
    'emptyOutput': ['--output='],
  };
  for (final entry in invalidCases.entries) {
    test(
      'GivenInvalid${entry.key}_WhenGenerated_ThenExit64WithoutValue',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['document', 'generate', ...entry.value, '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          identityDocumentService: _service('219099999'),
        );

        expect(code, 64);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('219-09-9999')));
        expect(err.toString(), isNot(contains('PRIVATE')));
        final error =
            (jsonDecode(err.toString()) as Map<String, Object?>)['error']
                as Map<String, Object?>;
        expect(error['kind'], 'validation');
        if (entry.key == 'rg') {
          expect(error['code'], 'document.rg-jurisdiction-required');
        }
      },
    );
  }

  test(
    'GivenValidFirstThenExhaustion_WhenGenerated_ThenNoPartialValue',
    () async {
      var attempts = 0;
      final out = StringBuffer(), err = StringBuffer();
      final code = await runChimera(
        ['document', 'generate', '--count=2', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        identityDocumentService: IdentityDocumentService(
          generator: IdentityDocumentGenerator.forTesting(
            candidate: (_, _, _) =>
                ++attempts == 1 ? '219099999' : 'PRIVATE INVALID',
          ),
        ),
      );

      expect(attempts, 33);
      expect(code, 70);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('219-09-9999')));
      expect(err.toString(), isNot(contains('PRIVATE')));
      final error =
          (jsonDecode(err.toString()) as Map<String, Object?>)['error']
              as Map<String, Object?>;
      expect(error['code'], 'document.generation-failed');
    },
  );

  test(
    'GivenOutputPath_WhenGenerated_ThenExactLabeledBatchAndNotice',
    () async {
      final out = StringBuffer(), err = StringBuffer();
      List<int>? written;
      final code = await runChimera(
        [
          'document',
          'generate',
          '--locale=br',
          '--type=cpf',
          '--count=2',
          '--output=result.txt',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        identityDocumentService: _service('28001238938'),
        writeOutputFile: (path, bytes) async {
          expect(path, 'result.txt');
          written = bytes;
        },
      );

      expect(code, 0);
      expect(err.toString(), isEmpty);
      expect(
        utf8.decode(written!),
        'Dados sintéticos de identidade - não comprovam emissão oficial\n'
        '280.012.389-38\n280.012.389-38',
      );
      expect(
        out.toString(),
        '${const MessageCatalog().lookup('pt-BR', 'document.saved')}\n',
      );
    },
  );

  test('GivenOutputWriterFailure_WhenGenerated_Then74WithoutValue', () async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runChimera(
      ['document', 'generate', '--output=PRIVATE', '--json'],
      localeTag: 'en',
      out: out,
      err: err,
      identityDocumentService: _service('219099999'),
      writeOutputFile: (_, _) async =>
          throw const FileSystemException('PRIVATE'),
    );

    expect(code, 74);
    expect(out.toString(), isEmpty);
    expect(err.toString(), isNot(contains('PRIVATE')));
    expect(err.toString(), isNot(contains('219-09-9999')));
  });

  test('GivenStdoutFailure_WhenGenerated_Then74WithoutValue', () async {
    final err = StringBuffer();
    final code = await runChimera(
      ['document', 'generate'],
      localeTag: 'en',
      out: const _DeniedSink(),
      err: err,
      identityDocumentService: _service('219099999'),
    );

    expect(code, 74);
    expect(err.toString(), isNot(contains('219-09-9999')));
  });

  for (final resource in [false, true]) {
    test(
      'Given${resource}SerializationFailure_WhenJsonRequested_ThenTypedFailure',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['document', 'generate', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          identityDocumentService: _service('219099999'),
          identityDocumentJsonEncoder: (_) {
            if (resource) throw OutOfMemoryError();
            throw StateError('PRIVATE');
          },
        );

        expect(code, resource ? 75 : 74);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('PRIVATE')));
        expect(err.toString(), isNot(contains('219-09-9999')));
      },
    );
  }

  test('GivenNativeExecutable_WhenDocumentCommandRuns_ThenProductionContractHolds', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-document-executable-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final library = (await Isolate.resolvePackageUri(
      Uri.parse('package:chimera_cli/chimera_cli.dart'),
    ))!;
    final entrypoint = File.fromUri(library.resolve('../bin/chimera.dart'));
    final executable =
        '${directory.path}/chimera-document${Platform.isWindows ? '.exe' : ''}';
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      entrypoint.path,
      '-o',
      executable,
    ]);
    expect(compilation.exitCode, 0, reason: compilation.stderr.toString());

    final result = await Process.run(executable, [
      'document',
      'generate',
      '--locale=br',
      '--type=cnpj',
      '--count=2',
      '--json',
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final json = jsonDecode(result.stdout.toString()) as Map<String, Object?>;
    expect(json['locale'], 'br');
    expect(json['type'], 'cnpj');
    expect(json['cnpjFormat'], 'alphanumeric');
    expect(json['synthetic'], isTrue);
    expect(json['label'], 'synthetic-test-data');
    expect(json['values'], hasLength(2));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

IdentityDocumentService _service(String value) => IdentityDocumentService(
  generator: IdentityDocumentGenerator.forTesting(
    candidate: (_, _, _) => value,
  ),
);

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
