import 'dart:convert';

import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenValidRequest_WhenCreated_ThenTokenAndOrderedJsonReturn', () async {
    final request = JwtCreateOperationRequest(
      headerJson: '{}',
      claimsJson: '{"sub":"private-claims-marker"}',
      algorithm: 'HS256',
      key: '0123456789abcdef0123456789abcdef',
    );
    final output = _success(await const JwtCreateService().execute(request));

    expect(output.token.split('.'), hasLength(3));
    expect(output.toJson().keys, <String>['token']);
    expect(jsonEncode(output.toJson()), '{"token":"${output.token}"}');
    expect(request.toString(), isNot(contains('private-claims-marker')));
    expect(request.toString(), isNot(contains('0123456789abcdef')));
    expect(output.toString(), isNot(contains(output.token)));
  });

  test('GivenInjectedSigner_WhenCreated_ThenDelegatesExactlyOnce', () async {
    var calls = 0;
    final service = JwtCreateService(
      creator: JwtCreator.forTesting(
        sign: (header, claims, algorithm, key) {
          calls++;
          expect(header['typ'], 'JWT');
          expect(claims, <String, Object?>{'value': 1});
          expect(algorithm, 'HS256');
          expect(key.keyType, 'oct');
          return 'header.payload.signature';
        },
      ),
    );
    final output = _success(
      await service.execute(
        JwtCreateOperationRequest(
          headerJson: '{}',
          claimsJson: '{"value":1}',
          algorithm: 'HS256',
          key: '0123456789abcdef0123456789abcdef',
        ),
      ),
    );
    expect(calls, 1);
    expect(output.token, 'header.payload.signature');
  });

  group('GivenUtilityFailure_WhenCreated_ThenTypedFailureReturns', () {
    final fixtures =
        <
          ({
            String name,
            JwtCreateOperationRequest request,
            JwtCreator creator,
            FailureKind kind,
            String code,
            String field,
            String reason,
            String messageKey,
          })
        >[
          (
            name: 'InvalidAlgorithm',
            request: JwtCreateOperationRequest(
              headerJson: '{}',
              claimsJson: '{}',
              algorithm: 'none',
              key: 'private-key-marker',
            ),
            creator: const JwtCreator(),
            kind: FailureKind.validation,
            code: 'jwt-create.invalid-algorithm',
            field: 'algorithm',
            reason: 'unsupported-algorithm',
            messageKey: 'error.jwtCreate.validation',
          ),
          (
            name: 'SigningFailure',
            request: JwtCreateOperationRequest(
              headerJson: '{}',
              claimsJson: '{"private":"claims-marker"}',
              algorithm: 'HS256',
              key: '0123456789abcdef0123456789abcdef',
            ),
            creator: JwtCreator.forTesting(
              sign: (_, _, _, _) => throw StateError('dependency-marker'),
            ),
            kind: FailureKind.processing,
            code: 'jwt-create.signing-failed',
            field: 'token',
            reason: 'cryptographic-failure',
            messageKey: 'error.jwtCreate.processing',
          ),
          (
            name: 'ResourceFailure',
            request: JwtCreateOperationRequest(
              headerJson: '{}',
              claimsJson: '{}',
              algorithm: 'HS256',
              key: '0123456789abcdef0123456789abcdef',
            ),
            creator: const JwtCreator(maxInputCharacters: 1),
            kind: FailureKind.resource,
            code: 'jwt-create.resource-limit',
            field: 'header',
            reason: 'input-limit',
            messageKey: 'error.jwtCreate.resource',
          ),
        ];

    for (final fixture in fixtures) {
      test(fixture.name, () async {
        final result = await JwtCreateService(creator: fixture.creator)
            .execute(fixture.request);
        expect(result, isA<ChimeraFailure<JwtCreateOutput>>());
        final failure = result as ChimeraFailure<JwtCreateOutput>;
        expect(failure.kind, fixture.kind);
        expect(failure.code, fixture.code);
        expect(failure.messageKey, fixture.messageKey);
        expect(failure.details, <String, Object?>{
          'field': fixture.field,
          'reason': fixture.reason,
        });
        final diagnostics = '$failure ${failure.details}';
        expect(diagnostics, isNot(contains('private-key-marker')));
        expect(diagnostics, isNot(contains('claims-marker')));
        expect(diagnostics, isNot(contains('dependency-marker')));
      });
    }
  });
}

JwtCreateOutput _success(ChimeraResult<JwtCreateOutput> result) => result.fold(
  onSuccess: (output) => output,
  onFailure: (failure) => fail('Unexpected ${failure.code}'),
);
