import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('CronEvaluator', () {
    test('GivenFiveFieldExpression_WhenEvaluated_ThenPreviousAndNextOccurrencesAreReturned', () {
      final result = const CronEvaluator().evaluate(
        CronEvaluationRequest(
          expression: '0 9 * * *',
          timeZone: 'UTC',
          occurrenceCount: 2,
          referenceUtc: DateTime.utc(2026, 1, 15, 12),
        ),
      );

      expect(result.hasSeconds, isFalse);
      expect(result.normalizedExpression, '0 9 * * *');
      expect(
        result.previous.map((occurrence) => occurrence.utcIso8601),
        <String>['2026-01-15T09:00:00.000Z', '2026-01-14T09:00:00.000Z'],
      );
      expect(result.next.map((occurrence) => occurrence.utcIso8601), <String>[
        '2026-01-16T09:00:00.000Z',
        '2026-01-17T09:00:00.000Z',
      ]);
    });

    test('GivenSixFieldExpression_WhenEvaluated_ThenSecondsFieldIsApplied', () {
      final result = const CronEvaluator().evaluate(
        CronEvaluationRequest(
          expression: '30 */15 * * * *',
          timeZone: 'UTC',
          occurrenceCount: 2,
          referenceUtc: DateTime.utc(2026, 1, 15, 12),
        ),
      );

      expect(result.hasSeconds, isTrue);
      expect(result.next.map((occurrence) => occurrence.utcIso8601), <String>[
        '2026-01-15T12:00:30.000Z',
        '2026-01-15T12:15:30.000Z',
      ]);
      expect(
        result.previous.map((occurrence) => occurrence.utcIso8601),
        <String>['2026-01-15T11:45:30.000Z', '2026-01-15T11:30:30.000Z'],
      );
    });

    test(
      'GivenNamedFieldsAndIanaZone_WhenEvaluated_ThenLocalOffsetIsPreserved',
      () {
        final result = const CronEvaluator().evaluate(
          CronEvaluationRequest(
            expression: '0 8 * JAN MON-FRI',
            timeZone: 'America/Sao_Paulo',
            occurrenceCount: 1,
            referenceUtc: DateTime.utc(2026, 1, 5, 10),
          ),
        );

        expect(
          result.next.single.localIso8601,
          '2026-01-05T08:00:00.000-03:00',
        );
        expect(result.next.single.utcIso8601, '2026-01-05T11:00:00.000Z');
        expect(result.fields['month'], '1');
        expect(result.fields['dayOfWeek'], '1-5');
      },
    );

    test('GivenListsRangesAndExactReference_WhenEvaluated_ThenStrictAdjacentOccurrencesAreReturned', () {
      final result = const CronEvaluator().evaluate(
        CronEvaluationRequest(
          expression: '0,30 9-10 * * MON,WED,FRI',
          timeZone: 'UTC',
          occurrenceCount: 1,
          referenceUtc: DateTime.utc(2026, 1, 5, 9),
        ),
      );

      expect(result.fields['minute'], '0,30');
      expect(result.fields['hour'], '9-10');
      expect(result.fields['dayOfWeek'], '1,3,5');
      expect(result.previous.single.utcIso8601, '2026-01-02T10:30:00.000Z');
      expect(result.next.single.utcIso8601, '2026-01-05T09:30:00.000Z');
    });

    test(
      'GivenNonexistentDstTime_WhenEvaluated_ThenInvalidWallClockIsSkipped',
      () {
        final result = const CronEvaluator().evaluate(
          CronEvaluationRequest(
            expression: '30 2 * * *',
            timeZone: 'America/New_York',
            occurrenceCount: 1,
            referenceUtc: DateTime.utc(2026, 3, 8, 5),
          ),
        );

        expect(
          result.previous.single.localIso8601,
          '2026-03-07T02:30:00.000-05:00',
        );
        expect(
          result.next.single.localIso8601,
          '2026-03-09T02:30:00.000-04:00',
        );
      },
    );

    test('GivenRestrictedMonthDayAndWeekday_WhenEvaluated_ThenUnixOrSemanticsApply', () {
      final result = const CronEvaluator().evaluate(
        CronEvaluationRequest(
          expression: '0 9 13 * MON',
          timeZone: 'UTC',
          occurrenceCount: 1,
          referenceUtc: DateTime.utc(2026, 1, 14),
        ),
      );

      expect(result.previous.single.utcIso8601, '2026-01-13T09:00:00.000Z');
      expect(result.next.single.utcIso8601, '2026-01-19T09:00:00.000Z');
    });

    test(
      'GivenFullDomainDayOfMonthRange_WhenEvaluated_ThenFieldRemainsRestricted',
      () {
        final result = const CronEvaluator().evaluate(
          CronEvaluationRequest(
            expression: '0 0 1-31 * MON',
            timeZone: 'UTC',
            occurrenceCount: 1,
            referenceUtc: DateTime.utc(2026, 1, 6, 12),
          ),
        );

        expect(result.next.single.utcIso8601, '2026-01-07T00:00:00.000Z');
      },
    );

    for (final dayOfWeek in <String>['0-6', '1-7', '0,1,2,3,4,5,6']) {
      test('GivenFullDomainDayOfWeekSyntax$dayOfWeek'
          '_WhenEvaluated_ThenFieldRemainsRestricted', () {
        final result = const CronEvaluator().evaluate(
          CronEvaluationRequest(
            expression: '0 0 1 * $dayOfWeek',
            timeZone: 'UTC',
            occurrenceCount: 1,
            referenceUtc: DateTime.utc(2026, 1, 6, 12),
          ),
        );

        expect(result.next.single.utcIso8601, '2026-01-07T00:00:00.000Z');
      });
    }

    test(
      'GivenRepeatedDstWallClock_WhenEvaluated_ThenBothInstantsAreReturned',
      () {
        final result = const CronEvaluator().evaluate(
          CronEvaluationRequest(
            expression: '30 1 * * *',
            timeZone: 'America/New_York',
            occurrenceCount: 2,
            referenceUtc: DateTime.utc(2026, 11, 1, 5),
          ),
        );

        expect(result.next.map((occurrence) => occurrence.utcIso8601), <String>[
          '2026-11-01T05:30:00.000Z',
          '2026-11-01T06:30:00.000Z',
        ]);
        expect(
          result.next.map((occurrence) => occurrence.localIso8601),
          <String>[
            '2026-11-01T01:30:00.000-04:00',
            '2026-11-01T01:30:00.000-05:00',
          ],
        );
      },
    );

    test('GivenMultipleRepeatedDstTimes_WhenEvaluated_ThenOccurrencesAreChronological', () {
      final evaluator = const CronEvaluator();
      final next = evaluator.evaluate(
        CronEvaluationRequest(
          expression: '0,30 1 * * *',
          timeZone: 'America/New_York',
          occurrenceCount: 4,
          referenceUtc: DateTime.utc(2026, 11, 1, 4),
        ),
      );
      final previous = evaluator.evaluate(
        CronEvaluationRequest(
          expression: '0,30 1 * * *',
          timeZone: 'America/New_York',
          occurrenceCount: 4,
          referenceUtc: DateTime.utc(2026, 11, 1, 7),
        ),
      );

      expect(next.next.map((occurrence) => occurrence.utcIso8601), <String>[
        '2026-11-01T05:00:00.000Z',
        '2026-11-01T05:30:00.000Z',
        '2026-11-01T06:00:00.000Z',
        '2026-11-01T06:30:00.000Z',
      ]);
      expect(
        previous.previous.map((occurrence) => occurrence.utcIso8601),
        <String>[
          '2026-11-01T06:30:00.000Z',
          '2026-11-01T06:00:00.000Z',
          '2026-11-01T05:30:00.000Z',
          '2026-11-01T05:00:00.000Z',
        ],
      );
    });

    test('GivenMaximumCountForRareSchedule_WhenEvaluated_ThenAllOccurrencesAreReturned', () {
      final result = const CronEvaluator().evaluate(
        CronEvaluationRequest(
          expression: '0 0 29 2 *',
          timeZone: 'UTC',
          occurrenceCount: 100,
          referenceUtc: DateTime.utc(2026, 1, 1),
        ),
      );

      expect(result.previous, hasLength(100));
      expect(result.next, hasLength(100));
    });

    for (final invalidCase
        in <({String name, CronEvaluationRequest request, String code})>[
          (
            name: 'field count',
            request: CronEvaluationRequest(
              expression: '* * * *',
              timeZone: 'UTC',
              occurrenceCount: 1,
              referenceUtc: DateTime.utc(2026),
            ),
            code: 'cron.invalid-field-count',
          ),
          (
            name: 'field value',
            request: CronEvaluationRequest(
              expression: '60 * * * *',
              timeZone: 'UTC',
              occurrenceCount: 1,
              referenceUtc: DateTime.utc(2026),
            ),
            code: 'cron.invalid-field',
          ),
          (
            name: 'time zone',
            request: CronEvaluationRequest(
              expression: '* * * * *',
              timeZone: 'Mars/Olympus',
              occurrenceCount: 1,
              referenceUtc: DateTime.utc(2026),
            ),
            code: 'cron.invalid-time-zone',
          ),
          (
            name: 'occurrence count',
            request: CronEvaluationRequest(
              expression: '* * * * *',
              timeZone: 'UTC',
              occurrenceCount: 0,
              referenceUtc: DateTime.utc(2026),
            ),
            code: 'cron.invalid-count',
          ),
        ]) {
      test(
        'GivenInvalid${invalidCase.name}_WhenEvaluated_ThenTypedValidationFailureIsThrown',
        () {
          expect(
            () => const CronEvaluator().evaluate(invalidCase.request),
            throwsA(
              isA<CronEvaluationException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    CronEvaluationFailureKind.validation,
                  )
                  .having((error) => error.code, 'code', invalidCase.code),
            ),
          );
        },
      );
    }

    test('GivenSearchBudgetIsExhausted_WhenEvaluated_ThenTypedResourceFailureIsThrown', () {
      expect(
        () => const CronEvaluator(maxSearchDays: 1).evaluate(
          CronEvaluationRequest(
            expression: '0 0 1 12 *',
            timeZone: 'UTC',
            occurrenceCount: 1,
            referenceUtc: DateTime.utc(2026, 1, 2),
          ),
        ),
        throwsA(
          isA<CronEvaluationException>()
              .having(
                (error) => error.kind,
                'kind',
                CronEvaluationFailureKind.resource,
              )
              .having((error) => error.code, 'code', 'cron.search-limit'),
        ),
      );
    });
  });
}
