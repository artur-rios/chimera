import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('JsonFormatter', () {
    test('GivenNestedValue_WhenFormatted_ThenTwoSpaceJsonIsStable', () {
      final result = const JsonFormatter().format(
        const JsonFormatRequest(
          source: '{"name":"Ada","active":true,"meta":{"count":2}}',
          indent: 2,
        ),
      );

      expect(
        result.formatted,
        '{\n'
        '  "name": "Ada",\n'
        '  "active": true,\n'
        '  "meta": {\n'
        '    "count": 2\n'
        '  }\n'
        '}',
      );
      expect(result.indent, 2);
    });

    test('GivenEveryJsonRootKind_WhenFormatted_ThenMeaningIsPreserved', () {
      for (final source in <String>[
        '[1,"two",false,null]',
        '"hello"',
        '42',
        'true',
        'null',
      ]) {
        final result = const JsonFormatter().format(
          JsonFormatRequest(source: source, indent: 2),
        );

        expect(
          jsonDecode(result.formatted),
          jsonDecode(source),
          reason: source,
        );
      }
    });

    test('GivenFourSpaceIndent_WhenFormatted_ThenNestedIndentIsFourSpaces', () {
      final result = const JsonFormatter().format(
        const JsonFormatRequest(source: '{"outer":{"inner":1}}', indent: 4),
      );

      expect(result.formatted, contains('\n        "inner": 1'));
    });

    test('GivenEscapedAndUnicodeText_WhenFormatted_ThenTextRoundTrips', () {
      final result = const JsonFormatter().format(
        const JsonFormatRequest(
          source: r'{"value":"Olá\n\"Chimera\""}',
          indent: 2,
        ),
      );

      expect(
        (jsonDecode(result.formatted) as Map<String, Object?>)['value'],
        'Olá\n"Chimera"',
      );
    });

    test('GivenUnicodeEscape_WhenFormatted_ThenEscapeLexemeIsPreserved', () {
      final result = const JsonFormatter().format(
        const JsonFormatRequest(source: r'{"value":"\uDEAD"}', indent: 2),
      );

      expect(result.formatted, '{\n  "value": "\\uDEAD"\n}');
    });

    test('GivenExtremeNumbers_WhenFormatted_ThenLexemesRemainExact', () {
      final result = const JsonFormatter().format(
        const JsonFormatRequest(
          source: '{"large":9007199254740993,"underflow":1e-400}',
          indent: 2,
        ),
      );

      expect(
        result.formatted,
        '{\n'
        '  "large": 9007199254740993,\n'
        '  "underflow": 1e-400\n'
        '}',
      );
    });

    test('GivenInvalidIndent_WhenFormatted_ThenValidationFailureIsThrown', () {
      expect(
        () => const JsonFormatter().format(
          const JsonFormatRequest(source: '{}', indent: 3),
        ),
        throwsA(
          isA<JsonFormatException>()
              .having(
                (error) => error.kind,
                'kind',
                JsonFormatFailureKind.validation,
              )
              .having(
                (error) => error.code,
                'code',
                'json-format.invalid-indent',
              ),
        ),
      );
    });

    test(
      'GivenMalformedJson_WhenFormatted_ThenLocationAndReasonAreReturned',
      () {
        expect(
          () => const JsonFormatter().format(
            const JsonFormatRequest(source: '{"secret":}', indent: 2),
          ),
          throwsA(
            isA<JsonFormatException>()
                .having(
                  (error) => error.code,
                  'code',
                  'json-format.invalid-json',
                )
                .having((error) => error.offset, 'offset', isNotNull)
                .having((error) => error.reason, 'reason', isNotEmpty)
                .having(
                  (error) => error.reason,
                  'redacted reason',
                  isNot(contains('secret')),
                ),
          ),
        );
      },
    );

    test(
      'GivenResourceBudgetExceeded_WhenFormatted_ThenNoResultIsReturned',
      () {
        final cases = <JsonFormatter, String>{
          const JsonFormatter(maxSourceChars: 1): '{"a":1}',
          const JsonFormatter(maxNodes: 1): '[1,2]',
          const JsonFormatter(maxDepth: 1): '[[1]]',
          const JsonFormatter(maxOutputChars: 1): '{"a":1}',
        };

        for (final entry in cases.entries) {
          expect(
            () => entry.key.format(
              JsonFormatRequest(source: entry.value, indent: 2),
            ),
            throwsA(
              isA<JsonFormatException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    JsonFormatFailureKind.resource,
                  )
                  .having(
                    (error) => error.code,
                    'code',
                    'json-format.resource-limit',
                  ),
            ),
          );
        }
      },
    );

    test('GivenLargeArray_WhenNodeBudgetReached_ThenParsingStops', () {
      final source = '[${List.filled(1000, '0').join(',')}]';

      expect(
        () =>
            const JsonFormatter(maxNodes: 10)
                .format(JsonFormatRequest(source: source, indent: 2)),
        throwsA(
          isA<JsonFormatException>().having(
            (error) => error.code,
            'code',
            'json-format.resource-limit',
          ),
        ),
      );
    });

    test('GivenDeepInput_WhenDepthBudgetReached_ThenParsingStops', () {
      final source = '${'[' * 1000}0${']' * 1000}';

      expect(
        () =>
            const JsonFormatter(maxDepth: 10)
                .format(JsonFormatRequest(source: source, indent: 2)),
        throwsA(
          isA<JsonFormatException>().having(
            (error) => error.code,
            'code',
            'json-format.resource-limit',
          ),
        ),
      );
    });
  });
}
