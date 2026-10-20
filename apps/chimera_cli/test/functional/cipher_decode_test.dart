import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  final knownAnswers = <({List<String> options, String encoded, String plain})>[
    (
      options: ['--cipher=caesar', '--shift=3'],
      encoded: 'Dwwdfn',
      plain: 'Attack',
    ),
    (options: ['--cipher=rot13'], encoded: 'Nggnpx', plain: 'Attack'),
    (
      options: ['--cipher=vigenere', '--key=LEMON'],
      encoded: 'Lxfopv',
      plain: 'Attack',
    ),
    (options: ['--cipher=atbash'], encoded: 'Zggzxp', plain: 'Attack'),
    (
      options: ['--cipher=affine', '--a=5', '--b=8'],
      encoded: 'Izzisg',
      plain: 'Attack',
    ),
    (
      options: ['--cipher=bacon'],
      encoded: 'AAAAAbaabbbaabbaaaaaaaabaababa',
      plain: 'Attack',
    ),
    (
      options: ['--cipher=rail-fence', '--rails=3'],
      encoded: 'Actakt',
      plain: 'Attack',
    ),
  ];

  for (final locale in ['en', 'pt-BR']) {
    for (final fixture in knownAnswers) {
      test(
        'Given$locale${fixture.options.first}_WhenCipherDecoded_ThenKnownAnswerReturns',
        () async {
          final out = StringBuffer();
          final err = StringBuffer();
          final exit = await runChimera(
            [
              'cipher',
              'decode',
              '--input=${fixture.encoded}',
              ...fixture.options,
            ],
            localeTag: locale,
            out: out,
            err: err,
          );

          expect(exit, 0);
          expect(err.toString(), isEmpty);
          expect(out.toString(), fixture.plain);
        },
      );
    }

    test('Given${locale}Help_WhenRequested_ThenContractIsDocumented', () async {
      final out = StringBuffer();
      final exit = await runChimera(
        ['--help', 'cipher', 'decode'],
        localeTag: locale,
        out: out,
        err: StringBuffer(),
      );

      expect(exit, 0);
      expect(out.toString(), contains('chimera cipher decode'));
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
      'Given${source}Source_WhenDecodedAsJson_ThenStableShapeReturns',
      () async {
        final out = StringBuffer();
        final err = StringBuffer();
        final exit = await runChimera(
          [
            'cipher',
            'decode',
            '--cipher=atbash',
            if (source == 'argument') '--input=Zyx \u{1F9EA}',
            if (source == 'stdin') '--stdin',
            if (source == 'file') '--file=private',
            '--json',
          ],
          localeTag: 'en',
          out: out,
          err: err,
          readStandardInputBytes: () async => utf8.encode('Zyx \u{1F9EA}'),
          readFileBytes: (_) async => utf8.encode('Zyx \u{1F9EA}'),
        );

        expect(exit, 0);
        expect(err.toString(), isEmpty);
        expect(jsonDecode(out.toString()), {
          'decoded': 'Abc \u{1F9EA}',
          'cipher': 'atbash',
          'characterPolicy': 'preserve',
        });
      },
    );
  }

  test(
    'GivenRejectedUnicode_WhenDecoded_ThenSafeScalarLocationReturns',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        [
          'cipher',
          'decode',
          '--input=Z\u{1F9EA}Y',
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
        'message': 'The cipher decoding request is invalid.',
        'location': {
          'field': 'input',
          'reason': 'unsupported-symbol',
          'position': 1,
        },
      });
      expect(err.toString(), isNot(contains('\u{1F9EA}')));
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
        ['cipher', 'decode', ...fixture.options, '--json'],
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
      final envelope = jsonDecode(err.toString()) as Map<String, dynamic>;
      final error = envelope['error'] as Map<String, dynamic>;
      expect(error['code'], fixture.code);
      expect(err.toString(), isNot(contains('private')));
      if (fixture.code != 'cipher.invalid-parameter') expect(reads, 0);
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
        final target = File('${directory.path}/decoded.txt');
        await target.writeAsString('prior');
        final out = StringBuffer();
        final err = StringBuffer();
        final exit = await runChimera(
          [
            'cipher',
            'decode',
            '--input=Zyx',
            '--cipher=atbash',
            '--output=${target.path}',
          ],
          localeTag: locale,
          out: out,
          err: err,
        );

        expect(exit, 0);
        expect(await target.readAsString(), 'Abc');
        expect(
          out.toString(),
          locale == 'en'
              ? 'Cipher decoded text saved.\n'
              : 'Texto decifrado salvo.\n',
        );
        expect(err.toString(), isEmpty);
      },
    );
  }

  test('GivenInputAccessFailure_WhenDecoded_ThenExit74IsRedacted', () async {
    final err = StringBuffer();
    final exit = await runChimera(
      ['cipher', 'decode', '--stdin', '--cipher=atbash', '--json'],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
      readStandardInputBytes: () => throw StateError('private input'),
    );

    expect(exit, 74);
    expect(err.toString(), contains('cipher.input-access'));
    expect(err.toString(), isNot(contains('private input')));
  });

  test('GivenOutputAccessFailure_WhenDecoded_ThenExit74IsRedacted', () async {
    final err = StringBuffer();
    final exit = await runChimera(
      [
        'cipher',
        'decode',
        '--input=Z',
        '--cipher=atbash',
        '--output=private',
        '--json',
      ],
      localeTag: 'en',
      out: StringBuffer(),
      err: err,
      writeOutputFile: (_, _) => throw StateError('private output'),
    );

    expect(exit, 74);
    expect(err.toString(), contains('cipher.output-access'));
    expect(err.toString(), isNot(contains('private output')));
  });

  test('GivenResourceFailure_WhenDecoded_ThenNoOutputIsSaved', () async {
    var saves = 0;
    final out = StringBuffer();
    final err = StringBuffer();
    final exit = await runChimera(
      [
        'cipher',
        'decode',
        '--input=Z',
        '--cipher=atbash',
        '--output=private',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
      cipherDecodeService: const CipherDecodeService(
        decoder: CipherDecoder(maxOutputCharacters: 0),
      ),
      writeOutputFile: (_, _) async => saves++,
    );

    expect(exit, 75);
    expect(saves, 0);
    expect(out.toString(), isEmpty);
    expect(err.toString(), contains('cipher.resource-limit'));
  });

  test(
    'GivenUnexpectedProcessingFailure_WhenDecoded_ThenExit70IsRedacted',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exit = await runChimera(
        ['cipher', 'decode', '--input=secret', '--cipher=atbash', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        cipherDecodeService: const CipherDecodeService(
          decodeOverride: _throwUnexpectedFailure,
        ),
      );

      expect(exit, 70);
      expect(out.toString(), isEmpty);
      expect(err.toString(), isNot(contains('secret')));
      expect(err.toString(), isNot(contains('private decoder diagnostics')));
      final error = (jsonDecode(err.toString()) as Map)['error'] as Map;
      expect(error['kind'], 'processing');
      expect(error['code'], 'cipher.processing-failed');
      expect(error['message'], 'Cipher decoding failed.');
    },
  );
}

CipherDecodeResult _throwUnexpectedFailure(CipherDecodeRequest request) =>
    throw StateError('private decoder diagnostics');
