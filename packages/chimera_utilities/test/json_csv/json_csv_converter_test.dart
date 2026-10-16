import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('JsonCsvConverter', () {
    test('GivenHeterogeneousRows_WhenConverted_ThenColumnsAndMissingFieldsAreDeterministic', () {
      final result = const JsonCsvConverter().convert(
        const JsonCsvRequest(
          source: '[{"name":"Ada","active":true},{"age":37,"name":"Lin"}]',
          delimiter: 'comma',
          includeHeaders: true,
        ),
      );

      expect(result.columns, <String>['name', 'active', 'age']);
      expect(result.rowCount, 2);
      expect(result.csv, 'name,active,age\r\nAda,true,\r\nLin,,37');
    });

    test('GivenReservedCharacters_WhenConverted_ThenFieldsUseCsvQuoting', () {
      final result = const JsonCsvConverter().convert(
        const JsonCsvRequest(
          source: r'[{"value":"comma, quote \" and\nline"}]',
          delimiter: 'comma',
          includeHeaders: true,
        ),
      );

      expect(result.csv, 'value\r\n"comma, quote "" and\nline"');
    });

    test('GivenNestedValues_WhenConverted_ThenCompactJsonIsPreserved', () {
      final result = const JsonCsvConverter().convert(
        const JsonCsvRequest(
          source: '[{"meta":{"x":1},"tags":["a","b"],"value":null}]',
          delimiter: 'semicolon',
          includeHeaders: true,
        ),
      );

      expect(result.csv, 'meta;tags;value\r\n"{""x"":1}";"[""a"",""b""]";null');
    });

    test('GivenHeadersDisabled_WhenConverted_ThenOnlyDataRowsAreReturned', () {
      final result = const JsonCsvConverter().convert(
        const JsonCsvRequest(
          source: '[{"a":"x","b":"y"}]',
          delimiter: 'tab',
          includeHeaders: false,
        ),
      );

      expect(result.csv, 'x\ty');
      expect(result.includeHeaders, isFalse);
    });

    test('GivenHeaderlessEmptyField_WhenConverted_ThenRowDoesNotCollapse', () {
      final result = const JsonCsvConverter().convert(
        const JsonCsvRequest(
          source: '[{"value":""}]',
          delimiter: 'comma',
          includeHeaders: false,
        ),
      );

      expect(result.csv, '""');
      expect(result.rowCount, 1);
    });

    test(
      'GivenEverySupportedDelimiter_WhenParsed_ThenItsCharacterIsStable',
      () {
        expect(JsonCsvDelimiter.tryParse('comma')?.character, ',');
        expect(JsonCsvDelimiter.tryParse('semicolon')?.character, ';');
        expect(JsonCsvDelimiter.tryParse('tab')?.character, '\t');
        expect(JsonCsvDelimiter.tryParse('pipe')?.character, '|');
      },
    );

    test(
      'GivenUnsupportedDelimiter_WhenConverted_ThenOptionFailureIsThrown',
      () {
        expect(
          () => const JsonCsvConverter().convert(
            const JsonCsvRequest(
              source: '[]',
              delimiter: 'colon',
              includeHeaders: true,
            ),
          ),
          throwsA(
            isA<JsonCsvException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  JsonCsvFailureKind.validation,
                )
                .having(
                  (error) => error.code,
                  'code',
                  'json-csv.invalid-delimiter',
                ),
          ),
        );
      },
    );

    test('GivenMalformedJson_WhenConverted_ThenOffsetFailureIsThrown', () {
      expect(
        () => const JsonCsvConverter().convert(
          const JsonCsvRequest(
            source: '[{"name":}]',
            delimiter: 'comma',
            includeHeaders: true,
          ),
        ),
        throwsA(
          isA<JsonCsvException>()
              .having((error) => error.code, 'code', 'json-csv.invalid-json')
              .having((error) => error.offset, 'offset', isNotNull),
        ),
      );
    });

    test(
      'GivenNonObjectMember_WhenConverted_ThenIndexedPathFailureIsThrown',
      () {
        expect(
          () => const JsonCsvConverter().convert(
            const JsonCsvRequest(
              source: '[{"name":"Ada"},false]',
              delimiter: 'comma',
              includeHeaders: true,
            ),
          ),
          throwsA(
            isA<JsonCsvException>()
                .having((error) => error.code, 'code', 'json-csv.not-object')
                .having((error) => error.path, 'path', r'$[1]'),
          ),
        );
      },
    );

    test('GivenUnsupportedNumber_WhenConverted_ThenOffsetFailureIsThrown', () {
      expect(
        () => const JsonCsvConverter().convert(
          const JsonCsvRequest(
            source: '[{"value":1e400}]',
            delimiter: 'comma',
            includeHeaders: true,
          ),
        ),
        throwsA(
          isA<JsonCsvException>()
              .having(
                (error) => error.code,
                'code',
                'json-csv.unsupported-number',
              )
              .having((error) => error.offset, 'offset', isNotNull),
        ),
      );
    });

    test('GivenEmptyArray_WhenConverted_ThenEmptyCsvIsReturned', () {
      final result = const JsonCsvConverter().convert(
        const JsonCsvRequest(
          source: '[]',
          delimiter: 'pipe',
          includeHeaders: true,
        ),
      );

      expect(result.csv, isEmpty);
      expect(result.columns, isEmpty);
      expect(result.rowCount, 0);
    });

    test(
      'GivenRowsWithoutColumns_WhenConverted_ThenBlankRecordsArePreserved',
      () {
        final result = const JsonCsvConverter().convert(
          const JsonCsvRequest(
            source: '[{},{}]',
            delimiter: 'comma',
            includeHeaders: true,
          ),
        );

        expect(result.csv, '""\r\n""');
        expect(result.rowCount, 2);
      },
    );

    test(
      'GivenCellBudgetExceeded_WhenConverted_ThenResourceFailureIsThrown',
      () {
        expect(
          () => const JsonCsvConverter(maxCells: 1).convert(
            const JsonCsvRequest(
              source: '[{"a":1},{"a":2}]',
              delimiter: 'comma',
              includeHeaders: true,
            ),
          ),
          throwsA(
            isA<JsonCsvException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  JsonCsvFailureKind.resource,
                )
                .having(
                  (error) => error.code,
                  'code',
                  'json-csv.resource-limit',
                ),
          ),
        );
      },
    );
  });
}
