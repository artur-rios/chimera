import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('JsonYamlConverter', () {
    test('GivenNestedObject_WhenConverted_ThenYamlAndOptionsAreStable', () {
      final result = const JsonYamlConverter().convert(
        const JsonYamlRequest(
          source: '{"name":"Ada","active":true,"meta":{"count":2}}',
          indent: 2,
          quoteStrings: true,
        ),
      );

      expect(result.yaml, 'name: "Ada"\nactive: true\nmeta:\n  count: 2');
      expect(result.indent, 2);
      expect(result.quoteStrings, isTrue);
    });

    test('GivenEveryJsonRootKind_WhenConverted_ThenEachIsSupported', () {
      for (final source in <String>[
        '[1,"two",false,null]',
        '"hello"',
        '42',
        'true',
        'null',
      ]) {
        expect(
          const JsonYamlConverter()
              .convert(
                JsonYamlRequest(source: source, indent: 2, quoteStrings: false),
              )
              .yaml,
          isNotEmpty,
          reason: source,
        );
      }
    });

    test('GivenFourSpaceIndent_WhenConverted_ThenNestedYamlUsesFourSpaces', () {
      final result = const JsonYamlConverter().convert(
        const JsonYamlRequest(
          source: '{"outer":{"inner":1}}',
          indent: 4,
          quoteStrings: false,
        ),
      );

      expect(result.yaml, contains('\n    inner: 1'));
    });

    test(
      'GivenMultilineAndSensitiveStrings_WhenConverted_ThenYamlRemainsValid',
      () {
        final result = const JsonYamlConverter().convert(
          const JsonYamlRequest(
            source: r'{"multiline":"one\ntwo","booleanLike":"true","empty":""}',
            indent: 2,
            quoteStrings: false,
          ),
        );

        expect(result.yaml, contains(r'multiline: "one\ntwo"'));
        expect(result.yaml, contains('booleanLike: "true"'));
        expect(result.yaml, contains('empty: ""'));
        expect((loadYaml(result.yaml) as YamlMap)['multiline'], 'one\ntwo');
      },
    );

    test('GivenYamlSensitiveKeys_WhenConverted_ThenKeysRoundTrip', () {
      final result = const JsonYamlConverter().convert(
        const JsonYamlRequest(
          source: '{"a: b":1,"#key":"value","true":"still a key"}',
          indent: 2,
          quoteStrings: false,
        ),
      );

      final decoded = loadYaml(result.yaml) as YamlMap;
      expect(decoded['a: b'], 1);
      expect(decoded['#key'], 'value');
      expect(decoded['true'], 'still a key');
    });

    test('GivenTypeLikeStrings_WhenConverted_ThenStringsRemainStrings', () {
      final result = const JsonYamlConverter().convert(
        const JsonYamlRequest(
          source:
              '{"hex":"0x10","boolean":"true","nothing":"null",'
              '"date":"2026-10-16"}',
          indent: 2,
          quoteStrings: false,
        ),
      );

      final decoded = loadYaml(result.yaml) as YamlMap;
      expect(decoded['hex'], allOf(isA<String>(), '0x10'));
      expect(decoded['boolean'], allOf(isA<String>(), 'true'));
      expect(decoded['nothing'], allOf(isA<String>(), 'null'));
      expect(decoded['date'], allOf(isA<String>(), '2026-10-16'));
    });

    test('GivenEscapedControls_WhenConverted_ThenValueRoundTrips', () {
      final result = const JsonYamlConverter().convert(
        const JsonYamlRequest(
          source: r'{"value":"\b\f\n\r\t\u0000\"\\"}',
          indent: 2,
          quoteStrings: false,
        ),
      );

      expect(
        (loadYaml(result.yaml) as YamlMap)['value'],
        '\b\f\n\r\t\u0000"\\',
      );
    });

    test('GivenForcedQuotesAndTrailingNewline_WhenConverted_ThenNoBlockScalarIsUsed', () {
      final result = const JsonYamlConverter().convert(
        const JsonYamlRequest(
          source: r'{"value":"one\ntwo\n"}',
          indent: 2,
          quoteStrings: true,
        ),
      );

      expect(result.yaml, r'value: "one\ntwo\n"');
      expect((loadYaml(result.yaml) as YamlMap)['value'], 'one\ntwo\n');
    });

    test('GivenInvalidIndent_WhenConverted_ThenValidationFailureIsThrown', () {
      expect(
        () => const JsonYamlConverter().convert(
          const JsonYamlRequest(source: '{}', indent: 3, quoteStrings: false),
        ),
        throwsA(
          isA<JsonYamlException>()
              .having(
                (error) => error.kind,
                'kind',
                JsonYamlFailureKind.validation,
              )
              .having(
                (error) => error.code,
                'code',
                'json-yaml.invalid-indent',
              ),
        ),
      );
    });

    test('GivenMalformedJson_WhenConverted_ThenOffsetFailureIsThrown', () {
      expect(
        () => const JsonYamlConverter().convert(
          const JsonYamlRequest(
            source: '{"secret":}',
            indent: 2,
            quoteStrings: false,
          ),
        ),
        throwsA(
          isA<JsonYamlException>()
              .having((error) => error.code, 'code', 'json-yaml.invalid-json')
              .having((error) => error.offset, 'offset', isNotNull),
        ),
      );
    });

    test('GivenUnsupportedNumber_WhenConverted_ThenOffsetFailureIsThrown', () {
      expect(
        () => const JsonYamlConverter().convert(
          const JsonYamlRequest(
            source: '{"value":1e400}',
            indent: 2,
            quoteStrings: false,
          ),
        ),
        throwsA(
          isA<JsonYamlException>()
              .having(
                (error) => error.code,
                'code',
                'json-yaml.unsupported-number',
              )
              .having((error) => error.offset, 'offset', isNotNull),
        ),
      );
    });

    test('GivenVeryLongInteger_WhenConverted_ThenResourceLimitWins', () {
      final source = '{"value":${'9' * 100000}}';

      expect(
        () => const JsonYamlConverter().convert(
          JsonYamlRequest(source: source, indent: 2, quoteStrings: false),
        ),
        throwsA(
          isA<JsonYamlException>()
              .having(
                (error) => error.kind,
                'kind',
                JsonYamlFailureKind.resource,
              )
              .having(
                (error) => error.code,
                'code',
                'json-yaml.resource-limit',
              ),
        ),
      );
    });

    test('GivenVeryLongNumericToken_WhenConverted_ThenResourceLimitWins', () {
      final source = '{"value":1.${'0' * 5000}}';

      expect(
        () => const JsonYamlConverter().convert(
          JsonYamlRequest(source: source, indent: 2, quoteStrings: false),
        ),
        throwsA(
          isA<JsonYamlException>()
              .having(
                (error) => error.kind,
                'kind',
                JsonYamlFailureKind.resource,
              )
              .having(
                (error) => error.code,
                'code',
                'json-yaml.resource-limit',
              ),
        ),
      );
    });

    test('GivenInsignificantZeros_WhenConverted_ThenPrecisionIsNormalized', () {
      final accepted = const JsonYamlConverter().convert(
        const JsonYamlRequest(
          source: '{"value":1.234567890123450000}',
          indent: 2,
          quoteStrings: false,
        ),
      );

      expect((loadYaml(accepted.yaml) as YamlMap)['value'], 1.23456789012345);
      expect(
        () => const JsonYamlConverter().convert(
          const JsonYamlRequest(
            source: '{"value":1.234567890123456}',
            indent: 2,
            quoteStrings: false,
          ),
        ),
        throwsA(
          isA<JsonYamlException>().having(
            (error) => error.code,
            'code',
            'json-yaml.unsupported-number',
          ),
        ),
      );
    });

    test(
      'GivenLongCoefficientWithExponent_WhenNormalized_ThenItIsAccepted',
      () {
        final result = const JsonYamlConverter().convert(
          const JsonYamlRequest(
            source: '{"value":10000000000000000e-16}',
            indent: 2,
            quoteStrings: false,
          ),
        );

        expect((loadYaml(result.yaml) as YamlMap)['value'], 1);
      },
    );

    test(
      'GivenAnyResourceBudgetExceeded_WhenConverted_ThenNoYamlIsReturned',
      () {
        final cases = <JsonYamlConverter, String>{
          const JsonYamlConverter(maxSourceChars: 1): '{"a":1}',
          const JsonYamlConverter(maxNodes: 1): '[1,2]',
          const JsonYamlConverter(maxDepth: 1): '[[1]]',
          const JsonYamlConverter(maxOutputChars: 1): '{"a":1}',
        };

        for (final entry in cases.entries) {
          expect(
            () => entry.key.convert(
              JsonYamlRequest(
                source: entry.value,
                indent: 2,
                quoteStrings: false,
              ),
            ),
            throwsA(
              isA<JsonYamlException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    JsonYamlFailureKind.resource,
                  )
                  .having(
                    (error) => error.code,
                    'code',
                    'json-yaml.resource-limit',
                  ),
            ),
          );
        }
      },
    );

    test('GivenLargeArray_WhenNodeBudgetReached_ThenParsingStops', () {
      final source = '[${List.filled(1000, '0').join(',')}]';

      expect(
        () => const JsonYamlConverter(maxNodes: 10).convert(
          JsonYamlRequest(source: source, indent: 2, quoteStrings: false),
        ),
        throwsA(
          isA<JsonYamlException>().having(
            (error) => error.code,
            'code',
            'json-yaml.resource-limit',
          ),
        ),
      );
    });

    test('GivenDeepInput_WhenDepthBudgetReached_ThenParsingStops', () {
      final source = '${'[' * 1000}0${']' * 1000}';

      expect(
        () => const JsonYamlConverter(maxDepth: 10).convert(
          JsonYamlRequest(source: source, indent: 2, quoteStrings: false),
        ),
        throwsA(
          isA<JsonYamlException>().having(
            (error) => error.code,
            'code',
            'json-yaml.resource-limit',
          ),
        ),
      );
    });
  });
}
