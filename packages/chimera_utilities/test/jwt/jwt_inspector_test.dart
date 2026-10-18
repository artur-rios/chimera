import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:jose/jose.dart';
import 'package:test/test.dart';

const _secret = '0123456789abcdef0123456789abcdef';
const _knownToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJzdWIiOiIxMjM0NTY3ODkwIiwiYWRtaW4iOnRydWV9.'
    'GpegCaZaV8lAuGeXX71D9MjJFAI6MUSoLLD2JD3e8Qs';

void main() {
  group('JwtInspector results', () {
    const inspector = JwtInspector();

    test('GivenSignedTokenWithoutKey_WhenInspected_ThenDecodedOnlyReturns', () {
      final result = inspector.inspect(
        const JwtInspectRequest(token: _knownToken),
      );

      expect(result.header, <String, Object?>{'alg': 'HS256', 'typ': 'JWT'});
      expect(result.claims, <String, Object?>{
        'sub': '1234567890',
        'admin': true,
      });
      expect(result.verification, JwtVerificationStatus.notRequested);
    });

    test('GivenKnownHs256TokenAndKey_WhenInspected_ThenVerifiedReturns', () {
      final result = inspector.inspect(
        const JwtInspectRequest(token: _knownToken, key: _secret),
      );

      expect(result.verification, JwtVerificationStatus.verified);
    });

    test(
      'GivenWrongSignature_WhenInspected_ThenParsedUntrustedResultReturns',
      () {
        final parts = _knownToken.split('.');
        final token =
            '${parts[0]}.${parts[1]}.${_bytesSegment(List<int>.filled(32, 0))}';

        final result = inspector.inspect(
          JwtInspectRequest(token: token, key: _secret),
        );

        expect(result.header['alg'], 'HS256');
        expect(result.claims['sub'], '1234567890');
        expect(result.verification, JwtVerificationStatus.failed);
      },
    );

    test(
      'GivenEverySupportedAlgorithm_WhenInspected_ThenSignatureVerifies',
      () {
        for (final algorithm in JwtInspector.supportedAlgorithms) {
          final key = JsonWebKey.generate(algorithm);
          final token = const JwtCreator()
              .create(
                JwtCreateRequest(
                  headerJson: '{}',
                  claimsJson: '{"algorithm":"$algorithm"}',
                  algorithm: algorithm,
                  key: jsonEncode(key),
                ),
              )
              .token;

          final result = inspector.inspect(
            JwtInspectRequest(token: token, key: jsonEncode(key)),
          );

          expect(result.claims, <String, Object?>{'algorithm': algorithm});
          expect(result.verification, JwtVerificationStatus.verified);
        }
      },
    );

    test('GivenTokenKidAndUnlabelledKey_WhenInspected_ThenKeyIsAccepted', () {
      final token = const JwtCreator()
          .create(
            const JwtCreateRequest(
              headerJson: '{"kid":"rotation-1"}',
              claimsJson: '{}',
              algorithm: 'HS256',
              key: _secret,
            ),
          )
          .token;

      final result = inspector.inspect(
        JwtInspectRequest(token: token, key: _octJwk()),
      );

      expect(result.verification, JwtVerificationStatus.verified);
    });

    test(
      'GivenMutableVerificationCopies_WhenInspected_ThenCopiesAreCleared',
      () {
        List<int>? capturedInput;
        List<int>? capturedSignature;
        final inspector = JwtInspector.forTesting(
          verify: (input, signature, _, _) {
            capturedInput = input;
            capturedSignature = signature;
            return true;
          },
        );

        final result = inspector.inspect(
          const JwtInspectRequest(token: _knownToken, key: _secret),
        );

        expect(result.verification, JwtVerificationStatus.verified);
        expect(capturedInput, isNotEmpty);
        expect(capturedSignature, isNotEmpty);
        expect(capturedInput, everyElement(0));
        expect(capturedSignature, everyElement(0));
      },
    );
  });

  group('JwtInspector token validation', () {
    const inspector = JwtInspector();

    for (final token in <String>[
      '',
      'a.b',
      'a.b.c.d',
      '.b.c',
      'a..c',
      'a.b.',
    ]) {
      test(
        'GivenMalformedStructure${token.length}_WhenInspected_ThenTokenFails',
        () {
          expect(
            () => inspector.inspect(JwtInspectRequest(token: token)),
            _failure(
              kind: JwtInspectFailureKind.validation,
              code: 'jwt-inspect.invalid-token',
              field: 'token',
              reason: 'malformed-structure',
            ),
          );
        },
      );
    }

    test('GivenPaddedSegment_WhenInspected_ThenEncodingFails', () {
      final parts = _knownToken.split('.');
      expect(
        () => inspector.inspect(
          JwtInspectRequest(token: '${parts[0]}=.${parts[1]}.${parts[2]}'),
        ),
        _failure(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.invalid-token',
          field: 'token',
          reason: 'invalid-encoding',
        ),
      );
    });

    for (final fixture in <({String name, String header, String claims})>[
      (name: 'HeaderScalar', header: '[]', claims: '{}'),
      (name: 'ClaimsScalar', header: '{"alg":"HS256"}', claims: 'null'),
      (
        name: 'DuplicateHeader',
        header: '{"alg":"HS256","\\u0061lg":"HS256"}',
        claims: '{}',
      ),
      (
        name: 'NestedDuplicateClaims',
        header: '{"alg":"HS256"}',
        claims: '{"profile":{"role":"user","role":"admin"}}',
      ),
    ]) {
      test('Given${fixture.name}_WhenInspected_ThenJsonFails', () {
        expect(
          () => inspector.inspect(
            JwtInspectRequest(
              token: _unsignedToken(fixture.header, fixture.claims),
            ),
          ),
          throwsA(
            isA<JwtInspectException>()
                .having(
                  (error) => error.code,
                  'code',
                  'jwt-inspect.invalid-token',
                )
                .having(
                  (error) => error.reason,
                  'reason',
                  fixture.name.endsWith('Scalar')
                      ? 'object-required'
                      : 'invalid-json',
                ),
          ),
        );
      });
    }

    for (final header in <String>[
      '{}',
      '{"alg":null}',
      '{"alg":"none"}',
      '{"alg":"PS256"}',
    ]) {
      test(
        'GivenUnsupportedHeader${header.length}_WhenInspected_ThenAlgorithmFails',
        () {
          expect(
            () => inspector.inspect(
              JwtInspectRequest(token: _unsignedToken(header, '{}')),
            ),
            _failure(
              kind: JwtInspectFailureKind.validation,
              code: 'jwt-inspect.unsupported-algorithm',
              field: 'token',
              reason: 'unsupported-algorithm',
            ),
          );
        },
      );
    }

    for (final name in <String>{
      'crit',
      'jwk',
      'jku',
      'x5u',
      'x5c',
      'x5t',
      'x5t#S256',
    }) {
      test('GivenProtected${name}Header_WhenInspected_ThenHeaderFails', () {
        final value = name == 'crit' ? <String>['private'] : 'private-marker';
        expect(
          () => inspector.inspect(
            JwtInspectRequest(
              token: _unsignedToken(
                jsonEncode(<String, Object?>{'alg': 'HS256', name: value}),
                '{}',
              ),
            ),
          ),
          _failure(
            kind: JwtInspectFailureKind.validation,
            code: 'jwt-inspect.invalid-token',
            field: 'token',
            reason: name == 'crit'
                ? 'unsupported-critical-header'
                : 'unsupported-key-selection-header',
          ),
        );
      });
    }

    test('GivenDetachedPayloadHeader_WhenInspected_ThenHeaderFails', () {
      expect(
        () => inspector.inspect(
          JwtInspectRequest(
            token: _unsignedToken('{"alg":"HS256","b64":false}', '{}'),
          ),
        ),
        _failure(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.invalid-token',
          field: 'token',
          reason: 'unsupported-critical-header',
        ),
      );
    });
  });

  group('JwtInspector key validation', () {
    const inspector = JwtInspector();

    test('GivenWeakRawHmacKey_WhenInspected_ThenKeyFails', () {
      expect(
        () => inspector.inspect(
          const JwtInspectRequest(token: _knownToken, key: 'too-short'),
        ),
        _failure(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.invalid-key',
          field: 'key',
          reason: 'insufficient-key-length',
        ),
      );
    });

    for (final fixture
        in <({String name, Map<String, Object?> changes, String reason})>[
          (
            name: 'WrongAlgorithm',
            changes: <String, Object?>{'alg': 'HS512'},
            reason: 'algorithm-mismatch',
          ),
          (
            name: 'EncryptionUse',
            changes: <String, Object?>{'use': 'enc'},
            reason: 'operation-not-permitted',
          ),
          (
            name: 'SignOnlyOperations',
            changes: <String, Object?>{
              'key_ops': <String>['sign'],
            },
            reason: 'operation-not-permitted',
          ),
        ]) {
      test('Given${fixture.name}Jwk_WhenInspected_ThenCompatibilityFails', () {
        expect(
          () => inspector.inspect(
            JwtInspectRequest(
              token: _knownToken,
              key: _octJwk(changes: fixture.changes),
            ),
          ),
          _failure(
            kind: JwtInspectFailureKind.validation,
            code: 'jwt-inspect.incompatible-key',
            field: 'key',
            reason: fixture.reason,
          ),
        );
      });
    }

    test('GivenConflictingKeyIds_WhenInspected_ThenCompatibilityFails', () {
      final token = const JwtCreator()
          .create(
            const JwtCreateRequest(
              headerJson: '{"kid":"expected"}',
              claimsJson: '{}',
              algorithm: 'HS256',
              key: _secret,
            ),
          )
          .token;
      expect(
        () => inspector.inspect(
          JwtInspectRequest(
            token: token,
            key: _octJwk(changes: const <String, Object?>{'kid': 'other'}),
          ),
        ),
        _failure(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.incompatible-key',
          field: 'key',
          reason: 'key-id-mismatch',
        ),
      );
    });

    test('GivenWrongKeyFamily_WhenInspected_ThenCompatibilityFails', () {
      final rsaKey = JsonWebKey.generate('RS256');
      expect(
        () => inspector.inspect(
          JwtInspectRequest(token: _knownToken, key: jsonEncode(rsaKey)),
        ),
        _failure(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.incompatible-key',
          field: 'key',
          reason: 'algorithm-mismatch',
        ),
      );
    });

    test('GivenDuplicateNestedJwkMember_WhenInspected_ThenKeyFails', () {
      expect(
        () => inspector.inspect(
          const JwtInspectRequest(
            token: _knownToken,
            key:
                '{"kty":"oct","k":"MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY",'
                '"meta":{"owner":"first","owner":"second"}}',
          ),
        ),
        _failure(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.invalid-key',
          field: 'key',
          reason: 'invalid-json',
        ),
      );
    });
  });

  group('JwtInspector failures', () {
    test('GivenInputBudgetExceeded_WhenInspected_ThenResourceFails', () {
      expect(
        () =>
            const JwtInspector(maxInputCharacters: 1)
                .inspect(const JwtInspectRequest(token: _knownToken)),
        _failure(
          kind: JwtInspectFailureKind.resource,
          code: 'jwt-inspect.resource-limit',
          field: 'token',
          reason: 'input-limit',
        ),
      );
    });

    test('GivenDecodedBudgetExceeded_WhenInspected_ThenResourceFails', () {
      expect(
        () =>
            const JwtInspector(maxDecodedBytes: 1)
                .inspect(const JwtInspectRequest(token: _knownToken)),
        _failure(
          kind: JwtInspectFailureKind.resource,
          code: 'jwt-inspect.resource-limit',
          field: 'token',
          reason: 'decoded-limit',
        ),
      );
    });

    test(
      'GivenVerificationDependencyFailure_WhenInspected_ThenProcessingFails',
      () {
        final inspector = JwtInspector.forTesting(
          verify: (_, _, _, _) => throw StateError('private-dependency-marker'),
        );
        expect(
          () => inspector.inspect(
            const JwtInspectRequest(token: _knownToken, key: _secret),
          ),
          _failure(
            kind: JwtInspectFailureKind.processing,
            code: 'jwt-inspect.verification-failed',
            field: 'token',
            reason: 'cryptographic-failure',
          ),
        );
      },
    );

    test('GivenAllocationFailure_WhenInspected_ThenResourceFails', () {
      final inspector = JwtInspector.forTesting(
        verify: (_, _, _, _) => throw OutOfMemoryError(),
      );
      expect(
        () => inspector.inspect(
          const JwtInspectRequest(token: _knownToken, key: _secret),
        ),
        _failure(
          kind: JwtInspectFailureKind.resource,
          code: 'jwt-inspect.resource-limit',
          field: 'token',
          reason: 'allocation-limit',
        ),
      );
    });

    test('GivenPrivateInputs_WhenFailureReturns_ThenDiagnosticIsRedacted', () {
      final privateToken = _unsignedToken(
        '{"alg":"HS256"}',
        '{"secret":"private-claims-marker"}',
      );
      try {
        const JwtInspector().inspect(
          JwtInspectRequest(token: privateToken, key: 'private-key-marker'),
        );
        fail('Expected key failure');
      } on JwtInspectException catch (error) {
        final text =
            '${error.kind} ${error.code} ${error.field} '
            '${error.reason} $error';
        expect(text, isNot(contains('private-claims-marker')));
        expect(text, isNot(contains('private-key-marker')));
      }
    });
  });
}

String _unsignedToken(String header, String claims) =>
    '${_textSegment(header)}.${_textSegment(claims)}.${_bytesSegment(<int>[1])}';

String _textSegment(String value) => _bytesSegment(utf8.encode(value));

String _bytesSegment(List<int> value) =>
    base64Url.encode(value).replaceAll('=', '');

String _octJwk({Map<String, Object?> changes = const <String, Object?>{}}) {
  final value = <String, Object?>{
    'kty': 'oct',
    'k': _bytesSegment(utf8.encode(_secret)),
    ...changes,
  };
  return jsonEncode(value);
}

Matcher _failure({
  required JwtInspectFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<JwtInspectException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
