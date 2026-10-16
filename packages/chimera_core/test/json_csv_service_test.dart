import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenValidRows_WhenCsvServiceExecutes_ThenStableOutputIsReturned',
    () async {
      final result = await const JsonCsvService().execute(
        const JsonCsvOperationRequest(
          source: '[{"name":"Ada"},{"name":"Lin","active":true}]',
          delimiter: 'semicolon',
          includeHeaders: true,
        ),
      );

      final output = (result as ChimeraSuccess<JsonCsvOutput>).value;
      expect(output.csv, 'name;active\r\nAda;\r\nLin;true');
      expect(output.toJson(), <String, Object?>{
        'csv': 'name;active\r\nAda;\r\nLin;true',
        'columns': <String>['name', 'active'],
        'delimiter': 'semicolon',
        'includeHeaders': true,
        'rowCount': 2,
      });
    },
  );

  test('GivenInvalidDelimiter_WhenCsvServiceExecutes_ThenValidationFailureIsReturned', () async {
    final result = await const JsonCsvService().execute(
      const JsonCsvOperationRequest(
        source: '[]',
        delimiter: 'colon',
        includeHeaders: true,
      ),
    );

    final failure = result as ChimeraFailure<JsonCsvOutput>;
    expect(failure.kind, FailureKind.validation);
    expect(failure.code, 'json-csv.invalid-delimiter');
    expect(failure.messageKey, 'error.jsonCsv.validation');
  });

  test('GivenMalformedJson_WhenCsvServiceExecutes_ThenOffsetIsReturnedWithoutInput', () async {
    final result = await const JsonCsvService().execute(
      const JsonCsvOperationRequest(
        source: '[{"secret":}]',
        delimiter: 'comma',
        includeHeaders: true,
      ),
    );

    final failure = result as ChimeraFailure<JsonCsvOutput>;
    expect(failure.details['offset'], isA<int>());
    expect(failure.details.values, isNot(contains('secret')));
  });

  test('GivenCellBudgetExceeded_WhenCsvServiceExecutes_ThenResourceFailureIsReturned', () async {
    final result =
        await const JsonCsvService(converter: JsonCsvConverter(maxCells: 1))
            .execute(
              const JsonCsvOperationRequest(
                source: '[{"a":1},{"a":2}]',
                delimiter: 'comma',
                includeHeaders: true,
              ),
            );

    final failure = result as ChimeraFailure<JsonCsvOutput>;
    expect(failure.kind, FailureKind.resource);
    expect(failure.code, 'json-csv.resource-limit');
    expect(failure.messageKey, 'error.jsonCsv.resource');
  });
}
