import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('DateConverter', () {
    const converter = DateConverter();

    test(
      'GivenIsoInstant_WhenConvertedToTargetZone_ThenOffsetIsoIsReturned',
      () {
        final result = converter.convert(
          const DateConversionRequest(
            value: '2026-01-15T12:30:45.123Z',
            sourceRepresentation: DateRepresentation.iso8601,
            targetRepresentation: DateRepresentation.iso8601,
            sourceTimeZone: 'UTC',
            targetTimeZone: 'America/Sao_Paulo',
          ),
        );

        expect(result.convertedValue, '2026-01-15T09:30:45.123-03:00');
        expect(result.utcIso8601, '2026-01-15T12:30:45.123Z');
        expect(result.targetOffset, '-03:00');
      },
    );

    test(
      'GivenLocalIsoAndSourceZone_WhenConvertedToEpoch_ThenInstantIsResolved',
      () {
        final result = converter.convert(
          const DateConversionRequest(
            value: '2026-01-15T09:30:45',
            sourceRepresentation: DateRepresentation.iso8601,
            targetRepresentation: DateRepresentation.unixSeconds,
            sourceTimeZone: 'America/Sao_Paulo',
            targetTimeZone: 'UTC',
          ),
        );

        expect(result.convertedValue, '1768480245');
        expect(result.utcIso8601, '2026-01-15T12:30:45.000Z');
      },
    );

    test(
      'GivenUnixMilliseconds_WhenConvertedToCustomPattern_ThenTargetZoneIsUsed',
      () {
        final result = converter.convert(
          const DateConversionRequest(
            value: '1768480245123',
            sourceRepresentation: DateRepresentation.unixMilliseconds,
            targetRepresentation: DateRepresentation.customPattern,
            sourceTimeZone: 'UTC',
            targetTimeZone: 'Asia/Tokyo',
            targetPattern: 'yyyy/MM/dd HH:mm:ss.SSS',
          ),
        );

        expect(result.convertedValue, '2026/01/15 21:30:45.123');
        expect(result.targetOffset, '+09:00');
      },
    );

    test('GivenCustomPattern_WhenConvertedToMilliseconds_ThenStrictCalendarIsApplied', () {
      final result = converter.convert(
        const DateConversionRequest(
          value: '29/02/2024 23:05:07',
          sourceRepresentation: DateRepresentation.customPattern,
          targetRepresentation: DateRepresentation.unixMilliseconds,
          sourceTimeZone: 'UTC',
          targetTimeZone: 'UTC',
          sourcePattern: 'dd/MM/yyyy HH:mm:ss',
        ),
      );

      expect(result.convertedValue, '1709247907000');
    });

    test('GivenQuotedTokenLiteral_WhenCustomDateIsConverted_ThenLiteralIsNotAField', () {
      final result = converter.convert(
        const DateConversionRequest(
          value: '2026-01-15 yyyy',
          sourceRepresentation: DateRepresentation.customPattern,
          targetRepresentation: DateRepresentation.iso8601,
          sourceTimeZone: 'UTC',
          targetTimeZone: 'UTC',
          sourcePattern: "yyyy-MM-dd 'yyyy'",
        ),
      );

      expect(result.convertedValue, '2026-01-15T00:00:00.000+00:00');
    });

    test('GivenIsoPrecisionBeyondMilliseconds_WhenConverted_ThenValidationFailureIsTyped', () {
      expect(
        () => converter.convert(
          const DateConversionRequest(
            value: '2026-01-15T09:30:45.123456',
            sourceRepresentation: DateRepresentation.iso8601,
            targetRepresentation: DateRepresentation.iso8601,
            sourceTimeZone: 'America/Sao_Paulo',
            targetTimeZone: 'UTC',
          ),
        ),
        throwsA(
          isA<DateConversionException>().having(
            (error) => error.code,
            'code',
            'date.invalid-value',
          ),
        ),
      );
    });

    test('GivenCustomInputWithSurroundingWhitespace_WhenConverted_ThenAdaptersShareNormalization', () {
      final result = converter.convert(
        const DateConversionRequest(
          value: '\n  29/02/2024 23:05:07  \n',
          sourceRepresentation: DateRepresentation.customPattern,
          targetRepresentation: DateRepresentation.iso8601,
          sourceTimeZone: 'UTC',
          targetTimeZone: 'UTC',
          sourcePattern: 'dd/MM/yyyy HH:mm:ss',
        ),
      );

      expect(result.convertedValue, '2024-02-29T23:05:07.000+00:00');
    });

    for (final value in <String>[
      '2026-1-05 01:02:03.001',
      '2026-01-05 1:02:03.001',
      '2026-01-05 01:02:03.1',
    ]) {
      test(
        'GivenUnderWidthCustomField${value}_WhenConverted_ThenValidationFailureIsTyped',
        () {
          expect(
            () => converter.convert(
              DateConversionRequest(
                value: value,
                sourceRepresentation: DateRepresentation.customPattern,
                targetRepresentation: DateRepresentation.iso8601,
                sourceTimeZone: 'UTC',
                targetTimeZone: 'UTC',
                sourcePattern: 'yyyy-MM-dd HH:mm:ss.SSS',
              ),
            ),
            throwsA(
              isA<DateConversionException>().having(
                (error) => error.code,
                'code',
                'date.invalid-value',
              ),
            ),
          );
        },
      );
    }

    test(
      'GivenNegativeMilliseconds_WhenConvertedToSeconds_ThenSecondsAreFloored',
      () {
        final result = converter.convert(
          const DateConversionRequest(
            value: '-1',
            sourceRepresentation: DateRepresentation.unixMilliseconds,
            targetRepresentation: DateRepresentation.unixSeconds,
            sourceTimeZone: 'UTC',
            targetTimeZone: 'UTC',
          ),
        );

        expect(result.convertedValue, '-1');
        expect(result.utcIso8601, '1969-12-31T23:59:59.999Z');
      },
    );

    for (final invalidCase
        in <({String name, DateConversionRequest request, String code})>[
          (
            name: 'calendar date',
            request: DateConversionRequest(
              value: '2026-02-30',
              sourceRepresentation: DateRepresentation.iso8601,
              targetRepresentation: DateRepresentation.iso8601,
              sourceTimeZone: 'UTC',
              targetTimeZone: 'UTC',
            ),
            code: 'date.invalid-value',
          ),
          (
            name: 'epoch',
            request: DateConversionRequest(
              value: '12.5',
              sourceRepresentation: DateRepresentation.unixSeconds,
              targetRepresentation: DateRepresentation.iso8601,
              sourceTimeZone: 'UTC',
              targetTimeZone: 'UTC',
            ),
            code: 'date.invalid-epoch',
          ),
          (
            name: 'zone',
            request: DateConversionRequest(
              value: '0',
              sourceRepresentation: DateRepresentation.unixSeconds,
              targetRepresentation: DateRepresentation.iso8601,
              sourceTimeZone: 'UTC',
              targetTimeZone: 'Mars/Olympus',
            ),
            code: 'date.invalid-time-zone',
          ),
          (
            name: 'pattern',
            request: DateConversionRequest(
              value: 'January 15 2026',
              sourceRepresentation: DateRepresentation.customPattern,
              targetRepresentation: DateRepresentation.iso8601,
              sourceTimeZone: 'UTC',
              targetTimeZone: 'UTC',
              sourcePattern: 'MMMM dd yyyy',
            ),
            code: 'date.invalid-pattern',
          ),
          (
            name: 'DST gap',
            request: DateConversionRequest(
              value: '2026-03-08T02:30:00',
              sourceRepresentation: DateRepresentation.iso8601,
              targetRepresentation: DateRepresentation.iso8601,
              sourceTimeZone: 'America/New_York',
              targetTimeZone: 'UTC',
            ),
            code: 'date.nonexistent-local-time',
          ),
          (
            name: 'DST overlap',
            request: DateConversionRequest(
              value: '2026-11-01T01:30:00',
              sourceRepresentation: DateRepresentation.iso8601,
              targetRepresentation: DateRepresentation.iso8601,
              sourceTimeZone: 'America/New_York',
              targetTimeZone: 'UTC',
            ),
            code: 'date.ambiguous-local-time',
          ),
        ]) {
      test(
        'GivenInvalid${invalidCase.name}_WhenConverted_ThenValidationFailureIsTyped',
        () {
          expect(
            () => converter.convert(invalidCase.request),
            throwsA(
              isA<DateConversionException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    DateConversionFailureKind.validation,
                  )
                  .having((error) => error.code, 'code', invalidCase.code),
            ),
          );
        },
      );
    }

    test(
      'GivenEpochOutsideSupportedRange_WhenConverted_ThenRangeFailureIsTyped',
      () {
        expect(
          () => converter.convert(
            const DateConversionRequest(
              value: '999999999999999999999',
              sourceRepresentation: DateRepresentation.unixMilliseconds,
              targetRepresentation: DateRepresentation.iso8601,
              sourceTimeZone: 'UTC',
              targetTimeZone: 'UTC',
            ),
          ),
          throwsA(
            isA<DateConversionException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  DateConversionFailureKind.range,
                )
                .having((error) => error.code, 'code', 'date.out-of-range'),
          ),
        );
      },
    );

    test('GivenTargetZoneMovesInstantOutsideCalendarRange_WhenConverted_ThenRangeFailureIsTyped', () {
      expect(
        () => converter.convert(
          const DateConversionRequest(
            value: '253402300799999',
            sourceRepresentation: DateRepresentation.unixMilliseconds,
            targetRepresentation: DateRepresentation.iso8601,
            sourceTimeZone: 'UTC',
            targetTimeZone: 'Pacific/Kiritimati',
          ),
        ),
        throwsA(
          isA<DateConversionException>()
              .having(
                (error) => error.kind,
                'kind',
                DateConversionFailureKind.range,
              )
              .having((error) => error.code, 'code', 'date.out-of-range'),
        ),
      );
    });

    test('GivenNumericTargetAtMaximumInstant_WhenTargetZoneCrossesYear_ThenEpochStillSucceeds', () {
      final result = converter.convert(
        const DateConversionRequest(
          value: '253402300799999',
          sourceRepresentation: DateRepresentation.unixMilliseconds,
          targetRepresentation: DateRepresentation.unixSeconds,
          sourceTimeZone: 'UTC',
          targetTimeZone: 'Pacific/Kiritimati',
        ),
      );

      expect(result.convertedValue, '253402300799');
    });
  });
}
