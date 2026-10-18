import 'dart:convert';

import 'package:jose/jose.dart';

import 'strict_json_object.dart';

enum JwtCreateFailureKind { validation, processing, resource }

final class JwtCreateRequest {
  const JwtCreateRequest({
    required this.headerJson,
    required this.claimsJson,
    required this.algorithm,
    required this.key,
  });

  final String headerJson;
  final String claimsJson;
  final String algorithm;
  final String key;
}

final class JwtCreateResult {
  const JwtCreateResult({required this.token});

  final String token;
}

final class JwtCreateException implements Exception {
  const JwtCreateException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
  });

  final JwtCreateFailureKind kind;
  final String code;
  final String field;
  final String reason;

  @override
  String toString() => 'JwtCreateException($code, $field, $reason)';
}

typedef JwtSignFunction = String Function(
  Map<String, dynamic> header,
  Map<String, dynamic> claims,
  String algorithm,
  JsonWebKey key,
);

final class JwtCreator {
  const JwtCreator({this.maxInputCharacters, this.maxTokenCharacters})
    : assert(maxInputCharacters == null || maxInputCharacters >= 0),
      assert(maxTokenCharacters == null || maxTokenCharacters >= 0),
      sign = _signWithJose;

  const JwtCreator.forTesting({
    this.maxInputCharacters,
    this.maxTokenCharacters,
    this.sign = _signWithJose,
  }) : assert(maxInputCharacters == null || maxInputCharacters >= 0),
       assert(maxTokenCharacters == null || maxTokenCharacters >= 0);

  static const supportedAlgorithms = <String>{
    'HS256',
    'HS384',
    'HS512',
    'RS256',
    'RS384',
    'RS512',
    'ES256',
    'ES256K',
    'ES384',
    'ES512',
  };

  final int? maxInputCharacters;
  final int? maxTokenCharacters;
  final JwtSignFunction sign;

  JwtCreateResult create(JwtCreateRequest request) {
    _checkBudget('header', request.headerJson);
    _checkBudget('claims', request.claimsJson);
    _checkBudget('algorithm', request.algorithm);
    _checkBudget('key', request.key);

    if (!supportedAlgorithms.contains(request.algorithm)) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.invalid-algorithm',
        field: 'algorithm',
        reason: 'unsupported-algorithm',
      );
    }

    final header = _parseObject(
      request.headerJson,
      field: 'header',
      code: 'jwt-create.invalid-header',
    );
    final claims = _parseObject(
      request.claimsJson,
      field: 'claims',
      code: 'jwt-create.invalid-claims',
    );
    _validateHeader(header, request.algorithm);

    JsonWebKey key;
    try {
      key = _parseKey(request.key, request.algorithm);
    } on JwtCreateException {
      rethrow;
    } on OutOfMemoryError {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.resource,
        code: 'jwt-create.resource-limit',
        field: 'key',
        reason: 'allocation-limit',
      );
    } catch (_) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.invalid-key',
        field: 'key',
        reason: 'malformed-key',
      );
    }
    if (header['kid'] case final Object keyId) {
      if (keyId is! String || (key.keyId != null && key.keyId != keyId)) {
        throw const JwtCreateException(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.incompatible-key',
          field: 'key',
          reason: 'key-id-mismatch',
        );
      }
    }

    try {
      final token = sign(header, claims, request.algorithm, key);
      if (token.split('.').length != 3) {
        throw const FormatException();
      }
      if (maxTokenCharacters case final limit? when token.length > limit) {
        throw const JwtCreateException(
          kind: JwtCreateFailureKind.resource,
          code: 'jwt-create.resource-limit',
          field: 'token',
          reason: 'output-limit',
        );
      }
      return JwtCreateResult(token: token);
    } on JwtCreateException {
      rethrow;
    } on OutOfMemoryError {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.resource,
        code: 'jwt-create.resource-limit',
        field: 'token',
        reason: 'allocation-limit',
      );
    } catch (_) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.processing,
        code: 'jwt-create.signing-failed',
        field: 'token',
        reason: 'cryptographic-failure',
      );
    }
  }

  void _checkBudget(String field, String value) {
    if (maxInputCharacters case final limit? when value.length > limit) {
      throw JwtCreateException(
        kind: JwtCreateFailureKind.resource,
        code: 'jwt-create.resource-limit',
        field: field,
        reason: 'input-limit',
      );
    }
  }

  static Map<String, dynamic> _parseObject(
    String source, {
    required String field,
    required String code,
  }) {
    try {
      return decodeStrictJsonObject(source);
    } on OutOfMemoryError {
      throw JwtCreateException(
        kind: JwtCreateFailureKind.resource,
        code: 'jwt-create.resource-limit',
        field: field,
        reason: 'allocation-limit',
      );
    } on StrictJsonObjectException catch (error) {
      throw JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: code,
        field: field,
        reason: switch (error.failure) {
          StrictJsonObjectFailure.invalidJson => 'invalid-json',
          StrictJsonObjectFailure.objectRequired => 'object-required',
          StrictJsonObjectFailure.invalidUnicode => 'invalid-unicode',
        },
      );
    }
  }

  static void _validateHeader(Map<String, dynamic> header, String algorithm) {
    if (header.containsKey('alg') && header['alg'] != algorithm) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.invalid-header',
        field: 'header',
        reason: 'algorithm-mismatch',
      );
    }
    if (header.containsKey('crit') || header['b64'] == false) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.invalid-header',
        field: 'header',
        reason: 'unsupported-critical-header',
      );
    }
    if (header.keys.any(
      const <String>{'jwk', 'jku', 'x5u', 'x5c', 'x5t', 'x5t#S256'}.contains,
    )) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.invalid-header',
        field: 'header',
        reason: 'unsupported-key-selection-header',
      );
    }
    header.putIfAbsent('typ', () => 'JWT');
  }

  static JsonWebKey _parseKey(String source, String algorithm) {
    final trimmed = source.trim();
    late JsonWebKey key;
    Map<String, dynamic>? jwk;

    if (trimmed.startsWith('{')) {
      final decoded = _parseObject(
        trimmed,
        field: 'key',
        code: 'jwt-create.invalid-key',
      );
      jwk = decoded;
      key = JsonWebKey.fromJson(decoded);
    } else if (algorithm.startsWith('HS')) {
      final bytes = utf8.encode(source);
      try {
        final minimum = switch (algorithm) {
          'HS256' => 32,
          'HS384' => 48,
          'HS512' => 64,
          _ => throw StateError('validated algorithm'),
        };
        if (bytes.length < minimum) {
          throw const JwtCreateException(
            kind: JwtCreateFailureKind.validation,
            code: 'jwt-create.invalid-key',
            field: 'key',
            reason: 'insufficient-key-length',
          );
        }
        key = JsonWebKey.fromJson(<String, dynamic>{
          'kty': 'oct',
          'k': base64Url.encode(bytes).replaceAll('=', ''),
        });
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } else {
      key = JsonWebKey.fromPem(source);
    }

    final expectedType = algorithm.startsWith('HS')
        ? 'oct'
        : algorithm.startsWith('RS')
        ? 'RSA'
        : 'EC';
    if (key.keyType != expectedType || !key.usableForAlgorithm(algorithm)) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.incompatible-key',
        field: 'key',
        reason: 'algorithm-mismatch',
      );
    }
    if (key.publicKeyUse case final use? when use != 'sig') {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.incompatible-key',
        field: 'key',
        reason: 'operation-not-permitted',
      );
    }
    if (key.keyOperations case final operations?
        when !operations.contains('sign')) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.incompatible-key',
        field: 'key',
        reason: 'operation-not-permitted',
      );
    }
    if (!key.usableForOperation('sign')) {
      throw const JwtCreateException(
        kind: JwtCreateFailureKind.validation,
        code: 'jwt-create.incompatible-key',
        field: 'key',
        reason: 'private-key-required',
      );
    }
    if (expectedType == 'oct' && jwk != null) {
      final encoded = jwk['k'];
      if (encoded is! String) {
        throw const JwtCreateException(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.invalid-key',
          field: 'key',
          reason: 'malformed-key',
        );
      }
      final requiredLength = switch (algorithm) {
        'HS256' => 32,
        'HS384' => 48,
        'HS512' => 64,
        _ => 0,
      };
      List<int> bytes;
      try {
        bytes = base64Url.decode(base64Url.normalize(encoded));
      } catch (_) {
        throw const JwtCreateException(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.invalid-key',
          field: 'key',
          reason: 'malformed-key',
        );
      }
      try {
        if (bytes.length < requiredLength) {
          throw const JwtCreateException(
            kind: JwtCreateFailureKind.validation,
            code: 'jwt-create.invalid-key',
            field: 'key',
            reason: 'insufficient-key-length',
          );
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    }
    if (expectedType == 'EC' && jwk != null) {
      final expectedCurve = switch (algorithm) {
        'ES256' => 'P-256',
        'ES256K' => 'P-256K',
        'ES384' => 'P-384',
        'ES512' => 'P-521',
        _ => null,
      };
      if (jwk['crv'] != expectedCurve) {
        throw const JwtCreateException(
          kind: JwtCreateFailureKind.validation,
          code: 'jwt-create.incompatible-key',
          field: 'key',
          reason: 'algorithm-mismatch',
        );
      }
    }
    return key;
  }

  static String _signWithJose(
    Map<String, dynamic> header,
    Map<String, dynamic> claims,
    String algorithm,
    JsonWebKey key,
  ) {
    final builder = JsonWebSignatureBuilder()..jsonContent = claims;
    for (final entry in header.entries) {
      builder.setProtectedHeader(entry.key, entry.value);
    }
    builder.addRecipient(key, algorithm: algorithm);
    return builder.build().toCompactSerialization();
  }
}
