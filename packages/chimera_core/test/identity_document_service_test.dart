import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test('GivenDefaults_WhenExecuted_ThenStableLabeledSsnJsonReturns', () async {
    final result = await IdentityDocumentService(
      generator: _generator('219099999'),
    ).execute(const IdentityDocumentOperationRequest());

    final output = (result as ChimeraSuccess<IdentityDocumentOutput>).value;
    expect(output.toJson(), {
      'locale': 'us',
      'type': 'ssn',
      'count': 1,
      'synthetic': true,
      'label': 'synthetic-test-data',
      'values': ['219-09-9999'],
    });
  });

  final successes =
      <
        String,
        (IdentityDocumentOperationRequest, String, Map<String, Object?>)
      >{
        'ssn': (
          const IdentityDocumentOperationRequest(locale: 'us', type: 'ssn'),
          '219099999',
          {'locale': 'us', 'type': 'ssn'},
        ),
        'itin': (
          const IdentityDocumentOperationRequest(locale: 'us', type: 'itin'),
          '900700000',
          {'locale': 'us', 'type': 'itin'},
        ),
        'ein': (
          const IdentityDocumentOperationRequest(locale: 'us', type: 'ein'),
          '200000000',
          {'locale': 'us', 'type': 'ein'},
        ),
        'cpf': (
          const IdentityDocumentOperationRequest(locale: 'br', type: 'cpf'),
          '28001238938',
          {'locale': 'br', 'type': 'cpf'},
        ),
        'cnpjNumeric': (
          const IdentityDocumentOperationRequest(
            locale: 'br',
            type: 'cnpj',
            cnpjFormat: 'numeric',
          ),
          '11222333000181',
          {'locale': 'br', 'type': 'cnpj', 'cnpjFormat': 'numeric'},
        ),
        'cnpjAlphanumeric': (
          const IdentityDocumentOperationRequest(
            locale: 'br',
            type: 'cnpj',
            cnpjFormat: 'alphanumeric',
          ),
          '12ABC34501DE35',
          {'locale': 'br', 'type': 'cnpj', 'cnpjFormat': 'alphanumeric'},
        ),
        'cnh': (
          const IdentityDocumentOperationRequest(locale: 'br', type: 'cnh'),
          '02650306461',
          {'locale': 'br', 'type': 'cnh'},
        ),
        'cin': (
          const IdentityDocumentOperationRequest(locale: 'br', type: 'cin'),
          '28001238938',
          {'locale': 'br', 'type': 'cin'},
        ),
      };

  for (final entry in successes.entries) {
    test(
      'Given${entry.key}_WhenExecuted_ThenRequestedDocumentReturns',
      () async {
        final result = await IdentityDocumentService(
          generator: _generator(entry.value.$2),
        ).execute(entry.value.$1);

        final output = (result as ChimeraSuccess<IdentityDocumentOutput>).value;
        expect(output.locale, entry.value.$3['locale']);
        expect(output.type, entry.value.$3['type']);
        expect(output.toJson(), containsPair('synthetic', true));
        for (final pair in entry.value.$3.entries) {
          expect(output.toJson(), containsPair(pair.key, pair.value));
        }
      },
    );
  }

  final invalid = <String, IdentityDocumentOperationRequest>{
    'Locale': const IdentityDocumentOperationRequest(locale: 'ca'),
    'Type': const IdentityDocumentOperationRequest(type: 'passport'),
    'LocaleType': const IdentityDocumentOperationRequest(
      locale: 'us',
      type: 'cpf',
    ),
    'RgJurisdiction': const IdentityDocumentOperationRequest(
      locale: 'br',
      type: 'rg',
    ),
    'CnpjFormat': const IdentityDocumentOperationRequest(
      locale: 'br',
      type: 'cnpj',
      cnpjFormat: 'legacy',
    ),
    'UnexpectedCnpjFormat': const IdentityDocumentOperationRequest(
      locale: 'br',
      type: 'cpf',
      cnpjFormat: 'numeric',
    ),
    'EmptyCount': const IdentityDocumentOperationRequest(count: ''),
    'ZeroCount': const IdentityDocumentOperationRequest(count: '0'),
    'SignedCount': const IdentityDocumentOperationRequest(count: '+1'),
    'WhitespaceCount': const IdentityDocumentOperationRequest(count: ' 1'),
    'DecimalCount': const IdentityDocumentOperationRequest(count: '1.0'),
  };

  for (final entry in invalid.entries) {
    test('GivenInvalid${entry.key}_WhenExecuted_ThenTypedValidation', () async {
      var calls = 0;
      final result = await IdentityDocumentService(
        generator: IdentityDocumentGenerator.forTesting(
          candidate: (_, _, _) {
            calls++;
            return 'PRIVATE';
          },
        ),
      ).execute(entry.value);

      final failure = result as ChimeraFailure<IdentityDocumentOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, startsWith('document.'));
      expect(failure.messageKey, 'error.document.validation');
      expect(calls, 0);
      if (entry.key == 'RgJurisdiction') {
        expect(failure.code, 'document.rg-jurisdiction-required');
      }
    });
  }

  test(
    'GivenCountAboveArbitraryCeiling_WhenExecuted_ThenExactBatchReturns',
    () async {
      final result = await IdentityDocumentService(
        generator: _generator('219099999'),
      ).execute(const IdentityDocumentOperationRequest(count: '1001'));

      expect(
        (result as ChimeraSuccess<IdentityDocumentOutput>).value.count,
        1001,
      );
    },
  );

  test(
    'GivenCandidateFailure_WhenExecuted_ThenRedactedProcessingFailure',
    () async {
      final result = await IdentityDocumentService(
        generator: IdentityDocumentGenerator.forTesting(
          candidate: (_, _, _) => throw StateError('PRIVATE DOCUMENT'),
        ),
      ).execute(const IdentityDocumentOperationRequest());

      final failure = result as ChimeraFailure<IdentityDocumentOutput>;
      expect(failure.kind, FailureKind.processing);
      expect(failure.code, 'document.source-unavailable');
      expect(failure.messageKey, 'error.document.processing');
      expect(failure.toString(), isNot(contains('PRIVATE')));
    },
  );

  test('GivenResourceFailure_WhenExecuted_ThenTypedResourceFailure', () async {
    final result = await IdentityDocumentService(
      generator: IdentityDocumentGenerator.forTesting(
        candidate: (_, _, _) => '219099999',
        allocate: (_) => throw OutOfMemoryError(),
      ),
    ).execute(const IdentityDocumentOperationRequest());

    final failure = result as ChimeraFailure<IdentityDocumentOutput>;
    expect(failure.kind, FailureKind.resource);
    expect(failure.code, 'document.resource-limit');
    expect(failure.messageKey, 'error.document.resource');
  });
}

IdentityDocumentGenerator _generator(String value) =>
    IdentityDocumentGenerator.forTesting(candidate: (_, _, _) => value);
