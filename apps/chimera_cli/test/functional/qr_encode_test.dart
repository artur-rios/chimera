import 'dart:convert';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

void main() {
  test('GivenTextAndOutput_WhenQrEncoded_ThenExactPngIsSaved', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    String? savedPath;
    List<int>? savedBytes;

    final exitCode = await runChimera(
      <String>[
        'qr',
        'encode',
        '--text=hello',
        '--error-correction=high',
        '--size=256',
        '--margin=6',
        '--foreground=#112233',
        '--background=#F0F0F0',
        '--output=code.png',
      ],
      localeTag: 'en',
      out: out,
      err: err,
      writeOutputFile: (path, bytes) async {
        savedPath = path;
        savedBytes = List<int>.of(bytes);
      },
    );

    expect(exitCode, 0);
    expect(savedPath, 'code.png');
    expect(savedBytes!.take(8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    expect(out.toString(), contains('QR PNG saved'));
    expect(out.toString(), contains('256'));
    expect(err.toString(), isEmpty);
  });

  test('GivenStdinAndJson_WhenQrEncoded_ThenStableJsonReturns', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      <String>['qr', 'encode', '--stdin', '--json'],
      localeTag: 'en',
      out: out,
      err: err,
      readStandardInputBytes: () async => utf8.encode('Olá'),
    );

    expect(exitCode, 0);
    expect(err.toString(), isEmpty);
    final decoded = jsonDecode(out.toString()) as Map<String, dynamic>;
    expect(decoded.keys, <String>[
      'pngBase64',
      'size',
      'version',
      'moduleCount',
      'errorCorrection',
      'quietZoneModules',
      'foreground',
      'background',
      'inputByteCount',
      'outputByteCount',
    ]);
    expect(base64Decode(decoded['pngBase64'] as String).take(8), <int>[
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
    expect(decoded['inputByteCount'], 4);
    expect(out.toString(), endsWith('\n'));
  });

  test('GivenFileInput_WhenQrEncoded_ThenStrictUtf8IsReadOnce', () async {
    final reads = <String>[];
    final exitCode = await runChimera(
      <String>['qr', 'encode', '--file=input.txt', '--json'],
      localeTag: 'en',
      out: StringBuffer(),
      err: StringBuffer(),
      readFileBytes: (path) async {
        reads.add(path);
        return utf8.encode('file content');
      },
    );

    expect(exitCode, 0);
    expect(reads, <String>['input.txt']);
  });

  test(
    'GivenOversizedInvalidFile_WhenRead_ThenResourceLimitPrecedesUtf8Decode',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>['qr', 'encode', '--file=input.txt', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readFileBytes: (_) async => List<int>.filled(8193, 0xFF),
      );

      expect(exitCode, 75);
      expect(out.toString(), isEmpty);
      expect(err.toString(), contains('qr-encode.resource-limit'));
      expect(err.toString(), contains('byte-limit'));
      expect(err.toString(), isNot(contains('invalid-utf8')));
    },
  );

  test('GivenInvalidOptions_WhenRun_ThenValidationPrecedesIo', () async {
    final invalid = <List<String>>[
      <String>['qr', 'encode', '--json'],
      <String>['qr', 'encode', '--text=x', '--stdin', '--json'],
      <String>['qr', 'encode', '--text=x'],
      <String>['qr', 'encode', '--text=x', '--size=nope', '--json'],
      <String>['qr', 'encode', '--text=x', '--margin=-1', '--json'],
      <String>[
        'qr',
        'encode',
        '--text=x',
        '--error-correction=maximum',
        '--json',
      ],
    ];

    for (final args in invalid) {
      final out = StringBuffer();
      final err = StringBuffer();
      var reads = 0;
      final exitCode = await runChimera(
        args,
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async {
          reads++;
          return utf8.encode('must not read');
        },
      );
      expect(exitCode, 64, reason: '$args');
      expect(reads, 0, reason: '$args');
      expect(out.toString(), isEmpty, reason: '$args');
      expect(err.toString(), contains('QR encoding request is invalid'));
    }
  });

  test('GivenCapacityFailure_WhenRun_ThenExit64IsRedacted', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final oversized = List<String>.filled(300, 'private-marker-').join();
    final exitCode = await runChimera(
      <String>[
        'qr',
        'encode',
        '--text=$oversized',
        '--error-correction=high',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 64);
    expect(out.toString(), isEmpty);
    expect(err.toString(), contains('qr-encode.invalid-input'));
    expect(err.toString(), isNot(contains('private-marker')));
  });

  test('GivenInputAccessFailure_WhenRun_ThenExit74HasNoOutput', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final exitCode = await runChimera(
      <String>['qr', 'encode', '--file=private.txt', '--output=code.png'],
      localeTag: 'en',
      out: out,
      err: err,
      readFileBytes: (_) async => throw StateError('private-read-marker'),
    );

    expect(exitCode, 74);
    expect(out.toString(), isEmpty);
    expect(err.toString(), 'The QR input file could not be read.\n');
    expect(err.toString(), isNot(contains('private-read-marker')));
  });

  test('GivenOutputAccessFailure_WhenRun_ThenExit74HasNoSuccess', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final exitCode = await runChimera(
      <String>[
        'qr',
        'encode',
        '--text=private-input-marker',
        '--output=code.png',
      ],
      localeTag: 'en',
      out: out,
      err: err,
      writeOutputFile: (_, _) async => throw StateError('private-write-marker'),
    );

    expect(exitCode, 74);
    expect(out.toString(), isEmpty);
    expect(err.toString(), 'The QR PNG could not be saved.\n');
    expect(err.toString(), isNot(contains('private-input-marker')));
    expect(err.toString(), isNot(contains('private-write-marker')));
  });

  test('GivenHelp_WhenRunInBothLocales_ThenQrUsageReturns', () async {
    for (final locale in <String>['en', 'pt-BR']) {
      final out = StringBuffer();
      final exitCode = await runChimera(
        <String>['qr', 'encode', '--help'],
        localeTag: locale,
        out: out,
        err: StringBuffer(),
      );
      expect(exitCode, 0);
      expect(out.toString(), contains('chimera qr encode'));
      expect(out.toString(), contains('--error-correction'));
    }
  });

  test(
    'GivenPortugueseHumanOutput_WhenEncoded_ThenCorrectionIsLocalized',
    () async {
      final out = StringBuffer();
      final exitCode = await runChimera(
        <String>[
          'qr',
          'encode',
          '--text=olá',
          '--error-correction=high',
          '--output=code.png',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: StringBuffer(),
        writeOutputFile: (_, _) async {},
      );

      expect(exitCode, 0);
      expect(out.toString(), contains('Alta'));
      expect(out.toString(), isNot(contains(' high')));
    },
  );
}
