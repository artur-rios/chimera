import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenReferenceInstant_WhenParsed_ThenExplicitOffsetIsRequiredAndNormalized', () {
    expect(parseCronReference('2026-01-05T12:00:00'), isNull);
    expect(
      parseCronReference('2026-01-05T12:00:00-03:00'),
      DateTime.utc(2026, 1, 5, 15),
    );
    expect(
      parseCronReference('2026-01-05T12:00:00Z'),
      DateTime.utc(2026, 1, 5, 12),
    );
  });

  test('GivenValidCronRequest_WhenServiceExecutes_ThenStableStructuredOutputIsReturned', () async {
    const service = CronService();

    final result = await service.execute(
      CronRequest(
        expression: '0 9 * * MON-FRI',
        timeZone: 'UTC',
        occurrenceCount: 1,
        referenceUtc: DateTime.utc(2026, 1, 5, 12),
      ),
    );

    expect(result, isA<ChimeraSuccess<CronOutput>>());
    final output = (result as ChimeraSuccess<CronOutput>).value;
    expect(output.evaluation.normalizedExpression, '0 9 * * 1-5');
    expect(output.toJson(), <String, Object?>{
      'expression': '0 9 * * 1-5',
      'timeZone': 'UTC',
      'hasSeconds': false,
      'fields': <String, String>{
        'seconds': '0',
        'minute': '0',
        'hour': '9',
        'dayOfMonth': '*',
        'month': '*',
        'dayOfWeek': '1-5',
      },
      'previous': <Map<String, Object?>>[
        <String, Object?>{
          'utc': '2026-01-05T09:00:00.000Z',
          'local': '2026-01-05T09:00:00.000+00:00',
          'abbreviation': 'UTC',
        },
      ],
      'next': <Map<String, Object?>>[
        <String, Object?>{
          'utc': '2026-01-06T09:00:00.000Z',
          'local': '2026-01-06T09:00:00.000+00:00',
          'abbreviation': 'UTC',
        },
      ],
    });
  });

  test('GivenInvalidCronRequest_WhenServiceExecutes_ThenTypedValidationFailureHasNoInputDetails', () async {
    const service = CronService();

    final result = await service.execute(
      CronRequest(
        expression: 'secret invalid expression',
        timeZone: 'UTC',
        occurrenceCount: 1,
        referenceUtc: DateTime.utc(2026),
      ),
    );

    expect(result, isA<ChimeraFailure<CronOutput>>());
    final failure = result as ChimeraFailure<CronOutput>;
    expect(failure.kind, FailureKind.validation);
    expect(failure.code, 'cron.invalid-field-count');
    expect(failure.messageKey, 'error.cron.validation');
    expect(failure.details, isEmpty);
  });

  test('GivenEvaluatorBudgetFailure_WhenServiceExecutes_ThenTypedResourceFailureIsReturned', () async {
    const service = CronService(evaluator: CronEvaluator(maxSearchDays: 1));

    final result = await service.execute(
      CronRequest(
        expression: '0 0 1 12 *',
        timeZone: 'UTC',
        occurrenceCount: 1,
        referenceUtc: DateTime.utc(2026, 1, 2),
      ),
    );

    expect(result, isA<ChimeraFailure<CronOutput>>());
    final failure = result as ChimeraFailure<CronOutput>;
    expect(failure.kind, FailureKind.resource);
    expect(failure.code, 'cron.search-limit');
    expect(failure.messageKey, 'error.cron.resource');
    expect(failure.details, isEmpty);
  });
}
