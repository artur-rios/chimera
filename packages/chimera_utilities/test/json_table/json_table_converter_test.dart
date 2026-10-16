import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('JsonTableConverter', () {
    test('GivenHeterogeneousObjectArray_WhenConverted_ThenColumnsUseFirstSeenOrder', () {
      final table = const JsonTableConverter().convert(
        const JsonTableRequest(
          source: '[{"name":"Ada","active":true},{"age":37,"name":"Lin"}]',
          includeRowNumbers: false,
        ),
      );

      expect(table.columns, <String>['name', 'active', 'age']);
      expect(table.rows, <List<String>>[
        <String>['Ada', 'true', ''],
        <String>['Lin', '', '37'],
      ]);
    });

    test(
      'GivenNestedValuesAndNull_WhenConverted_ThenStructureIsSerializedAsJson',
      () {
        final table = const JsonTableConverter().convert(
          const JsonTableRequest(
            source: '[{"meta":{"x":1},"tags":["a","b"],"value":null}]',
            includeRowNumbers: true,
          ),
        );

        expect(table.includeRowNumbers, isTrue);
        expect(table.rows.single, <String>['{"x":1}', '["a","b"]', 'null']);
      },
    );

    test('GivenEmptyArray_WhenConverted_ThenEmptyTableIsReturned', () {
      final table = const JsonTableConverter().convert(
        const JsonTableRequest(source: '[]', includeRowNumbers: false),
      );

      expect(table.columns, isEmpty);
      expect(table.rows, isEmpty);
    });

    test('GivenUnicodeAndEscapes_WhenConverted_ThenStringValueIsDecoded', () {
      final table = const JsonTableConverter().convert(
        const JsonTableRequest(
          source: r'[{"text":"Ol\u00e1\n\u4e16\u754c"}]',
          includeRowNumbers: false,
        ),
      );

      expect(table.rows.single.single, 'Ol\u00e1\n\u4e16\u754c');
    });

    test('GivenMalformedJson_WhenConverted_ThenOffsetAwareValidationFailureIsThrown', () {
      expect(
        () => const JsonTableConverter().convert(
          const JsonTableRequest(
            source: '[{"name":}]',
            includeRowNumbers: false,
          ),
        ),
        throwsA(
          isA<JsonTableException>()
              .having(
                (error) => error.kind,
                'kind',
                JsonTableFailureKind.validation,
              )
              .having((error) => error.code, 'code', 'json-table.invalid-json')
              .having((error) => error.offset, 'offset', isNotNull),
        ),
      );
    });

    test(
      'GivenNonArrayJson_WhenConverted_ThenRootPathValidationFailureIsThrown',
      () {
        expect(
          () => const JsonTableConverter().convert(
            const JsonTableRequest(
              source: '{"name":"Ada"}',
              includeRowNumbers: false,
            ),
          ),
          throwsA(
            isA<JsonTableException>()
                .having((error) => error.code, 'code', 'json-table.not-array')
                .having((error) => error.path, 'path', r'$'),
          ),
        );
      },
    );

    test('GivenNonObjectMember_WhenConverted_ThenIndexedPathValidationFailureIsThrown', () {
      expect(
        () => const JsonTableConverter().convert(
          const JsonTableRequest(
            source: '[{"name":"Ada"},42]',
            includeRowNumbers: false,
          ),
        ),
        throwsA(
          isA<JsonTableException>()
              .having((error) => error.code, 'code', 'json-table.not-object')
              .having((error) => error.path, 'path', r'$[1]'),
        ),
      );
    });

    test('GivenCellBudgetExceeded_WhenConverted_ThenResourceFailureHasNoPartialTable', () {
      expect(
        () => const JsonTableConverter(maxCells: 3).convert(
          const JsonTableRequest(
            source: '[{"a":1,"b":2},{"a":3,"b":4}]',
            includeRowNumbers: false,
          ),
        ),
        throwsA(
          isA<JsonTableException>()
              .having(
                (error) => error.kind,
                'kind',
                JsonTableFailureKind.resource,
              )
              .having(
                (error) => error.code,
                'code',
                'json-table.resource-limit',
              ),
        ),
      );
    });

    test(
      'GivenUnsupportedJsonNumber_WhenConverted_ThenOffsetAwareFailureIsThrown',
      () {
        for (final source in <String>[
          '[{"value":1e400}]',
          '[{"value":1e-400}]',
          '[{"value":-1e-400}]',
          '[{"value":9007199254740992}]',
        ]) {
          expect(
            () => const JsonTableConverter().convert(
              JsonTableRequest(source: source, includeRowNumbers: false),
            ),
            throwsA(
              isA<JsonTableException>()
                  .having(
                    (error) => error.code,
                    'code',
                    'json-table.unsupported-number',
                  )
                  .having((error) => error.offset, 'offset', isNotNull),
            ),
          );
        }
      },
    );

    test('GivenInvalidStructureWithUnsupportedNumber_WhenConverted_ThenPathFailureWins', () {
      expect(
        () => const JsonTableConverter().convert(
          const JsonTableRequest(source: '1e400', includeRowNumbers: false),
        ),
        throwsA(
          isA<JsonTableException>()
              .having((error) => error.code, 'code', 'json-table.not-array')
              .having((error) => error.path, 'path', r'$'),
        ),
      );
      expect(
        () => const JsonTableConverter().convert(
          const JsonTableRequest(source: '[1e400]', includeRowNumbers: false),
        ),
        throwsA(
          isA<JsonTableException>()
              .having((error) => error.code, 'code', 'json-table.not-object')
              .having((error) => error.path, 'path', r'$[0]'),
        ),
      );
    });

    test('GivenEmptyObjects_WhenConverted_ThenRowIdentityIsPreserved', () {
      final table = const JsonTableConverter().convert(
        const JsonTableRequest(source: '[{},{}]', includeRowNumbers: true),
      );

      expect(table.columns, isEmpty);
      expect(table.rows, <List<String>>[<String>[], <String>[]]);
    });
  });
}
