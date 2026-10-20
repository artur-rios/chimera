import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_l10n/chimera_l10n.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final today = DateTime.utc(2026, 10, 20);

  for (final locale in ['en', 'pt-BR']) {
    test('Given${locale}Help_WhenRequested_ThenLocalizedContract', () async {
      final out = StringBuffer(), err = StringBuffer();
      final code = await runChimera(
        ['person', 'generate', '--help'],
        localeTag: locale,
        out: out,
        err: err,
        personService: PersonService(
          generator: PersonGenerator.forTesting(
            candidate: (_, _) => throw StateError('must not generate'),
            today: () => today,
          ),
        ),
      );

      expect(code, 0);
      expect(
        out.toString(),
        '${const MessageCatalog().lookup(locale, 'cli.personUsage')}\n',
      );
      expect(err.toString(), isEmpty);
    });
  }

  test('GivenDefaults_WhenGenerated_ThenLabeledUsPersonReturns', () async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runChimera(
      ['person', 'generate'],
      localeTag: 'en',
      out: out,
      err: err,
      personService: _service(_usPerson(), today),
    );

    expect(code, 0);
    expect(out.toString(), contains('Synthetic person test data'));
    expect(out.toString(), contains('Name: Avery Reed'));
    expect(out.toString(), contains('Birth date: 1990-06-15'));
    expect(out.toString(), contains('100 Example Avenue'));
    expect(out.toString(), contains('+1 (415) 555-0100'));
    expect(out.toString(), contains('avery.reed01@example.com'));
    expect(out.toString(), contains('SSN: 219-09-9999'));
    expect(err.toString(), isEmpty);
  });

  for (final entry in <String, (List<String>, SyntheticPerson)>{
    'Us': (['--locale=us', '--min-age=18', '--max-age=90'], _usPerson()),
    'Brazil': (['--locale=br', '--min-age=21', '--max-age=40'], _brPerson()),
  }.entries) {
    test(
      'Given${entry.key}Json_WhenGenerated_ThenStableLabeledResult',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['person', 'generate', ...entry.value.$1, '--count=2', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          personService: _service(entry.value.$2, today),
        );

        expect(code, 0);
        final json = jsonDecode(out.toString()) as Map<String, Object?>;
        expect(json['count'], 2);
        expect(json['synthetic'], isTrue);
        expect(json['label'], 'synthetic-test-data');
        expect(json['people'], hasLength(2));
        final person =
            (json['people'] as List<Object?>).first as Map<String, Object?>;
        final identifier =
            (person['identifiers'] as List<Object?>).first
                as Map<String, Object?>;
        expect(identifier['locale'], entry.key == 'Us' ? 'us' : 'br');
        expect(identifier['synthetic'], isTrue);
        expect(err.toString(), isEmpty);
      },
    );
  }

  final invalidCases = <String, List<String>>{
    'locale': ['--locale=ca'],
    'minimumAge': ['--min-age=-1'],
    'maximumAge': ['--max-age=131'],
    'ageRange': ['--min-age=91', '--max-age=18'],
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
          ['person', 'generate', ...entry.value, '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          personService: _service(_usPerson(), today),
        );

        expect(code, 64);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('Avery')));
        expect(err.toString(), isNot(contains('PRIVATE')));
        final error =
            (jsonDecode(err.toString()) as Map<String, Object?>)['error']
                as Map<String, Object?>;
        expect(error['kind'], 'validation');
        expect(error['code'], startsWith('person.'));
      },
    );
  }

  test(
    'GivenValidFirstThenExhaustion_WhenGenerated_ThenNoPartialPerson',
    () async {
      var attempts = 0;
      final out = StringBuffer(), err = StringBuffer();
      final code = await runChimera(
        ['person', 'generate', '--count=2', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        personService: PersonService(
          generator: PersonGenerator.forTesting(
            candidate: (_, _) => ++attempts == 1
                ? _usPerson()
                : _usPerson(phone: '+1 (212) 555-0100'),
            today: () => today,
          ),
        ),
      );

      expect(attempts, 33);
      expect(code, 70);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('Avery')));
      final error =
          (jsonDecode(err.toString()) as Map<String, Object?>)['error']
              as Map<String, Object?>;
      expect(error['code'], 'person.generation-failed');
    },
  );

  test(
    'GivenOutputPath_WhenGenerated_ThenExactLabeledBatchAndNotice',
    () async {
      final out = StringBuffer(), err = StringBuffer();
      List<int>? written;
      final code = await runChimera(
        [
          'person',
          'generate',
          '--locale=br',
          '--min-age=21',
          '--max-age=40',
          '--output=result.txt',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        personService: _service(_brPerson(), today),
        writeOutputFile: (path, bytes) async {
          expect(path, 'result.txt');
          written = bytes;
        },
      );

      expect(code, 0);
      expect(err.toString(), isEmpty);
      final saved = utf8.decode(written!);
      expect(
        saved,
        contains(
          const MessageCatalog().lookup('pt-BR', 'person.syntheticLabel'),
        ),
      );
      expect(saved, contains('Ana Silva'));
      expect(saved, contains('CPF: 280.012.389-38'));
      expect(saved, contains('CIN: 280.012.389-38'));
      expect(
        out.toString(),
        '${const MessageCatalog().lookup('pt-BR', 'person.saved')}\n',
      );
    },
  );

  test('GivenOutputWriterFailure_WhenGenerated_Then74WithoutPerson', () async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runChimera(
      ['person', 'generate', '--output=PRIVATE', '--json'],
      localeTag: 'en',
      out: out,
      err: err,
      personService: _service(_usPerson(), today),
      writeOutputFile: (_, _) async =>
          throw const FileSystemException('PRIVATE'),
    );

    expect(code, 74);
    expect(out.toString(), isEmpty);
    expect(err.toString(), isNot(contains('PRIVATE')));
    expect(err.toString(), isNot(contains('Avery')));
  });

  test('GivenStdoutFailure_WhenGenerated_Then74WithoutPerson', () async {
    final err = StringBuffer();
    final code = await runChimera(
      ['person', 'generate'],
      localeTag: 'en',
      out: const _DeniedSink(),
      err: err,
      personService: _service(_usPerson(), today),
    );

    expect(code, 74);
    expect(err.toString(), isNot(contains('Avery')));
  });

  for (final resource in [false, true]) {
    test(
      'Given${resource}SerializationFailure_WhenJsonRequested_ThenTypedFailure',
      () async {
        final out = StringBuffer(), err = StringBuffer();
        final code = await runChimera(
          ['person', 'generate', '--json'],
          localeTag: 'en',
          out: out,
          err: err,
          personService: _service(_usPerson(), today),
          personJsonEncoder: (_) {
            if (resource) throw OutOfMemoryError();
            throw StateError('PRIVATE');
          },
        );

        expect(code, resource ? 75 : 74);
        expect(out.toString(), isEmpty);
        expect(err.toString(), isNot(contains('PRIVATE')));
        expect(err.toString(), isNot(contains('Avery')));
      },
    );
  }

  test(
    'GivenNativeExecutable_WhenPersonCommandRuns_ThenProductionContractHolds',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chimera-person-executable-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final library = (await Isolate.resolvePackageUri(
        Uri.parse('package:chimera_cli/chimera_cli.dart'),
      ))!;
      final entrypoint = File.fromUri(library.resolve('../bin/chimera.dart'));
      final executable =
          '${directory.path}/chimera-person${Platform.isWindows ? '.exe' : ''}';
      final compilation = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'exe',
        entrypoint.path,
        '-o',
        executable,
      ]);
      expect(compilation.exitCode, 0, reason: compilation.stderr.toString());

      final result = await Process.run(executable, [
        'person',
        'generate',
        '--locale=br',
        '--min-age=21',
        '--max-age=40',
        '--count=2',
        '--json',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final json = jsonDecode(result.stdout.toString()) as Map<String, Object?>;
      expect(json['locale'], 'br');
      expect(json['synthetic'], isTrue);
      expect(json['label'], 'synthetic-test-data');
      expect(json['people'], hasLength(2));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

PersonService _service(SyntheticPerson person, DateTime today) => PersonService(
  generator: PersonGenerator.forTesting(
    candidate: (_, _) => person,
    today: () => today,
  ),
);

SyntheticPerson _usPerson({String phone = '+1 (415) 555-0100'}) =>
    SyntheticPerson(
      locale: PersonLocale.us,
      givenName: 'Avery',
      familyName: 'Reed',
      birthDate: DateTime.utc(1990, 6, 15),
      address: const PersonAddress(
        street: '100 Example Avenue',
        city: 'San Francisco',
        region: 'CA',
        postalCode: '94105',
        countryCode: 'US',
      ),
      phone: phone,
      email: 'avery.reed01@example.com',
      identifiers: const [
        PersonIdentifier(
          locale: PersonLocale.us,
          type: IdentityDocumentType.ssn,
          value: '219-09-9999',
        ),
      ],
    );

SyntheticPerson _brPerson() => SyntheticPerson(
  locale: PersonLocale.br,
  givenName: 'Ana',
  familyName: 'Silva',
  birthDate: DateTime.utc(1992, 2, 29),
  address: const PersonAddress(
    street: 'Rua Exemplo, 100',
    city: 'São Paulo',
    region: 'SP',
    postalCode: '01000-000',
    countryCode: 'BR',
  ),
  phone: '+55 (11) 90000-0000',
  email: 'ana.silva01@example.com',
  identifiers: const [
    PersonIdentifier(
      locale: PersonLocale.br,
      type: IdentityDocumentType.cpf,
      value: '280.012.389-38',
    ),
    PersonIdentifier(
      locale: PersonLocale.br,
      type: IdentityDocumentType.cin,
      value: '280.012.389-38',
    ),
  ],
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
