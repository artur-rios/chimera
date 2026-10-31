// ignore_for_file: prefer_initializing_formals

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class JwtCreateOperationRequest {
  const JwtCreateOperationRequest({
    required String headerJson,
    required String claimsJson,
    required String algorithm,
    required String key,
  }) : _headerJson = headerJson,
       _claimsJson = claimsJson,
       _algorithm = algorithm,
       _key = key;

  final String _headerJson;
  final String _claimsJson;
  final String _algorithm;
  final String _key;
}

final class JwtCreateOutput {
  const JwtCreateOutput({required this.token});

  final String token;

  Map<String, Object?> toJson() => <String, Object?>{'token': token};
}

final class JwtCreateService
    implements OperationService<JwtCreateOperationRequest, JwtCreateOutput> {
  const JwtCreateService({this.creator = const JwtCreator()});

  final JwtCreator creator;

  @override
  Future<ChimeraResult<JwtCreateOutput>> execute(
    JwtCreateOperationRequest request,
  ) async {
    try {
      final result = creator.create(
        JwtCreateRequest(
          headerJson: request._headerJson,
          claimsJson: request._claimsJson,
          algorithm: request._algorithm,
          key: request._key,
        ),
      );
      return ChimeraSuccess<JwtCreateOutput>(
        JwtCreateOutput(token: result.token),
      );
    } on JwtCreateException catch (error) {
      final kind = switch (error.kind) {
        JwtCreateFailureKind.validation => FailureKind.validation,
        JwtCreateFailureKind.processing => FailureKind.processing,
        JwtCreateFailureKind.resource => FailureKind.resource,
      };
      final messageKey = switch (kind) {
        FailureKind.validation => 'error.jwtCreate.validation',
        FailureKind.processing => 'error.jwtCreate.processing',
        FailureKind.resource => 'error.jwtCreate.resource',
        _ => throw StateError('Unhandled JWT create failure kind'),
      };
      return ChimeraFailure<JwtCreateOutput>(
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
