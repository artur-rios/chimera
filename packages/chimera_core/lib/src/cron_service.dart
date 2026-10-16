import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

DateTime? parseCronReference(String source) {
  final trimmed = source.trim();
  if (!RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(trimmed)) {
    return null;
  }
  return DateTime.tryParse(trimmed)?.toUtc();
}

final class CronRequest {
  const CronRequest({
    required this.expression,
    required this.timeZone,
    required this.occurrenceCount,
    required this.referenceUtc,
  });

  final String expression;
  final String timeZone;
  final int occurrenceCount;
  final DateTime referenceUtc;
}

final class CronOutput {
  const CronOutput(this.evaluation);

  final CronEvaluation evaluation;

  Map<String, Object?> toJson() => <String, Object?>{
    'expression': evaluation.normalizedExpression,
    'timeZone': evaluation.timeZone,
    'hasSeconds': evaluation.hasSeconds,
    'fields': evaluation.fields,
    'previous': evaluation.previous.map(_occurrenceToJson).toList(),
    'next': evaluation.next.map(_occurrenceToJson).toList(),
  };

  static Map<String, Object?> _occurrenceToJson(CronOccurrence occurrence) =>
      <String, Object?>{
        'utc': occurrence.utcIso8601,
        'local': occurrence.localIso8601,
        'abbreviation': occurrence.timeZoneAbbreviation,
      };
}

final class CronService implements OperationService<CronRequest, CronOutput> {
  const CronService({this.evaluator = const CronEvaluator()});

  final CronEvaluator evaluator;

  @override
  Future<ChimeraResult<CronOutput>> execute(CronRequest request) async {
    try {
      final evaluation = evaluator.evaluate(
        CronEvaluationRequest(
          expression: request.expression,
          timeZone: request.timeZone,
          occurrenceCount: request.occurrenceCount,
          referenceUtc: request.referenceUtc,
        ),
      );
      return ChimeraSuccess<CronOutput>(CronOutput(evaluation));
    } on CronEvaluationException catch (error) {
      final kind = switch (error.kind) {
        CronEvaluationFailureKind.validation => FailureKind.validation,
        CronEvaluationFailureKind.resource => FailureKind.resource,
      };
      final messageKey = switch (error.kind) {
        CronEvaluationFailureKind.validation => 'error.cron.validation',
        CronEvaluationFailureKind.resource => 'error.cron.resource',
      };
      return ChimeraFailure<CronOutput>(
        kind: kind,
        code: error.code,
        messageKey: messageKey,
      );
    }
  }
}
