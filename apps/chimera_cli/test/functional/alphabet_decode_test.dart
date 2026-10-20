import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final knownAnswers = <({String alphabet, String input, String decoded})>[
    (alphabet: 'morse', input: '... --- ... / ..---', decoded: 'SOS 2'),
    (alphabet: 'nato', input: 'alfa ZULU / niner', decoded: 'AZ 9'),
    (
      alphabet: 'braille',
      input: '\u2820\u2801\u283c\u2801\u281a\u2830\u2801',
      decoded: 'A10a',
    ),
  ];

  for (final locale in ['en', 'pt-BR']) {
    for (final fixture in knownAnswers) {
      test(
        'Given$locale${fixture.alphabet}_WhenDecoded_ThenReferenceReturns',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          final exit = await runChimera(
            [
              'alphabet',
              'decode',
              '--input=${fixture.input}',
              '--alphabet=${fixture.alphabet}',
            ],
            localeTag: locale,
            out: out,
            err: err,
          );

          expect(exit, 0);
          expect(err.toString(), isEmpty);
          expect(out.toString(), startsWith('${fixture.decoded}\n'));
          expect(
            out.toString(),
            contains(locale == 'en' ? 'Mapping: ' : 'Mapeamento: '),
          );
        },
      );
    }

    test(
      'Given${locale}DecodeHelp_WhenRequested_ThenContractIsDocumented',
      () async {
        final out = StringBuffer();
        final exit = await runChimera(
          ['--help', 'alphabet', 'decode'],
          localeTag: locale,
          out: out,
          err: StringBuffer(),
        );

        expect(exit, 0);
        expect(out.toString(), contains('chimera alphabet decode'));
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
      },
    );
  }

  for (final source in ['argument', 'stdin', 'file']) {
    test(
      'Given${source}Source_WhenDecodedAsJson_ThenStableMappingReturns',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        final exit = await runChimera(
          [
            'alphabet',
            'decode',
            '--alphabet=morse',
            if (source == 'argument') '--input=.- -...',
            if (source == 'stdin') '--stdin',
            if (source == 'file') '--file=private',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
          readStandardInputBytes: () async => utf8.encode('.- -...'),
          readFileBytes: (_) async => utf8.encode('.- -...'),
        );

        expect(exit, 0);
        expect(err.toString(), isEmpty);
        final result = jsonDecode(out.toString()) as Map<String, dynamic>;
        expect(result['decoded'], 'AB');
        expect(result['alphabet'], 'morse');
        expect((result['mapping'] as Map)['id'], 'itu-r-m.1677-1');
      },
    );
  }

  test(
    'GivenAmbiguousInput_WhenDecoded_ThenSafeScalarLocationReturns',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        [
          'alphabet',
          'decode',
          '--input=.-  -...',
          '--alphabet=morse',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exit, 64);
      expect(out.toString(), isEmpty);
      expect((jsonDecode(err.toString()) as Map)['error'], {
        'kind': 'validation',
        'code': 'alphabet.invalid-input',
        'message': 'The alphabet decoding request is invalid.',
        'location': {
          'field': 'input',
          'reason': 'invalid-token-sequence',
          'position': 3,
        },
      });
      expect(err.toString(), isNot(contains('.-')));
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
    test('GivenDecode${fixture.code}_WhenParsed_ThenTypedFailure', () async {
      var reads = 0;
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        ['alphabet', 'decode', ...fixture.options, '--json'],
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
      expect(
        ((jsonDecode(err.toString()) as Map)['error'] as Map)['code'],
        fixture.code,
      );
      expect(err.toString(), isNot(contains('private')));
    });
  }

  test('GivenDecodeOutput_WhenSaved_ThenExactUtf8AndReferenceReturn', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chimera-alphabet-decode-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final target = File('${directory.path}/decoded.txt');
    await target.writeAsString('prior');
    final out = StringBuffer();
    final err = StringBuffer();
    final exit = await runChimera(
      [
        'alphabet',
        'decode',
        '--input=... --- ...',
        '--alphabet=morse',
        '--output=${target.path}',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exit, 0);
    expect(await target.readAsString(), 'SOS');
    expect(out.toString(), startsWith('Alphabet-decoded text saved.\n'));
    expect(out.toString(), contains('itu-r-m.1677-1 (10/2009)'));
    expect(err.toString(), isEmpty);
  });

  test('GivenDecodeAccessFailure_WhenRead_ThenExit74Returns', () async {
    final err = StringBuffer();
    final exit = await runChimera(
      ['alphabet', 'decode', '--stdin', '--alphabet=morse', '--json'],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
      readStandardInputBytes: () async =>
          throw const FileSystemException('private'),
    );

    expect(exit, 74);
    expect(
      ((jsonDecode(err.toString()) as Map)['error'] as Map)['code'],
      'alphabet.input-access',
    );
    expect(err.toString(), isNot(contains('private')));
  });

  test('GivenDecodeResourceFailure_WhenRun_ThenExit75AndNoSave', () async {
    var saves = 0;
    final err = StringBuffer();
    final exit = await runChimera(
      [
        'alphabet',
        'decode',
        '--input=.-',
        '--alphabet=morse',
        '--output=private',
        '--json',
      ],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
      alphabetDecodeService: const AlphabetDecodeService(
        decoder: AlphabetDecoder(maxOutputCharacters: 0),
      ),
      writeOutputFile: (_, _) async => saves++,
    );

    expect(exit, 75);
    expect(saves, 0);
    expect(
      ((jsonDecode(err.toString()) as Map)['error'] as Map)['code'],
      'alphabet.resource-limit',
    );
  });

  test('GivenDecodeProcessingFailure_WhenRun_ThenExit70IsRedacted', () async {
    final err = StringBuffer();
    final exit = await runChimera(
      ['alphabet', 'decode', '--input=secret', '--alphabet=nato', '--json'],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
      alphabetDecodeService: const AlphabetDecodeService(
        decodeOverride: _throwUnexpectedFailure,
      ),
    );

    expect(exit, 70);
    expect(err.toString(), isNot(contains('secret')));
    expect(err.toString(), isNot(contains('private decoder diagnostics')));
    final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
    expect(error['message'], 'Alphabet decoding failed.');
  });
}

AlphabetDecodeResult _throwUnexpectedFailure(AlphabetDecodeRequest request) =>
    throw StateError('private decoder diagnostics');
