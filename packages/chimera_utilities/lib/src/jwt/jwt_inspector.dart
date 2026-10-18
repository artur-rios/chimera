import 'dart:convert';

import 'package:jose/jose.dart';

import 'jwt_creator.dart';
import 'strict_json_object.dart';

enum JwtInspectFailureKind { validation, processing, resource }

enum JwtVerificationStatus { notRequested, verified, failed }

final class JwtInspectRequest {
  const JwtInspectRequest({required this.token, this.key});

  final String token;
  final String? key;
}

final class JwtInspectResult {
  JwtInspectResult({
    required Map<String, dynamic> header,
    required Map<String, dynamic> claims,
    required this.verification,
  }) : header = Map<String, Object?>.unmodifiable(header),
       claims = Map<String, Object?>.unmodifiable(claims);

  final Map<String, Object?> header;
  final Map<String, Object?> claims;
  final JwtVerificationStatus verification;
}

final class JwtInspectException implements Exception {
  const JwtInspectException({
    required this.kind,
    required this.code,
    required this.field,
    required this.reason,
  });

  final JwtInspectFailureKind kind;
  final String code;
  final String field;
  final String reason;

  @override
  String toString() => 'JwtInspectException($code, $field, $reason)';
}

typedef JwtVerifyFunction = bool Function(
  List<int> signingInput,
  List<int> signature,
  String algorithm,
  JsonWebKey key,
);

final class JwtInspector {
  const JwtInspector({this.maxInputCharacters, this.maxDecodedBytes})
    : assert(maxInputCharacters == null || maxInputCharacters >= 0),
      assert(maxDecodedBytes == null || maxDecodedBytes >= 0),
      verify = _verifyWithJose;

  const JwtInspector.forTesting({
    this.maxInputCharacters,
    this.maxDecodedBytes,
    this.verify = _verifyWithJose,
  }) : assert(maxInputCharacters == null || maxInputCharacters >= 0),
       assert(maxDecodedBytes == null || maxDecodedBytes >= 0);

  static const supportedAlgorithms = JwtCreator.supportedAlgorithms;

  final int? maxInputCharacters;
  final int? maxDecodedBytes;
  final JwtVerifyFunction verify;

  JwtInspectResult inspect(JwtInspectRequest request) {
    _checkInputBudget('token', request.token);
    if (request.key case final key?) _checkInputBudget('key', key);

    final parts = request.token.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-token',
        field: 'token',
        reason: 'malformed-structure',
      );
    }

    List<int>? headerBytes;
    List<int>? claimsBytes;
    List<int>? signatureBytes;
    List<int>? signingInput;
    try {
      headerBytes = _decodeSegment(parts[0]);
      claimsBytes = _decodeSegment(parts[1]);
      signatureBytes = _decodeSegment(parts[2]);
      if (signatureBytes.isEmpty) {
        throw const JwtInspectException(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.invalid-token',
          field: 'token',
          reason: 'malformed-structure',
        );
      }
      _checkDecodedBudget(
        headerBytes.length + claimsBytes.length + signatureBytes.length,
      );

      final header = _decodeObject(headerBytes);
      final claims = _decodeObject(claimsBytes);
      final algorithm = _validateHeader(header);

      if (request.key == null) {
        return JwtInspectResult(
          header: header,
          claims: claims,
          verification: JwtVerificationStatus.notRequested,
        );
      }

      final key = _parseKey(request.key!, algorithm, header);
      signingInput = utf8.encode('${parts[0]}.${parts[1]}');
      bool verified;
      try {
        verified = verify(signingInput, signatureBytes, algorithm, key);
      } on OutOfMemoryError {
        throw const JwtInspectException(
          kind: JwtInspectFailureKind.resource,
          code: 'jwt-inspect.resource-limit',
          field: 'token',
          reason: 'allocation-limit',
        );
      } catch (_) {
        throw const JwtInspectException(
          kind: JwtInspectFailureKind.processing,
          code: 'jwt-inspect.verification-failed',
          field: 'token',
          reason: 'cryptographic-failure',
        );
      }
      return JwtInspectResult(
        header: header,
        claims: claims,
        verification: verified
            ? JwtVerificationStatus.verified
            : JwtVerificationStatus.failed,
      );
    } on JwtInspectException {
      rethrow;
    } on OutOfMemoryError {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.resource,
        code: 'jwt-inspect.resource-limit',
        field: 'token',
        reason: 'allocation-limit',
      );
    } finally {
      headerBytes?.fillRange(0, headerBytes.length, 0);
      claimsBytes?.fillRange(0, claimsBytes.length, 0);
      signatureBytes?.fillRange(0, signatureBytes.length, 0);
      signingInput?.fillRange(0, signingInput.length, 0);
    }
  }

  void _checkInputBudget(String field, String value) {
    if (maxInputCharacters case final limit? when value.length > limit) {
      throw JwtInspectException(
        kind: JwtInspectFailureKind.resource,
        code: 'jwt-inspect.resource-limit',
        field: field,
        reason: 'input-limit',
      );
    }
  }

  void _checkDecodedBudget(int length) {
    if (maxDecodedBytes case final limit? when length > limit) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.resource,
        code: 'jwt-inspect.resource-limit',
        field: 'token',
        reason: 'decoded-limit',
      );
    }
  }

  static List<int> _decodeSegment(String segment) {
    if (segment.contains('=') ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segment)) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-token',
        field: 'token',
        reason: 'invalid-encoding',
      );
    }
    try {
      final bytes = base64Url.decode(base64Url.normalize(segment));
      if (base64Url.encode(bytes).replaceAll('=', '') != segment) {
        bytes.fillRange(0, bytes.length, 0);
        throw const FormatException();
      }
      return bytes;
    } on JwtInspectException {
      rethrow;
    } on OutOfMemoryError {
      rethrow;
    } catch (_) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-token',
        field: 'token',
        reason: 'invalid-encoding',
      );
    }
  }

  static Map<String, dynamic> _decodeObject(List<int> bytes) {
    try {
      return decodeStrictJsonObject(utf8.decode(bytes));
    } on StrictJsonObjectException catch (error) {
      throw JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-token',
        field: 'token',
        reason: _strictReason(error.failure),
      );
    } on FormatException {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-token',
        field: 'token',
        reason: 'invalid-encoding',
      );
    }
  }

  static String _validateHeader(Map<String, dynamic> header) {
    final algorithm = header['alg'];
    if (algorithm is! String || !supportedAlgorithms.contains(algorithm)) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.unsupported-algorithm',
        field: 'token',
        reason: 'unsupported-algorithm',
      );
    }
    if (header.containsKey('crit') || header['b64'] == false) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-token',
        field: 'token',
        reason: 'unsupported-critical-header',
      );
    }
    if (header.keys.any(
      const <String>{'jwk', 'jku', 'x5u', 'x5c', 'x5t', 'x5t#S256'}.contains,
    )) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-token',
        field: 'token',
        reason: 'unsupported-key-selection-header',
      );
    }
    if (header.containsKey('kid') && header['kid'] is! String) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-token',
        field: 'token',
        reason: 'invalid-key-id',
      );
    }
    return algorithm;
  }

  static JsonWebKey _parseKey(
    String source,
    String algorithm,
    Map<String, dynamic> header,
  ) {
    final trimmed = source.trim();
    late JsonWebKey key;
    Map<String, dynamic>? jwk;
    try {
      if (trimmed.startsWith('{')) {
        jwk = decodeStrictJsonObject(trimmed);
        key = JsonWebKey.fromJson(jwk);
      } else if (algorithm.startsWith('HS')) {
        final bytes = utf8.encode(source);
        try {
          if (bytes.length < _minimumHmacLength(algorithm)) {
            throw const JwtInspectException(
              kind: JwtInspectFailureKind.validation,
              code: 'jwt-inspect.invalid-key',
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
        if (trimmed.startsWith('-----BEGIN RSA PUBLIC KEY-----') ||
            trimmed.startsWith('-----BEGIN ENCRYPTED PRIVATE KEY-----')) {
          throw const JwtInspectException(
            kind: JwtInspectFailureKind.validation,
            code: 'jwt-inspect.invalid-key',
            field: 'key',
            reason: 'unsupported-pem-format',
          );
        }
        key = JsonWebKey.fromPem(source);
      }
    } on JwtInspectException {
      rethrow;
    } on StrictJsonObjectException catch (error) {
      throw JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-key',
        field: 'key',
        reason: _strictReason(error.failure),
      );
    } on OutOfMemoryError {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.resource,
        code: 'jwt-inspect.resource-limit',
        field: 'key',
        reason: 'allocation-limit',
      );
    } catch (_) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.invalid-key',
        field: 'key',
        reason: 'malformed-key',
      );
    }

    final expectedType = algorithm.startsWith('HS')
        ? 'oct'
        : algorithm.startsWith('RS')
        ? 'RSA'
        : 'EC';
    if (key.keyType != expectedType || !key.usableForAlgorithm(algorithm)) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.incompatible-key',
        field: 'key',
        reason: 'algorithm-mismatch',
      );
    }
    if (key.publicKeyUse case final use? when use != 'sig') {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.incompatible-key',
        field: 'key',
        reason: 'operation-not-permitted',
      );
    }
    if (key.keyOperations case final operations?
        when !operations.contains('verify')) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.incompatible-key',
        field: 'key',
        reason: 'operation-not-permitted',
      );
    }
    if (!key.usableForOperation('verify')) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.incompatible-key',
        field: 'key',
        reason: 'operation-not-permitted',
      );
    }
    if (header['kid'] case final String tokenKeyId
        when key.keyId != null && key.keyId != tokenKeyId) {
      throw const JwtInspectException(
        kind: JwtInspectFailureKind.validation,
        code: 'jwt-inspect.incompatible-key',
        field: 'key',
        reason: 'key-id-mismatch',
      );
    }
    if (expectedType == 'oct' && jwk != null) {
      final encoded = jwk['k'];
      if (encoded is! String) {
        throw const JwtInspectException(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.invalid-key',
          field: 'key',
          reason: 'malformed-key',
        );
      }
      List<int> bytes;
      try {
        bytes = base64Url.decode(base64Url.normalize(encoded));
      } catch (_) {
        throw const JwtInspectException(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.invalid-key',
          field: 'key',
          reason: 'malformed-key',
        );
      }
      try {
        if (bytes.length < _minimumHmacLength(algorithm)) {
          throw const JwtInspectException(
            kind: JwtInspectFailureKind.validation,
            code: 'jwt-inspect.invalid-key',
            field: 'key',
            reason: 'insufficient-key-length',
          );
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    }
    if (expectedType == 'EC') {
      final expectedCurve = switch (algorithm) {
        'ES256' => 'P-256',
        'ES256K' => 'P-256K',
        'ES384' => 'P-384',
        'ES512' => 'P-521',
        _ => null,
      };
      if (key['crv'] != expectedCurve) {
        throw const JwtInspectException(
          kind: JwtInspectFailureKind.validation,
          code: 'jwt-inspect.incompatible-key',
          field: 'key',
          reason: 'algorithm-mismatch',
        );
      }
    }
    return key;
  }

  static int _minimumHmacLength(String algorithm) => switch (algorithm) {
    'HS256' => 32,
    'HS384' => 48,
    'HS512' => 64,
    _ => throw StateError('validated HMAC algorithm'),
  };

  static String _strictReason(StrictJsonObjectFailure failure) =>
      switch (failure) {
        StrictJsonObjectFailure.invalidJson => 'invalid-json',
        StrictJsonObjectFailure.objectRequired => 'object-required',
        StrictJsonObjectFailure.invalidUnicode => 'invalid-unicode',
      };

  static bool _verifyWithJose(
    List<int> signingInput,
    List<int> signature,
    String algorithm,
    JsonWebKey key,
  ) => key.verify(signingInput, signature, algorithm: algorithm);
}
