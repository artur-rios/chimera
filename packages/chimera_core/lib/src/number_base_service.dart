import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class NumberBaseOperationRequest {
  const NumberBaseOperationRequest({
    required this.value,
    required this.sourceBase,
    required this.targetBase,
  });

  final String value;
  final int sourceBase;
  final int targetBase;
}

final class NumberBaseOutput {
  const NumberBaseOutput(this.result);

  final NumberBaseResult result;

  String get converted => result.converted;

  Map<String, Object?> toJson() => <String, Object?>{
    'converted': result.converted,
    'sourceBase': result.sourceBase,
    'targetBase': result.targetBase,
  };
}

final class NumberBaseService
    implements OperationService<NumberBaseOperationRequest, NumberBaseOutput> {
  const NumberBaseService({this.converter = const NumberBaseConverter()});

  final NumberBaseConverter converter;

  @override
  Future<ChimeraResult<NumberBaseOutput>> execute(
    NumberBaseOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<NumberBaseOutput>(
        NumberBaseOutput(
          converter.convert(
            NumberBaseRequest(
              value: request.value,
              sourceBase: request.sourceBase,
              targetBase: request.targetBase,
            ),
          ),
        ),
      );
    } on NumberBaseException catch (error) {
      return ChimeraFailure<NumberBaseOutput>(
        kind: switch (error.kind) {
          NumberBaseFailureKind.validation => FailureKind.validation,
          NumberBaseFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          NumberBaseFailureKind.validation => 'error.numberBase.validation',
          NumberBaseFailureKind.resource => 'error.numberBase.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
