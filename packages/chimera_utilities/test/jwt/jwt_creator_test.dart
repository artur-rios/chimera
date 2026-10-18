import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:jose/jose.dart';
import 'package:test/test.dart';

void main() {
  group('JwtCreator signing', () {
    const creator = JwtCreator();

    test('GivenHs256Inputs_WhenCreated_ThenKnownCompactJwtReturns', () {
      final result = creator.create(
        const JwtCreateRequest(
          headerJson: '{}',
          claimsJson: '{"sub":"1234567890","admin":true}',
          algorithm: 'HS256',
          key: '0123456789abcdef0123456789abcdef',
        ),
      );

      expect(
        result.token,
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJzdWIiOiIxMjM0NTY3ODkwIiwiYWRtaW4iOnRydWV9.'
        'GpegCaZaV8lAuGeXX71D9MjJFAI6MUSoLLD2JD3e8Qs',
      );
    });

    test('GivenOctJwkAndHeader_WhenCreated_ThenTokenVerifies', () async {
      final keyBytes = utf8.encode('0123456789abcdef0123456789abcdef');
      final key = <String, Object?>{
        'kty': 'oct',
        'k': base64Url.encode(keyBytes).replaceAll('=', ''),
        'use': 'sig',
        'key_ops': <String>['sign', 'verify'],
        'alg': 'HS256',
        'kid': 'local-key',
      };
      final result = creator.create(
        JwtCreateRequest(
          headerJson: '{"kid":"local-key","typ":"at+jwt"}',
          claimsJson: '{"scope":"read","exp":1893456000}',
          algorithm: 'HS256',
          key: jsonEncode(key),
        ),
      );
      final jws = JsonWebSignature.fromCompactSerialization(result.token);
      final keyStore = JsonWebKeyStore()..addKey(JsonWebKey.fromJson(key));
      expect(await jws.getPayload(keyStore), isNotNull);
      expect(jws.unverifiedPayload.jsonContent, <String, Object?>{
        'scope': 'read',
        'exp': 1893456000,
      });
      expect(jws.commonHeader.algorithm, 'HS256');
      expect(jws.commonHeader['kid'], 'local-key');
      expect(jws.commonHeader['typ'], 'at+jwt');
    });

    test('GivenRepeatedCalls_WhenCreated_ThenRequestsRemainIndependent', () {
      final first = creator.create(
        const JwtCreateRequest(
          headerJson: '{}',
          claimsJson: '{"value":1}',
          algorithm: 'HS256',
          key: '0123456789abcdef0123456789abcdef',
        ),
      );
      final second = creator.create(
        const JwtCreateRequest(
          headerJson: '{}',
          claimsJson: '{"value":2}',
          algorithm: 'HS256',
          key: 'fedcba9876543210fedcba9876543210',
        ),
      );
      expect(first.token, isNot(second.token));
    });

    test(
      'GivenEverySupportedAlgorithm_WhenCreated_ThenTokenVerifies',
      () async {
        for (final algorithm in JwtCreator.supportedAlgorithms) {
          final key = JsonWebKey.generate(algorithm);
          final result = creator.create(
            JwtCreateRequest(
              headerJson: '{}',
              claimsJson: '{"algorithm":"$algorithm"}',
              algorithm: algorithm,
              key: jsonEncode(key),
            ),
          );
          final keyStore = JsonWebKeyStore()..addKey(key);
          final payload = await JsonWebSignature.fromCompactSerialization(
            result.token,
          ).getPayload(keyStore, allowedAlgorithms: <String>[algorithm]);
          expect(payload.jsonContent, <String, Object?>{
            'algorithm': algorithm,
          });
        }
      },
    );
  });

  group('JwtCreator validation', () {
    const creator = JwtCreator();

    for (final algorithm in <String>['', 'none', 'hs256', 'PS256', 'private']) {
      test('GivenUnsupported${algorithm}_WhenCreated_ThenAlgorithmFails', () {
        expect(
          () => creator.create(
            JwtCreateRequest(
              headerJson: '{}',
              claimsJson: '{}',
              algorithm: algorithm,
              key: 'private-key-marker-private-key',
            ),
          ),
          _failure(
            kind: JwtCreateFailureKind.validation,
            code: 'jwt-create.invalid-algorithm',
            field: 'algorithm',
            reason: 'unsupported-algorithm',
          ),
        );
      });
    }

    for (final entry in <String, String>{
      '[]': 'object-required',
      'null': 'object-required',
      '{': 'invalid-json',
    }.entries) {
      test('GivenInvalidHeader${entry.key}_WhenCreated_ThenHeaderFails', () {
        expect(
          () => creator.create(
            JwtCreateRequest(
              headerJson: entry.key,
              claimsJson: '{}',
              algorithm: 'HS256',
              key: '0123456789abcdef0123456789abcdef',
            ),
          ),
          _failure(
            kind: JwtCreateFailureKind.validation,
            code: 'jwt-create.invalid-header',
            field: 'header',
            reason: entry.value,
          ),
        );
      });
    }

    test('GivenMismatchedHeaderAlgorithm_WhenCreated_ThenHeaderFails', () {
      expect(
        () => creator.create(
          const JwtCreateRequest(
            headerJson: '{"alg":"HS512"}',
            claimsJson: '{}',
            algorithm: 'HS256',
            key: '0123456789abcdef0123456789abcdef',
          ),
        ),
        _failure(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.invalid-header',
          field: 'header',
          reason: 'algorithm-mismatch',
        ),
      );
    });

    for (final fixture in <({String name, String header, String claims})>[
      (
        name: 'Header',
        header: '{"alg":"HS256","\\u0061lg":"HS256"}',
        claims: '{}',
      ),
      (
        name: 'NestedClaims',
        header: '{}',
        claims: '{"profile":{"role":"user","role":"admin"}}',
      ),
    ]) {
      test('GivenDuplicate${fixture.name}Member_WhenCreated_ThenJsonFails', () {
        expect(
          () => creator.create(
            JwtCreateRequest(
              headerJson: fixture.header,
              claimsJson: fixture.claims,
              algorithm: 'HS256',
              key: '0123456789abcdef0123456789abcdef',
            ),
          ),
          throwsA(
            isA<JwtCreateException>()
                .having(
                  (error) => error.code,
                  'code',
                  fixture.name == 'Header'
                      ? 'jwt-create.invalid-header'
                      : 'jwt-create.invalid-claims',
                )
                .having((error) => error.reason, 'reason', 'invalid-json'),
          ),
        );
      });
    }

    for (final name in <String>{
      'jwk',
      'jku',
      'x5u',
      'x5c',
      'x5t',
      'x5t#S256',
    }) {
      test('GivenProtected${name}Header_WhenCreated_ThenHeaderFails', () {
        expect(
          () => creator.create(
            JwtCreateRequest(
              headerJson: jsonEncode(<String, Object?>{name: 'private-marker'}),
              claimsJson: '{}',
              algorithm: 'HS256',
              key: '0123456789abcdef0123456789abcdef',
            ),
          ),
          _failure(
            kind: JwtCreateFailureKind.validation,
            code: 'jwt-create.invalid-header',
            field: 'header',
            reason: 'unsupported-key-selection-header',
          ),
        );
      });
    }

    for (final claims in <String>['[]', 'null', 'true', '"private"', '{']) {
      test('GivenInvalidClaims${claims}_WhenCreated_ThenClaimsFail', () {
        expect(
          () => creator.create(
            JwtCreateRequest(
              headerJson: '{}',
              claimsJson: claims,
              algorithm: 'HS256',
              key: '0123456789abcdef0123456789abcdef',
            ),
          ),
          throwsA(
            isA<JwtCreateException>()
                .having(
                  (error) => error.code,
                  'code',
                  'jwt-create.invalid-claims',
                )
                .having((error) => error.field, 'field', 'claims'),
          ),
        );
      });
    }

    test('GivenWeakHmacKey_WhenCreated_ThenKeyFails', () {
      expect(
        () => creator.create(
          const JwtCreateRequest(
            headerJson: '{}',
            claimsJson: '{}',
            algorithm: 'HS256',
            key: 'too-short-private-marker',
          ),
        ),
        _failure(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.invalid-key',
          field: 'key',
          reason: 'insufficient-key-length',
        ),
      );
    });

    test('GivenDuplicateNestedJwkMember_WhenCreated_ThenKeyFails', () {
      expect(
        () => creator.create(
          const JwtCreateRequest(
            headerJson: '{}',
            claimsJson: '{}',
            algorithm: 'HS256',
            key:
                '{"kty":"oct","k":"MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY",'
                '"meta":{"owner":"first","owner":"second"}}',
          ),
        ),
        _failure(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.invalid-key',
          field: 'key',
          reason: 'invalid-json',
        ),
      );
    });

    test('GivenWrongKeyFamily_WhenCreated_ThenCompatibilityFails', () {
      final key = base64Url
          .encode(utf8.encode('0123456789abcdef0123456789abcdef'))
          .replaceAll('=', '');
      expect(
        () => creator.create(
          JwtCreateRequest(
            headerJson: '{}',
            claimsJson: '{}',
            algorithm: 'RS256',
            key: '{"kty":"oct","k":"$key"}',
          ),
        ),
        _failure(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.incompatible-key',
          field: 'key',
          reason: 'algorithm-mismatch',
        ),
      );
    });

    test('GivenPublicOnlyKey_WhenCreated_ThenPrivateKeyFails', () {
      final privateKey = JsonWebKey.generate('RS256');
      final publicKey = Map<String, dynamic>.of(privateKey.toJson())
        ..removeWhere(
          (key, _) => <String>{'d', 'p', 'q', 'dp', 'dq', 'qi'}.contains(key),
        );
      expect(
        () => creator.create(
          JwtCreateRequest(
            headerJson: '{}',
            claimsJson: '{}',
            algorithm: 'RS256',
            key: jsonEncode(publicKey),
          ),
        ),
        _failure(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.incompatible-key',
          field: 'key',
          reason: 'private-key-required',
        ),
      );
    });

    test('GivenPrivateInputs_WhenValidationFails_ThenErrorIsRedacted', () {
      try {
        creator.create(
          const JwtCreateRequest(
            headerJson: '{}',
            claimsJson: '{"secret":"private-claims-marker"}',
            algorithm: 'HS256',
            key: 'private-key-marker',
          ),
        );
        fail('Expected key failure');
      } on JwtCreateException catch (error) {
        final text =
            '${error.kind} ${error.code} ${error.field} '
            '${error.reason} $error';
        expect(text, isNot(contains('private-claims-marker')));
        expect(text, isNot(contains('private-key-marker')));
      }
    });
  });

  group('JwtCreator failures', () {
    test('GivenInputBudgetExceeded_WhenCreated_ThenResourceFails', () {
      expect(
        () => const JwtCreator(maxInputCharacters: 1).create(
          const JwtCreateRequest(
            headerJson: '{}',
            claimsJson: '{}',
            algorithm: 'HS256',
            key: '0123456789abcdef0123456789abcdef',
          ),
        ),
        _failure(
          kind: JwtCreateFailureKind.resource,
          code: 'jwt-create.resource-limit',
          field: 'header',
          reason: 'input-limit',
        ),
      );
    });

    test('GivenSigningFailure_WhenCreated_ThenProcessingFails', () {
      final creator = JwtCreator.forTesting(
        sign: (_, _, _, _) => throw StateError('private-dependency-marker'),
      );
      expect(
        () => creator.create(
          const JwtCreateRequest(
            headerJson: '{}',
            claimsJson: '{}',
            algorithm: 'HS256',
            key: '0123456789abcdef0123456789abcdef',
          ),
        ),
        _failure(
          kind: JwtCreateFailureKind.processing,
          code: 'jwt-create.signing-failed',
          field: 'token',
          reason: 'cryptographic-failure',
        ),
      );
    });

    test('GivenAllocationFailure_WhenCreated_ThenResourceFails', () {
      final creator = JwtCreator.forTesting(
        sign: (_, _, _, _) => throw OutOfMemoryError(),
      );
      expect(
        () => creator.create(
          const JwtCreateRequest(
            headerJson: '{}',
            claimsJson: '{}',
            algorithm: 'HS256',
            key: '0123456789abcdef0123456789abcdef',
          ),
        ),
        _failure(
          kind: JwtCreateFailureKind.resource,
          code: 'jwt-create.resource-limit',
          field: 'token',
          reason: 'allocation-limit',
        ),
      );
    });
  });
}

Matcher _failure({
  required JwtCreateFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<JwtCreateException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
