import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('NumberBaseConverter', () {
    const converter = NumberBaseConverter();

    test('GivenSupportedBases_WhenConverted_ThenKnownAnswersAreCanonical', () {
      final cases = <NumberBaseRequest, String>{
        const NumberBaseRequest(value: '255', sourceBase: 10, targetBase: 16):
            'ff',
        const NumberBaseRequest(value: '101010', sourceBase: 2, targetBase: 36):
            '16',
        const NumberBaseRequest(value: 'ZZ', sourceBase: 36, targetBase: 10):
            '1295',
        const NumberBaseRequest(
          value: '184467440737095516160',
          sourceBase: 10,
          targetBase: 16,
        ): 'a0000000000000000',
      };

      for (final entry in cases.entries) {
        final result = converter.convert(entry.key);

        expect(result.converted, entry.value);
        expect(result.sourceBase, entry.key.sourceBase);
        expect(result.targetBase, entry.key.targetBase);
      }
    });

    test(
      'GivenEverySupportedBase_WhenDigitsRoundTrip_ThenBoundariesAreEnforced',
      () {
        for (var base = 2; base <= 36; base++) {
          final highestDigit = _digitFor(base - 1);
          final decimal = converter.convert(
            NumberBaseRequest(
              value: highestDigit,
              sourceBase: base,
              targetBase: 10,
            ),
          );
          expect(decimal.converted, '${base - 1}', reason: 'base $base');

          final source = '${base * base + base - 1}';
          final encoded = converter.convert(
            NumberBaseRequest(value: source, sourceBase: 10, targetBase: base),
          );
          final roundTrip = converter.convert(
            NumberBaseRequest(
              value: encoded.converted,
              sourceBase: base,
              targetBase: 10,
            ),
          );
          expect(roundTrip.converted, source, reason: 'base $base round trip');

          final firstInvalid = base < 36 ? _digitFor(base) : '{';
          expect(
            () => converter.convert(
              NumberBaseRequest(
                value: firstInvalid,
                sourceBase: base,
                targetBase: 10,
              ),
            ),
            _numberBaseFailure(
              kind: NumberBaseFailureKind.validation,
              code: 'number-base.invalid-value',
              field: 'value',
              reason: 'invalid-digit',
            ),
            reason: 'base $base first invalid digit',
          );
        }
      },
    );

    test(
      'GivenSignsAndLeadingZeroes_WhenConverted_ThenRepresentationIsNormalized',
      () {
        final cases = <String, String>{
          '-000255': '-ff',
          '+000255': 'ff',
          '-0': '0',
          '+000': '0',
        };

        for (final entry in cases.entries) {
          final result = converter.convert(
            NumberBaseRequest(value: entry.key, sourceBase: 10, targetBase: 16),
          );

          expect(result.converted, entry.value);
        }
      },
    );

    test('GivenUppercaseSameBaseInput_WhenConverted_ThenOutputIsLowercaseCanonical', () {
      final result = converter.convert(
        const NumberBaseRequest(
          value: '000AbC',
          sourceBase: 16,
          targetBase: 16,
        ),
      );

      expect(result.converted, 'abc');
    });

    test('GivenSurroundingWhitespace_WhenConverted_ThenValueIsTrimmed', () {
      final result = converter.convert(
        const NumberBaseRequest(
          value: '\n +00FF \t',
          sourceBase: 16,
          targetBase: 10,
        ),
      );

      expect(result.converted, '255');
    });

    test(
      'GivenPrefixLookingText_WhenBaseChanges_ThenCharactersAreOrdinaryDigits',
      () {
        expect(
          () => converter.convert(
            const NumberBaseRequest(
              value: '0x10',
              sourceBase: 16,
              targetBase: 10,
            ),
          ),
          _numberBaseFailure(
            kind: NumberBaseFailureKind.validation,
            code: 'number-base.invalid-value',
            field: 'value',
            reason: 'invalid-digit',
          ),
        );

        final base36 = converter.convert(
          const NumberBaseRequest(
            value: '0x10',
            sourceBase: 36,
            targetBase: 10,
          ),
        );
        expect(base36.converted, '42804');
      },
    );

    test(
      'GivenInvalidBases_WhenConverted_ThenSourceBeforeTargetFailureIsReturned',
      () {
        expect(
          () => converter.convert(
            const NumberBaseRequest(value: '1', sourceBase: 1, targetBase: 37),
          ),
          _numberBaseFailure(
            kind: NumberBaseFailureKind.validation,
            code: 'number-base.invalid-base',
            field: 'sourceBase',
            reason: 'out-of-range-base',
          ),
        );
        expect(
          () => converter.convert(
            const NumberBaseRequest(value: '1', sourceBase: 10, targetBase: 37),
          ),
          _numberBaseFailure(
            kind: NumberBaseFailureKind.validation,
            code: 'number-base.invalid-base',
            field: 'targetBase',
            reason: 'out-of-range-base',
          ),
        );
      },
    );

    test(
      'GivenMissingOrInvalidDigits_WhenConverted_ThenTypedFailureIsReturned',
      () {
        for (final value in <String>['', ' ', '+', '-', '  +  ']) {
          expect(
            () => converter.convert(
              NumberBaseRequest(value: value, sourceBase: 10, targetBase: 2),
            ),
            _numberBaseFailure(
              kind: NumberBaseFailureKind.validation,
              code: 'number-base.invalid-value',
              field: 'value',
              reason: 'missing-value',
            ),
          );
        }
        for (final request in <NumberBaseRequest>[
          const NumberBaseRequest(value: '2', sourceBase: 2, targetBase: 10),
          const NumberBaseRequest(value: 'F F', sourceBase: 16, targetBase: 10),
          const NumberBaseRequest(value: '1_0', sourceBase: 10, targetBase: 2),
          const NumberBaseRequest(value: 'é', sourceBase: 36, targetBase: 10),
        ]) {
          expect(
            () => converter.convert(request),
            _numberBaseFailure(
              kind: NumberBaseFailureKind.validation,
              code: 'number-base.invalid-value',
              field: 'value',
              reason: 'invalid-digit',
            ),
          );
        }
      },
    );

    test(
      'GivenRawInputBudget_WhenAtOrBeyondBoundary_ThenNoOversizedInputIsParsed',
      () {
        final exact = const NumberBaseConverter(maxInputCharacters: 3).convert(
          const NumberBaseRequest(value: ' 1 ', sourceBase: 10, targetBase: 2),
        );
        expect(exact.converted, '1');

        expect(
          () => const NumberBaseConverter(maxInputCharacters: 2).convert(
            const NumberBaseRequest(
              value: ' 1 ',
              sourceBase: 10,
              targetBase: 2,
            ),
          ),
          _numberBaseFailure(
            kind: NumberBaseFailureKind.resource,
            code: 'number-base.resource-limit',
            field: 'value',
            reason: 'input-limit',
          ),
        );
      },
    );

    test(
      'GivenOutputBudget_WhenAtOrBeyondBoundary_ThenNoPartialOutputIsReturned',
      () {
        final exact = const NumberBaseConverter(maxOutputCharacters: 3).convert(
          const NumberBaseRequest(
            value: '-255',
            sourceBase: 10,
            targetBase: 16,
          ),
        );
        expect(exact.converted, '-ff');

        expect(
          () => const NumberBaseConverter(maxOutputCharacters: 2).convert(
            const NumberBaseRequest(
              value: '-255',
              sourceBase: 10,
              targetBase: 16,
            ),
          ),
          _numberBaseFailure(
            kind: NumberBaseFailureKind.resource,
            code: 'number-base.resource-limit',
            field: 'converted',
            reason: 'output-limit',
          ),
        );
        expect(
          () => const NumberBaseConverter(maxOutputCharacters: 0).convert(
            const NumberBaseRequest(value: '0', sourceBase: 10, targetBase: 2),
          ),
          _numberBaseFailure(
            kind: NumberBaseFailureKind.resource,
            code: 'number-base.resource-limit',
            field: 'converted',
            reason: 'output-limit',
          ),
        );
      },
    );
  });
}

String _digitFor(int value) =>
    String.fromCharCode(value < 10 ? 0x30 + value : 0x61 + value - 10);

Matcher _numberBaseFailure({
  required NumberBaseFailureKind kind,
  required String code,
  required String field,
  required String reason,
}) => throwsA(
  isA<NumberBaseException>()
      .having((error) => error.kind, 'kind', kind)
      .having((error) => error.code, 'code', code)
      .having((error) => error.field, 'field', field)
      .having((error) => error.reason, 'reason', reason),
);
