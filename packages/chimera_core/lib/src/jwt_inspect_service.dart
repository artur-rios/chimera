// ignore_for_file: prefer_initializing_formals

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class JwtInspectOperationRequest {
  const JwtInspectOperationRequest({required String token, String? key})
    : _token = token,
      _key = key;

  final String _token;
  final String? _key;
}

final class JwtInspectOutput {
  JwtInspectOutput({
    required Map<String, Object?> header,
    required Map<String, Object?> claims,
    required this.verification,
  }) : header = _freezeJsonObject(header),
       claims = _freezeJsonObject(claims);

  final Map<String, Object?> header;
  final Map<String, Object?> claims;
  final JwtVerificationStatus verification;

  Map<String, Object?> toJson() => <String, Object?>{
    'header': header,
    'claims': claims,
    'verification': switch (verification) {
      JwtVerificationStatus.notRequested => 'not-requested',
      JwtVerificationStatus.verified => 'verified',
      JwtVerificationStatus.failed => 'failed',
    },
  };
}

Map<String, Object?> _freezeJsonObject(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable(
      source.map(
        (key, value) => MapEntry<String, Object?>(key, _freezeJsonValue(value)),
      ),
    );

Object? _freezeJsonValue(Object? value) {
  if (value is Map<String, Object?>) return _freezeJsonObject(value);
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freezeJsonValue));
  }
  return value;
}

final class JwtInspectService
    implements OperationService<JwtInspectOperationRequest, JwtInspectOutput> {
  const JwtInspectService({this.inspector = const JwtInspector()});

  final JwtInspector inspector;

  @override
  Future<ChimeraResult<JwtInspectOutput>> execute(
    JwtInspectOperationRequest request,
  ) async {
    try {
      final result = inspector.inspect(
        JwtInspectRequest(token: request._token, key: request._key),
      );
      return ChimeraSuccess<JwtInspectOutput>(
        JwtInspectOutput(
          header: result.header,
          claims: result.claims,
          verification: result.verification,
        ),
      );
    } on JwtInspectException catch (error) {
      final kind = switch (error.kind) {
        JwtInspectFailureKind.validation => FailureKind.validation,
        JwtInspectFailureKind.processing => FailureKind.processing,
        JwtInspectFailureKind.resource => FailureKind.resource,
      };
      final messageKey = switch (kind) {
        FailureKind.validation => 'error.jwtInspect.validation',
        FailureKind.processing => 'error.jwtInspect.processing',
        FailureKind.resource => 'error.jwtInspect.resource',
        _ => throw StateError('Unhandled JWT inspect failure kind'),
      };
      return ChimeraFailure<JwtInspectOutput>(
        kind: kind,
        code: error.code,
        messageKey: messageKey,
        details: Map<String, Object?>.unmodifiable(<String, Object?>{
          'field': error.field,
          'reason': error.reason,
        }),
      );
    }
  }
}
