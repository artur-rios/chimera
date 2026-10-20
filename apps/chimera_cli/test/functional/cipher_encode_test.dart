import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final knownAnswers = <({List<String> options, String encoded})>[
    (options: ['--cipher=caesar', '--shift=3'], encoded: 'Dwwdfn'),
    (options: ['--cipher=rot13'], encoded: 'Nggnpx'),
    (options: ['--cipher=vigenere', '--key=LEMON'], encoded: 'Lxfopv'),
    (options: ['--cipher=atbash'], encoded: 'Zggzxp'),
    (options: ['--cipher=affine', '--a=5', '--b=8'], encoded: 'Izzisg'),
    (options: ['--cipher=bacon'], encoded: 'AAAAAbaabbbaabbaaaaaaaabaababa'),
    (options: ['--cipher=rail-fence', '--rails=3'], encoded: 'Actakt'),
  ];

  for (final locale in ['en', 'pt-BR']) {
    for (final fixture in knownAnswers) {
      test('Given$locale${fixture.options.first}'
          '_WhenCipherEncoded_ThenKnownAnswerReturns', () async {
        final out = StringBuffer();
        final err = StringBuffer();
        final exit = await runChimera(
          ['cipher', 'encode', '--input=Attack', ...fixture.options],
          localeTag: locale,
          out: out,
          err: err,
        );

        expect(exit, 0);
        expect(err.toString(), isEmpty);
        expect(out.toString(), fixture.encoded);
      });
    }

    test('Given${locale}Help_WhenRequested_ThenContractIsDocumented', () async {
      final out = StringBuffer();
      final exit = await runChimera(
        ['--help', 'cipher', 'encode'],
        localeTag: locale,
        out: out,
        err: StringBuffer(),
      );

      expect(exit, 0);
      expect(out.toString(), contains('chimera cipher encode'));
      for (final value in [
        'caesar',
        'rot13',
        'vigenere',
        'atbash',
        'affine',
        'bacon',
        'rail-fence',
        'preserve',
        'reject',
        '64',
        '74',
        '75',
      ]) {
        expect(out.toString(), contains(value));
      }
    });
  }

  for (final source in ['argument', 'stdin', 'file']) {
    test(
      'Given${source}Source_WhenEncodedAsJson_ThenStableShapeReturns',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        final exit = await runChimera(
          [
            'cipher',
            'encode',
            '--cipher=atbash',
            if (source == 'argument') '--input=Abc 😀',
            if (source == 'stdin') '--stdin',
            if (source == 'file') '--file=private',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
          readStandardInputBytes: () async => utf8.encode('Abc 😀'),
          readFileBytes: (_) async => utf8.encode('Abc 😀'),
        );

        expect(exit, 0);
        expect(err.toString(), isEmpty);
        expect(jsonDecode(out.toString()), {
          'encoded': 'Zyx 😀',
          'cipher': 'atbash',
          'characterPolicy': 'preserve',
        });
      },
    );
  }

  test(
    'GivenRejectedUnicode_WhenEncoded_ThenSafeScalarLocationReturns',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        [
          'cipher',
          'encode',
          '--input=A😀B',
          '--cipher=atbash',
          '--character-policy=reject',
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
        'code': 'cipher.unsupported-symbol',
        'message': 'The cipher encoding request is invalid.',
        'location': {
          'field': 'input',
          'reason': 'unsupported-symbol',
          'position': 1,
        },
      });
      expect(err.toString(), isNot(contains('😀')));
    },
  );

  final invalidCases = <({List<String> options, String code})>[
    (options: ['--cipher=atbash'], code: 'cipher.missing-source'),
    (
      options: ['--input=x', '--stdin', '--cipher=atbash'],
      code: 'cipher.conflicting-sources',
    ),
    (options: ['--input=x', '--cipher=unknown'], code: 'cipher.invalid-cipher'),
    (
      options: ['--input=x', '--cipher=atbash', '--character-policy=drop'],
      code: 'cipher.invalid-character-policy',
    ),
    (
      options: ['--input=x', '--cipher=caesar'],
      code: 'cipher.invalid-parameter',
    ),
    (
      options: ['--input=x', '--cipher=vigenere', '--key=private-1'],
      code: 'cipher.invalid-parameter',
    ),
    (
      options: ['--input=x', '--cipher=atbash', '--key=private'],
      code: 'cipher.invalid-parameter',
    ),
    (
      options: ['--input=x', '--cipher=atbash', '--unknown=value'],
      code: 'cipher.invalid-options',
    ),
  ];
  for (final fixture in invalidCases) {
    test('Given${fixture.code}_WhenParsed_ThenTypedRedactedFailure', () async {
      var reads = 0;
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        ['cipher', 'encode', ...fixture.options, '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async {
          reads++;
          return utf8.encode('private');
        },
      );

      expect(exit, 64);
      expect(out.toString(), isEmpty);
      expect(
        (jsonDecode(err.toString()) as Map)['error']['code'],
        fixture.code,
      );
      expect(err.toString(), isNot(contains('private')));
      if (fixture.code == 'cipher.invalid-options' ||
          fixture.code == 'cipher.missing-source' ||
          fixture.code == 'cipher.conflicting-sources' ||
          fixture.code == 'cipher.invalid-cipher' ||
          fixture.code == 'cipher.invalid-character-policy') {
        expect(reads, 0);
      }
    });
  }

  for (final locale in ['en', 'pt-BR']) {
    test(
      'Given${locale}Output_WhenSaved_ThenExactUtf8AndNoticeReturn',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'chimera-cipher-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final target = File('${directory.path}/encoded.txt');
        await target.writeAsString('prior');
        final out = StringBuffer();
        final err = StringBuffer();
        final exit = await runChimera(
          [
            'cipher',
            'encode',
            '--input=Abc',
            '--cipher=atbash',
            '--output=${target.path}',
          ],
          localeTag: locale,
          out: out,
          err: err,
        );

        expect(exit, 0);
        expect(await target.readAsString(), 'Zyx');
        expect(
          out.toString(),
          locale == 'en'
              ? 'Cipher encoded text saved.\n'
              : 'Texto cifrado salvo.\n',
        );
        expect(err.toString(), isEmpty);
      },
    );
  }

  test('GivenResourceFailure_WhenEncoded_ThenNoOutputIsSaved', () async {
    var saves = 0;
    final out = StringBuffer();
    final err = StringBuffer();
    final exit = await runChimera(
      [
        'cipher',
        'encode',
        '--input=A',
        '--cipher=bacon',
        '--output=private',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
      cipherEncodeService: const CipherEncodeService(
        encoder: CipherEncoder(maxOutputCharacters: 4),
      ),
      writeOutputFile: (_, _) async => saves++,
    );

    expect(exit, 75);
    expect(saves, 0);
    expect(out.toString(), isEmpty);
    expect(
      (jsonDecode(err.toString()) as Map)['error']['code'],
      'cipher.resource-limit',
    );
  });
}
