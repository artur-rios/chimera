import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class UuidOperationRequest {
  const UuidOperationRequest({
    this.version = 'v4',
    this.representation = 'uuid',
    this.count = '1',
  });

  final String version;
  final String representation;
  final String count;
}

final class UuidOutput {
  const UuidOutput(this.result);

  final UuidGenerationResult result;
  String get version => result.version.name;
  String get representation => result.representation.name;
  int get count => result.values.length;
  List<String> get values => result.values;

  Map<String, Object?> toJson() => {
    'version': version,
    'representation': representation,
    'count': count,
    'values': values,
  };
}

final class UuidService
    implements OperationService<UuidOperationRequest, UuidOutput> {
  const UuidService({this.generator = const UuidGenerator()});

  final UuidGenerator generator;

  @override
  Future<ChimeraResult<UuidOutput>> execute(
    UuidOperationRequest request,
  ) async {
    final version = switch (request.version) {
      'v4' => UuidVersion.v4,
      'v7' => UuidVersion.v7,
      _ => null,
    };
    if (version == null) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'uuid.invalid-version',
        messageKey: 'error.uuid.validation',
        details: {'field': 'version', 'reason': 'v4-or-v7-required'},
      );
    }
    final representation = switch (request.representation) {
      'uuid' => UuidRepresentation.uuid,
      'guid' => UuidRepresentation.guid,
      _ => null,
    };
    if (representation == null) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'uuid.invalid-representation',
        messageKey: 'error.uuid.validation',
        details: {'field': 'representation', 'reason': 'uuid-or-guid-required'},
      );
    }
    final count = tryParsePositiveDecimalInteger(request.count);
    if (count == null) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'uuid.invalid-count',
        messageKey: 'error.uuid.validation',
        details: {'field': 'count', 'reason': 'positive-integer-required'},
      );
    }

    try {
      return ChimeraSuccess(
        UuidOutput(
          generator.generate(
            UuidGenerationRequest(
              version: version,
              representation: representation,
              count: count,
            ),
          ),
        ),
      );
    } on UuidGenerationException catch (error) {
      final kind = switch (error.kind) {
        UuidGenerationFailureKind.validation => FailureKind.validation,
        UuidGenerationFailureKind.processing => FailureKind.processing,
        UuidGenerationFailureKind.resource => FailureKind.resource,
      };
      final messageKey = switch (error.kind) {
        UuidGenerationFailureKind.validation => 'error.uuid.validation',
        UuidGenerationFailureKind.processing => 'error.uuid.processing',
        UuidGenerationFailureKind.resource => 'error.uuid.resource',
      };
      return ChimeraFailure(
        kind: kind,
        code: error.code,
        messageKey: messageKey,
        details: {'field': error.field, 'reason': error.reason},
      );
    } on OutOfMemoryError {
      return const ChimeraFailure(
        kind: FailureKind.resource,
        code: 'uuid.resource-limit',
        messageKey: 'error.uuid.resource',
      );
    }
  }
}
