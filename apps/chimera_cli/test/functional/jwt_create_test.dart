import 'dart:convert';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:test/test.dart';

const _secret = '0123456789abcdef0123456789abcdef';

void main() {
  test(
    'GivenDirectSources_WhenJwtCreated_ThenExactTokenHasNoNewline',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final exitCode = await runChimera(
        <String>[
          'jwt',
          'create',
          '--algorithm=HS256',
          '--claims={"sub":"1234567890","admin":true}',
          '--key=$_secret',
        ],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
      expect(
        out.toString(),
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJzdWIiOiIxMjM0NTY3ODkwIiwiYWRtaW4iOnRydWV9.'
        'GpegCaZaV8lAuGeXX71D9MjJFAI6MUSoLLD2JD3e8Qs',
      );
    },
  );

  test(
    'GivenStdinClaimsAndKeyFile_WhenJsonRequested_ThenJsonReturns',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final reads = <String>[];
      final exitCode = await runChimera(
        <String>[
          'jwt',
          'create',
          '--algorithm=HS256',
          '--stdin',
          '--key-file=key.txt',
          '--json',
        ],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async {
          reads.add('stdin');
          return utf8.encode('{"value":1}');
        },
        readFileBytes: (path) async {
          reads.add(path);
          return utf8.encode(_secret);
        },
      );

      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
      expect(reads, <String>['stdin', 'key.txt']);
      final decoded = jsonDecode(out.toString()) as Map<String, dynamic>;
      expect((decoded['token'] as String).split('.'), hasLength(3));
      expect(out.toString(), endsWith('\n'));
    },
  );

  test('GivenOutputPath_WhenJwtCreated_ThenExactBytesAreSaved', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    String? path;
    List<int>? bytes;
    final exitCode = await runChimera(
      <String>[
        'jwt',
        'create',
        '--algorithm=HS256',
        '--claims={}',
        '--key=$_secret',
        '--output=token.jwt',
      ],
      localeTag: 'pt-BR',
      out: out,
      err: err,
      writeOutputFile: (value, payload) async {
        path = value;
        bytes = List<int>.of(payload);
      },
    );

    expect(exitCode, 0);
    expect(path, 'token.jwt');
    expect(utf8.decode(bytes!).split('.'), hasLength(3));
    expect(out.toString(), 'JWT salvo.\n');
    expect(err.toString(), isEmpty);
  });

  test('GivenConflictingSources_WhenRun_ThenValidationPrecedesIo', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    var reads = 0;
    final exitCode = await runChimera(
      <String>[
        'jwt',
        'create',
        '--algorithm=HS256',
        '--claims={}',
        '--claims-file=private.json',
        '--key=$_secret',
      ],
      localeTag: 'en',
      out: out,
      err: err,
      readFileBytes: (_) async {
        reads++;
        throw StateError('must not read');
      },
    );

    expect(exitCode, 64);
    expect(reads, 0);
    expect(out.toString(), isEmpty);
    expect(err.toString(), 'The JWT creation request is invalid.\n');
  });

  test('GivenNoneAlgorithm_WhenRun_ThenRedactedValidationReturns', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final exitCode = await runChimera(
      <String>[
        'jwt',
        'create',
        '--algorithm=none',
        '--claims={"secret":"private-claims-marker"}',
        '--key=private-key-marker',
        '--json',
      ],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 64);
    expect(out.toString(), isEmpty);
    expect(err.toString(), contains('jwt-create.invalid-algorithm'));
    expect(err.toString(), isNot(contains('private-claims-marker')));
    expect(err.toString(), isNot(contains('private-key-marker')));
  });

  test('GivenHelp_WhenRunInBothLocales_ThenJwtUsageReturns', () async {
    for (final locale in <String>['en', 'pt-BR']) {
      final out = StringBuffer();
      final exitCode = await runChimera(
        <String>['jwt', 'create', '--help'],
        localeTag: locale,
        out: out,
        err: StringBuffer(),
      );
      expect(exitCode, 0);
      expect(out.toString(), contains('chimera jwt create'));
      expect(out.toString(), contains('HS256'));
    }
  });
}
