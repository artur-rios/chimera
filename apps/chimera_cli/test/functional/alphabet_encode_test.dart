import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final knownAnswers = <({String alphabet, String input, String encoded})>[
    (alphabet: 'morse', input: 'SOS 2', encoded: '... --- ... / ..---'),
    (alphabet: 'nato', input: 'AZ 9', encoded: 'Alfa Zulu / Niner'),
    (
      alphabet: 'braille',
      input: 'A10a',
      encoded: '\u2820\u2801\u283c\u2801\u281a\u2830\u2801',
    ),
  ];

  for (final locale in ['en', 'pt-BR']) {
    for (final fixture in knownAnswers) {
      test(
        'Given$locale${fixture.alphabet}_WhenAlphabetEncoded_ThenKnownAnswerAndReferenceReturn',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          final exit = await runChimera(
            [
              'alphabet',
              'encode',
              '--input=${fixture.input}',
              '--alphabet=${fixture.alphabet}',
            ],
            localeTag: locale,
            out: out,
            err: err,
          );

          expect(exit, 0);
          expect(err.toString(), isEmpty);
          expect(out.toString(), startsWith('${fixture.encoded}\n'));
          expect(
            out.toString(),
            contains(locale == 'en' ? 'Mapping: ' : 'Mapeamento: '),
          );
          expect(
            out.toString(),
            contains(locale == 'en' ? 'Sources: ' : 'Fontes: '),
          );
        },
      );
    }

    test('Given${locale}Help_WhenRequested_ThenContractIsDocumented', () async {
      final out = StringBuffer();
      final exit = await runChimera(
        ['--help', 'alphabet', 'encode'],
        localeTag: locale,
        out: out,
        err: StringBuffer(),
      );

      expect(exit, 0);
      expect(out.toString(), contains('chimera alphabet encode'));
      for (final value in [
        'morse',
        'nato',
        'braille',
        '64',
        '70',
        '74',
        '75',
      ]) {
        expect(out.toString(), contains(value));
      }
    });
  }

  for (final source in ['argument', 'stdin', 'file']) {
    test(
      'Given${source}Source_WhenEncodedAsJson_ThenStableMappingReturns',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        final exit = await runChimera(
          [
            'alphabet',
            'encode',
            '--alphabet=morse',
            if (source == 'argument') '--input=AB',
            if (source == 'stdin') '--stdin',
            if (source == 'file') '--file=private',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
          readStandardInputBytes: () async => utf8.encode('AB'),
          readFileBytes: (_) async => utf8.encode('AB'),
        );

        expect(exit, 0);
        expect(err.toString(), isEmpty);
        final result = jsonDecode(out.toString()) as Map<String, dynamic>;
        expect(result['encoded'], '.- -...');
        expect(result['alphabet'], 'morse');
        final mapping = result['mapping'] as Map<String, dynamic>;
        expect(mapping['id'], 'itu-r-m.1677-1');
        expect(mapping['edition'], '10/2009');
        expect(mapping['sources'], hasLength(1));
        expect((mapping['symbols'] as Map)['A'], '.-');
        expect(mapping['rules'], isNotEmpty);
      },
    );
  }

  test(
    'GivenUnsupportedUnicode_WhenEncoded_ThenSafeScalarLocationReturns',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        ['alphabet', 'encode', '--input=A??B', '--alphabet=nato', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exit, 64);
      expect(out.toString(), isEmpty);
      expect((jsonDecode(err.toString()) as Map)['error'], {
        'kind': 'validation',
        'code': 'alphabet.unsupported-symbol',
        'message': 'The alphabet encoding request is invalid.',
        'location': {
          'field': 'input',
          'reason': 'unsupported-symbol',
          'position': 1,
        },
      });
      expect(err.toString(), isNot(contains('??')));
    },
  );

  final invalidCases = <({List<String> options, String code})>[
    (options: ['--alphabet=morse'], code: 'alphabet.missing-source'),
    (
      options: ['--input=x', '--stdin', '--alphabet=morse'],
      code: 'alphabet.conflicting-sources',
    ),
    (options: ['--input=x'], code: 'alphabet.invalid-alphabet'),
    (
      options: ['--input=x', '--alphabet=unknown'],
      code: 'alphabet.invalid-alphabet',
    ),
    (
      options: ['--input=x', '--alphabet=morse', '--unknown=value'],
      code: 'alphabet.invalid-options',
    ),
  ];
  for (final fixture in invalidCases) {
    test('Given${fixture.code}_WhenParsed_ThenTypedRedactedFailure', () async {
      var reads = 0;
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        ['alphabet', 'encode', ...fixture.options, '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async {
          reads++;
          return utf8.encode('private');
        },
      );

      expect(exit, 64);
      expect(reads, 0);
      expect(out.toString(), isEmpty);
      final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
      expect(error['code'], fixture.code);
      expect(err.toString(), isNot(contains('private')));
    });
  }

  for (final locale in ['en', 'pt-BR']) {
    test(
      'Given${locale}Output_WhenSaved_ThenExactUtf8AndReferenceReturn',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'chimera-alphabet-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/encoded.txt');
        await target.writeAsString('prior');
        final out = StringBuffer();
        final err = StringBuffer();
        final exit = await runChimera(
          [
            'alphabet',
            'encode',
            '--input=SOS',
            '--alphabet=morse',
            '--output=${target.path}',
          ],
          localeTag: locale,
          out: out,
          err: err,
        );

        expect(exit, 0);
        expect(await target.readAsString(), '... --- ...');
        expect(
          out.toString(),
          startsWith(
            locale == 'en'
                ? 'Alphabet-encoded text saved.\n'
                : 'Texto codificado com alfabeto salvo.\n',
          ),
        );
        expect(out.toString(), contains('itu-r-m.1677-1 (10/2009)'));
        expect(err.toString(), isEmpty);
      },
    );
  }

  test('GivenInputAccessFailure_WhenEncoded_ThenExit74Returns', () async {
    final err = StringBuffer();
    final exit = await runChimera(
      ['alphabet', 'encode', '--stdin', '--alphabet=morse', '--json'],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
      readStandardInputBytes: () async =>
          throw const FileSystemException('private'),
    );

    expect(exit, 74);
    final envelope = jsonDecode(err.toString()) as Map<String, dynamic>;
    final error = envelope['error'] as Map<String, dynamic>;
    expect(error['code'], 'alphabet.input-access');
    expect(err.toString(), isNot(contains('private')));
  });

  test('GivenOutputAccessFailure_WhenEncoded_ThenExit74Returns', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final exit = await runChimera(
      [
        'alphabet',
        'encode',
        '--input=A',
        '--alphabet=morse',
        '--output=private',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
      writeOutputFile: (_, _) async =>
          throw const FileSystemException('private'),
    );

    expect(exit, 74);
    expect(out.toString(), isEmpty);
    final envelope = jsonDecode(err.toString()) as Map<String, dynamic>;
    final error = envelope['error'] as Map<String, dynamic>;
    expect(error['code'], 'alphabet.output-access');
  });

  test('GivenResourceFailure_WhenEncoded_ThenNoOutputIsSaved', () async {
    var saves = 0;
    final out = StringBuffer();
    final err = StringBuffer();
    final exit = await runChimera(
      [
        'alphabet',
        'encode',
        '--input=A',
        '--alphabet=morse',
        '--output=private',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
      alphabetEncodeService: const AlphabetEncodeService(
        encoder: AlphabetEncoder(maxOutputCharacters: 0),
      ),
      writeOutputFile: (_, _) async => saves++,
    );

    expect(exit, 75);
    expect(saves, 0);
    expect(out.toString(), isEmpty);
    final envelope = jsonDecode(err.toString()) as Map<String, dynamic>;
    final error = envelope['error'] as Map<String, dynamic>;
    expect(error['code'], 'alphabet.resource-limit');
  });

  test(
    'GivenUnexpectedProcessingFailure_WhenEncoded_ThenExit70IsRedacted',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        ['alphabet', 'encode', '--input=secret', '--alphabet=nato', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        alphabetEncodeService: const AlphabetEncodeService(
          encodeOverride: _throwUnexpectedFailure,
        ),
      );

      expect(exit, 70);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('secret')));
      expect(err.toString(), isNot(contains('private encoder diagnostics')));
      final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
      expect(error['kind'], 'processing');
      expect(error['code'], 'alphabet.processing-failed');
      expect(error['message'], 'Alphabet encoding failed.');
    },
  );
}

AlphabetEncodeResult _throwUnexpectedFailure(AlphabetEncodeRequest request) =>
    throw StateError('private encoder diagnostics');
