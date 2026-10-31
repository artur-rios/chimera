import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class DateRequest {
  const DateRequest({
    required this.value,
    required this.sourceRepresentation,
    required this.targetRepresentation,
    required this.sourceTimeZone,
    required this.targetTimeZone,
    this.sourcePattern,
    this.targetPattern,
  });

  final String value;
  final DateRepresentation sourceRepresentation;
  final DateRepresentation targetRepresentation;
  final String sourceTimeZone;
  final String targetTimeZone;
  final String? sourcePattern;
  final String? targetPattern;
}

final class DateOutput {
  const DateOutput(this.conversion);

  final DateConversion conversion;

  Map<String, Object?> toJson() => <String, Object?>{
    'value': conversion.convertedValue,
    'from': conversion.sourceRepresentation.identifier,
    'to': conversion.targetRepresentation.identifier,
    'utc': conversion.utcIso8601,
    'sourceTimeZone': conversion.sourceTimeZone,
    'targetTimeZone': conversion.targetTimeZone,
    'targetOffset': conversion.targetOffset,
  };
}

final class DateService implements OperationService<DateRequest, DateOutput> {
  const DateService({this.converter = const DateConverter()});

  final DateConverter converter;

  @override
  Future<ChimeraResult<DateOutput>> execute(DateRequest request) async {
    try {
      return ChimeraSuccess<DateOutput>(
        DateOutput(
          converter.convert(
            DateConversionRequest(
              value: request.value,
              sourceRepresentation: request.sourceRepresentation,
              targetRepresentation: request.targetRepresentation,
              sourceTimeZone: request.sourceTimeZone,
              targetTimeZone: request.targetTimeZone,
              sourcePattern: request.sourcePattern,
              targetPattern: request.targetPattern,
            ),
          ),
        ),
      );
    } on DateConversionException catch (error) {
      return ChimeraFailure<DateOutput>(
        kind: switch (error.kind) {
          DateConversionFailureKind.validation => FailureKind.validation,
          DateConversionFailureKind.range => FailureKind.range,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          DateConversionFailureKind.validation => 'error.date.validation',
          DateConversionFailureKind.range => 'error.date.range',
        },
      );
    }
  }
}
