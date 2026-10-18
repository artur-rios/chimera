import 'dart:convert';
import 'dart:io';

import 'package:chimera_cli/chimera_cli.dart';
import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

const _secret = '0123456789abcdef0123456789abcdef';
const _token =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiIxMjM0NTY3ODkwIiwiYWRtaW4iOnRydWV9.'
    'GpegCaZaV8lAuGeXX71D9MjJFAI6MUSoLLD2JD3e8Qs';

void main() {
  test('GivenDirectToken_WhenInspected_ThenHumanDecodeOnlyReturns', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      <String>['jwt', 'inspect', '--token=$_token'],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 0);
    expect(err.toString(), isEmpty);
    expect(
      out.toString(),
      'Header: {"alg":"HS256","typ":"JWT"}\n'
      'Claims: {"sub":"1234567890","admin":true}\n'
      'Verification: Not requested\n',
    );
  });

  test(
    'GivenTokenAndKeyFiles_WhenJsonRequested_ThenVerifiedJsonReturns',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final reads = <String>[];

      final exitCode = await runChimera(
        <String>[
          'jwt',
          'inspect',
          '--token-file=token.jwt',
          '--key-file=key.txt',
          '--json',
        ],
        localeTag: 'pt-BR',
        out: out,
        err: err,
        readFileBytes: (path) async {
          reads.add(path);
          return utf8.encode(path == 'token.jwt' ? _token : _secret);
        },
      );

      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
      expect(reads, <String>['token.jwt', 'key.txt']);
      expect(jsonDecode(out.toString()), <String, Object?>{
        'header': <String, Object?>{'alg': 'HS256', 'typ': 'JWT'},
        'claims': <String, Object?>{'sub': '1234567890', 'admin': true},
        'verification': 'verified',
      });
      expect(out.toString(), endsWith('\n'));
    },
  );

  test(
    'GivenFailedSignatureFromStdin_WhenInspected_ThenAf02ReturnsExitZero',
    () async {
      final parts = _token.split('.');
      final failedToken =
          '${parts[0]}.${parts[1]}.${_segment(List<int>.filled(32, 0))}';
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>['jwt', 'inspect', '--stdin', '--key=$_secret', '--json'],
        localeTag: 'en',
        out: out,
        err: err,
        readStandardInputBytes: () async => utf8.encode(failedToken),
      );

      expect(exitCode, 0);
      expect(err.toString(), isEmpty);
      final decoded = jsonDecode(out.toString()) as Map<String, dynamic>;
      expect(decoded['verification'], 'failed');
      expect((decoded['claims'] as Map<String, dynamic>)['sub'], '1234567890');
    },
  );

  test(
    'GivenConflictingTokenSources_WhenRun_ThenValidationPrecedesIo',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();
      var reads = 0;

      final exitCode = await runChimera(
        <String>[
          'jwt',
          'inspect',
          '--token=$_token',
          '--token-file=private-token.jwt',
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
      expect(err.toString(), 'The JWT inspection request is invalid.\n');
    },
  );

  test(
    'GivenMalformedUtf8TokenFile_WhenRun_ThenValidationIsRedacted',
    () async {
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>['jwt', 'inspect', '--token-file=private-token.jwt'],
        localeTag: 'en',
        out: out,
        err: err,
        readFileBytes: (_) async => <int>[0xff],
      );

      expect(exitCode, 64);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'The JWT inspection request is invalid.\n');
      expect(err.toString(), isNot(contains('private-token.jwt')));
    },
  );

  test('GivenKeyFileAccessFailure_WhenRun_ThenExit74IsRedacted', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      <String>[
        'jwt',
        'inspect',
        '--token=$_token',
        '--key-file=private-key.pem',
      ],
      localeTag: 'pt-BR',
      out: out,
      err: err,
      readFileBytes: (_) async => throw StateError('private-read-marker'),
    );

    expect(exitCode, 74);
    expect(out.toString(), isEmpty);
    expect(err.toString(), 'Não foi possível ler o arquivo de chave.\n');
    expect(err.toString(), isNot(contains('private-key.pem')));
    expect(err.toString(), isNot(contains('private-read-marker')));
  });

  test('GivenCryptographicFailure_WhenRun_ThenExit70IsRedacted', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      <String>['jwt', 'inspect', '--token=$_token', '--key=$_secret'],
      localeTag: 'en',
      out: out,
      err: err,
      jwtInspectService: JwtInspectService(
        inspector: JwtInspector.forTesting(
          verify: (_, _, _, _) => throw StateError('private-dependency-marker'),
        ),
      ),
    );

    expect(exitCode, 70);
    expect(out.toString(), isEmpty);
    expect(err.toString(), 'The JWT signature could not be verified.\n');
    expect(err.toString(), isNot(contains(_token)));
    expect(err.toString(), isNot(contains(_secret)));
    expect(err.toString(), isNot(contains('private-dependency-marker')));
  });

  test('GivenResourceFailure_WhenRun_ThenExit75Returns', () async {
    final out = StringBuffer();
    final err = StringBuffer();

    final exitCode = await runChimera(
      <String>['jwt', 'inspect', '--token=$_token'],
      localeTag: 'en',
      out: out,
      err: err,
      jwtInspectService: const JwtInspectService(
        inspector: JwtInspector(maxInputBytes: 1),
      ),
    );

    expect(exitCode, 75);
    expect(out.toString(), isEmpty);
    expect(err.toString(), 'JWT inspection exceeded its resource limit.\n');
  });

  test('GivenNonFiniteClaim_WhenRun_ThenTypedValidationReturns', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    final token = _unsignedToken('{"alg":"HS256"}', '{"value":1e400}');

    final exitCode = await runChimera(
      <String>['jwt', 'inspect', '--token=$token', '--json'],
      localeTag: 'en',
      out: out,
      err: err,
    );

    expect(exitCode, 64);
    expect(out.toString(), isEmpty);
    expect(jsonDecode(err.toString()), <String, Object?>{
      'error': <String, Object?>{
        'kind': 'validation',
        'code': 'jwt-inspect.invalid-token',
        'message': 'The JWT inspection request is invalid.',
        'location': <String, Object?>{
          'field': 'token',
          'reason': 'invalid-json',
        },
      },
    });
  });

  test(
    'GivenOversizedTokenFile_WhenRun_ThenReadIsRejectedAsResource',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimera-jwt-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/oversized.jwt');
      final handle = file.openSync(mode: FileMode.write);
      try {
        handle.truncateSync(JwtInspector.defaultMaxInputBytes + 1);
      } finally {
        handle.closeSync();
      }
      final out = StringBuffer();
      final err = StringBuffer();

      final exitCode = await runChimera(
        <String>['jwt', 'inspect', '--token-file=${file.path}'],
        localeTag: 'en',
        out: out,
        err: err,
      );

      expect(exitCode, 75);
      expect(out.toString(), isEmpty);
      expect(err.toString(), 'JWT inspection exceeded its resource limit.\n');
    },
  );

  test('GivenHelp_WhenRunInBothLocales_ThenJwtInspectUsageReturns', () async {
    for (final locale in <String>['en', 'pt-BR']) {
      final out = StringBuffer();
      final exitCode = await runChimera(
        <String>['jwt', 'inspect', '--help'],
        localeTag: locale,
        out: out,
        err: StringBuffer(),
      );
      expect(exitCode, 0);
      expect(out.toString(), contains('chimera jwt inspect'));
      expect(out.toString(), contains('--token-file'));
      expect(out.toString(), contains('--key-file'));
    }
  });
}

String _segment(List<int> value) => base64Url.encode(value).replaceAll('=', '');

String _unsignedToken(String header, String claims) =>
    '${_segment(utf8.encode(header))}.${_segment(utf8.encode(claims))}.'
    '${_segment(<int>[1])}';
