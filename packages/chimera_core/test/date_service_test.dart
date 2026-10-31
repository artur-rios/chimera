import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenValidDateRequest_WhenServiceExecutes_ThenStableOutputIsReturned',
    () async {
      const service = DateService();

      final result = await service.execute(
        const DateRequest(
          value: '2026-01-15T12:30:45Z',
          sourceRepresentation: DateRepresentation.iso8601,
          targetRepresentation: DateRepresentation.customPattern,
          sourceTimeZone: 'UTC',
          targetTimeZone: 'America/Sao_Paulo',
          targetPattern: 'dd/MM/yyyy HH:mm:ss',
        ),
      );

      expect(result, isA<ChimeraSuccess<DateOutput>>());
      expect(
        (result as ChimeraSuccess<DateOutput>).value.toJson(),
        <String, Object?>{
          'value': '15/01/2026 09:30:45',
          'from': 'iso8601',
          'to': 'custom',
          'utc': '2026-01-15T12:30:45.000Z',
          'sourceTimeZone': 'UTC',
          'targetTimeZone': 'America/Sao_Paulo',
          'targetOffset': '-03:00',
        },
      );
    },
  );

  test('GivenInvalidDateRequest_WhenServiceExecutes_ThenTypedValidationFailureIsReturned', () async {
    final result = await const DateService().execute(
      const DateRequest(
        value: 'secret invalid date',
        sourceRepresentation: DateRepresentation.iso8601,
        targetRepresentation: DateRepresentation.iso8601,
        sourceTimeZone: 'UTC',
        targetTimeZone: 'UTC',
      ),
    );

    expect(result, isA<ChimeraFailure<DateOutput>>());
    final failure = result as ChimeraFailure<DateOutput>;
    expect(failure.kind, FailureKind.validation);
    expect(failure.code, 'date.invalid-value');
    expect(failure.messageKey, 'error.date.validation');
    expect(failure.details, isEmpty);
  });

  test('GivenOutOfRangeDateRequest_WhenServiceExecutes_ThenTypedRangeFailureIsReturned', () async {
    final result = await const DateService().execute(
      const DateRequest(
        value: '999999999999999999999',
        sourceRepresentation: DateRepresentation.unixMilliseconds,
        targetRepresentation: DateRepresentation.iso8601,
        sourceTimeZone: 'UTC',
        targetTimeZone: 'UTC',
      ),
    );

    expect(result, isA<ChimeraFailure<DateOutput>>());
    final failure = result as ChimeraFailure<DateOutput>;
    expect(failure.kind, FailureKind.range);
    expect(failure.code, 'date.out-of-range');
    expect(failure.messageKey, 'error.date.range');
  });
}
