import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

const _secret = '0123456789abcdef0123456789abcdef';
const _token =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiIxMjM0NTY3ODkwIiwiYWRtaW4iOnRydWV9.'
    'GpegCaZaV8lAuGeXX71D9MjJFAI6MUSoLLD2JD3e8Qs';

void main() {
  test(
    'GivenDecodeOnlyRequest_WhenInspected_ThenStableOrderedJsonReturns',
    () async {
      final request = JwtInspectOperationRequest(token: _token);
      final output = _success(await const JwtInspectService().execute(request));

      expect(output.header, <String, Object?>{'alg': 'HS256', 'typ': 'JWT'});
      expect(output.claims, <String, Object?>{
        'sub': '1234567890',
        'admin': true,
      });
      expect(output.verification, JwtVerificationStatus.notRequested);
      expect(output.toJson().keys, <String>[
        'header',
        'claims',
        'verification',
      ]);
      expect(
        jsonEncode(output.toJson()),
        '{"header":{"alg":"HS256","typ":"JWT"},'
        '"claims":{"sub":"1234567890","admin":true},'
        '"verification":"not-requested"}',
      );
      expect(request.toString(), isNot(contains(_token)));
      expect(output.toString(), isNot(contains('1234567890')));
      expect(() => output.header['changed'] = true, throwsUnsupportedError);
      expect(() => output.claims['changed'] = true, throwsUnsupportedError);
    },
  );

  test('GivenEveryStatus_WhenSerialized_ThenStableNamesReturn', () async {
    final verified = _success(
      await const JwtInspectService().execute(
        JwtInspectOperationRequest(token: _token, key: _secret),
      ),
    );
    final parts = _token.split('.');
    final failedToken =
        '${parts[0]}.${parts[1]}.${_segment(List<int>.filled(32, 0))}';
    final failed = _success(
      await const JwtInspectService().execute(
        JwtInspectOperationRequest(token: failedToken, key: _secret),
      ),
    );

    expect(verified.toJson()['verification'], 'verified');
    expect(failed.toJson()['verification'], 'failed');
    expect(failed.claims['sub'], '1234567890');
  });

  test('GivenNestedOutput_WhenConstructed_ThenEntireJsonIsImmutable', () {
    final output = JwtInspectOutput(
      header: const <String, Object?>{'alg': 'HS256'},
      claims: <String, Object?>{
        'nested': <String, Object?>{
          'items': <Object?>[1],
        },
      },
      verification: JwtVerificationStatus.notRequested,
    );

    final nested = output.claims['nested']! as Map<String, Object?>;
    final items = nested['items']! as List<Object?>;
    expect(() => nested['changed'] = true, throwsUnsupportedError);
    expect(() => items.add(2), throwsUnsupportedError);
  });

  test(
    'GivenInjectedInspector_WhenInspected_ThenDelegatesExactlyOnce',
    () async {
      var calls = 0;
      final service = JwtInspectService(
        inspector: JwtInspector.forTesting(
          verify: (input, signature, algorithm, key) {
            calls++;
            expect(utf8.decode(input), startsWith('eyJ'));
            expect(signature, isNotEmpty);
            expect(algorithm, 'HS256');
            expect(key.keyType, 'oct');
            return true;
          },
        ),
      );

      final output = _success(
        await service.execute(
          JwtInspectOperationRequest(token: _token, key: _secret),
        ),
      );

      expect(calls, 1);
      expect(output.verification, JwtVerificationStatus.verified);
    },
  );

  group('GivenUtilityFailure_WhenInspected_ThenTypedFailureReturns', () {
    final fixtures =
        <
          ({
            String name,
            JwtInspectOperationRequest request,
            JwtInspector inspector,
            FailureKind kind,
            String code,
            String field,
            String reason,
            String messageKey,
          })
        >[
          (
            name: 'InvalidToken',
            request: JwtInspectOperationRequest(token: 'private-token-marker'),
            inspector: const JwtInspector(),
            kind: FailureKind.validation,
            code: 'jwt-inspect.invalid-token',
            field: 'token',
            reason: 'malformed-structure',
            messageKey: 'error.jwtInspect.validation',
          ),
          (
            name: 'NonFiniteClaim',
            request: JwtInspectOperationRequest(
              token: _unsignedToken('{"alg":"HS256"}', '{"value":1e400}'),
            ),
            inspector: const JwtInspector(),
            kind: FailureKind.validation,
            code: 'jwt-inspect.invalid-token',
            field: 'token',
            reason: 'invalid-json',
            messageKey: 'error.jwtInspect.validation',
          ),
          (
            name: 'VerificationFailure',
            request: JwtInspectOperationRequest(
              token: _token,
              key: 'private-key-marker-private-key-0000000000',
            ),
            inspector: JwtInspector.forTesting(
              verify: (_, _, _, _) => throw StateError('dependency-marker'),
            ),
            kind: FailureKind.processing,
            code: 'jwt-inspect.verification-failed',
            field: 'token',
            reason: 'cryptographic-failure',
            messageKey: 'error.jwtInspect.processing',
          ),
          (
            name: 'ResourceFailure',
            request: JwtInspectOperationRequest(token: _token),
            inspector: const JwtInspector(maxInputBytes: 1),
            kind: FailureKind.resource,
            code: 'jwt-inspect.resource-limit',
            field: 'token',
            reason: 'input-limit',
            messageKey: 'error.jwtInspect.resource',
          ),
        ];

    for (final fixture in fixtures) {
      test(fixture.name, () async {
        final result = await JwtInspectService(inspector: fixture.inspector)
            .execute(fixture.request);

        expect(result, isA<ChimeraFailure<JwtInspectOutput>>());
        final failure = result as ChimeraFailure<JwtInspectOutput>;
        expect(failure.kind, fixture.kind);
        expect(failure.code, fixture.code);
        expect(failure.messageKey, fixture.messageKey);
        expect(failure.details, <String, Object?>{
          'field': fixture.field,
          'reason': fixture.reason,
        });
        final diagnostics = '$failure ${failure.details}';
        expect(diagnostics, isNot(contains('private-token-marker')));
        expect(diagnostics, isNot(contains('private-key-marker')));
        expect(diagnostics, isNot(contains('dependency-marker')));
      });
    }
  });
}

JwtInspectOutput _success(ChimeraResult<JwtInspectOutput> result) =>
    result.fold(
      onSuccess: (output) => output,
      onFailure: (failure) => fail('Unexpected ${failure.code}'),
    );

String _segment(List<int> value) => base64Url.encode(value).replaceAll('=', '');

String _unsignedToken(String header, String claims) =>
    '${_segment(utf8.encode(header))}.${_segment(utf8.encode(claims))}.'
    '${_segment(<int>[1])}';
