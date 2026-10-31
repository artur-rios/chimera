import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const validator = IdentityDocumentValidator();

  final knownAnswers =
      <(IdentityLocale, IdentityDocumentType, CnpjFormat, String)>[
        (
          IdentityLocale.us,
          IdentityDocumentType.ssn,
          CnpjFormat.alphanumeric,
          '219-09-9999',
        ),
        (
          IdentityLocale.us,
          IdentityDocumentType.itin,
          CnpjFormat.alphanumeric,
          '900-70-0000',
        ),
        (
          IdentityLocale.us,
          IdentityDocumentType.ein,
          CnpjFormat.alphanumeric,
          '20-0000000',
        ),
        (
          IdentityLocale.br,
          IdentityDocumentType.cpf,
          CnpjFormat.alphanumeric,
          '280.012.389-38',
        ),
        (
          IdentityLocale.br,
          IdentityDocumentType.cnpj,
          CnpjFormat.numeric,
          '11.222.333/0001-81',
        ),
        (
          IdentityLocale.br,
          IdentityDocumentType.cnpj,
          CnpjFormat.alphanumeric,
          '12.ABC.345/01DE-35',
        ),
        (
          IdentityLocale.br,
          IdentityDocumentType.cnh,
          CnpjFormat.alphanumeric,
          '02650306461',
        ),
        (
          IdentityLocale.br,
          IdentityDocumentType.cin,
          CnpjFormat.alphanumeric,
          '280.012.389-38',
        ),
      ];

  for (final answer in knownAnswers) {
    test(
      'Given${answer.$2.name}${answer.$3.name}KnownAnswer_WhenValidated_ThenAccepted',
      () {
        expect(
          validator.isValid(
            locale: answer.$1,
            type: answer.$2,
            cnpjFormat: answer.$3,
            value: answer.$4,
          ),
          isTrue,
        );
      },
    );

    if ({
      IdentityDocumentType.cpf,
      IdentityDocumentType.cnpj,
      IdentityDocumentType.cnh,
      IdentityDocumentType.cin,
    }.contains(answer.$2)) {
      test(
        'Given${answer.$2.name}${answer.$3.name}ChecksumMutation_WhenValidated_ThenRejected',
        () {
          final last = answer.$4.endsWith('0') ? '1' : '0';
          final mutation =
              '${answer.$4.substring(0, answer.$4.length - 1)}$last';
          expect(
            validator.isValid(
              locale: answer.$1,
              type: answer.$2,
              cnpjFormat: answer.$3,
              value: mutation,
            ),
            isFalse,
          );
        },
      );
    }
  }

  for (final invalid in [
    '000-12-1234',
    '666-12-1234',
    '900-12-1234',
    '123-00-1234',
    '123-12-0000',
  ]) {
    test('GivenInvalidSsn${invalid}_WhenValidated_ThenRejected', () {
      expect(
        validator.isValid(
          locale: IdentityLocale.us,
          type: IdentityDocumentType.ssn,
          value: invalid,
        ),
        isFalse,
      );
    });
  }

  for (final invalid in [
    '800-70-0000',
    '900-49-0000',
    '900-66-0000',
    '900-89-0000',
    '900-93-0000',
  ]) {
    test('GivenInvalidItin${invalid}_WhenValidated_ThenRejected', () {
      expect(
        validator.isValid(
          locale: IdentityLocale.us,
          type: IdentityDocumentType.itin,
          value: invalid,
        ),
        isFalse,
      );
    });
  }

  test('GivenInvalidEinPrefix_WhenValidated_ThenRejected', () {
    expect(
      validator.isValid(
        locale: IdentityLocale.us,
        type: IdentityDocumentType.ein,
        value: '00-0000000',
      ),
      isFalse,
    );
  });

  for (final entry in <IdentityDocumentType, String>{
    IdentityDocumentType.cpf: '111.111.111-11',
    IdentityDocumentType.cnpj: '00.000.000/0000-00',
    IdentityDocumentType.cnh: '00000000000',
    IdentityDocumentType.cin: '111.111.111-11',
  }.entries) {
    test('GivenRepeated${entry.key.name}_WhenValidated_ThenRejected', () {
      expect(
        validator.isValid(
          locale: IdentityLocale.br,
          type: entry.key,
          cnpjFormat: entry.key == IdentityDocumentType.cnpj
              ? CnpjFormat.numeric
              : CnpjFormat.alphanumeric,
          value: entry.value,
        ),
        isFalse,
      );
    });
  }

  for (final entry in knownAnswers) {
    test(
      'Given${entry.$2.name}_WhenGenerated_ThenCanonicalLabeledBatchReturns',
      () {
        final raw = entry.$4.replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final result =
            IdentityDocumentGenerator.forTesting(candidate: (_, _, _) => raw)
                .generate(
                  IdentityDocumentRequest(
                    locale: entry.$1,
                    type: entry.$2,
                    cnpjFormat: entry.$3,
                    count: 2,
                  ),
                );

        expect(result.values, [entry.$4, entry.$4]);
        expect(result.locale, entry.$1);
        expect(result.type, entry.$2);
        expect(result.cnpjFormat, entry.$3);
        expect(result.synthetic, isTrue);
        expect(() => result.values.add('PRIVATE'), throwsUnsupportedError);
      },
    );
  }

  test(
    'GivenLocaleTypeMismatch_WhenGenerated_ThenValidationPrecedesCandidate',
    () {
      var called = false;
      final generator = IdentityDocumentGenerator.forTesting(
        candidate: (_, _, _) {
          called = true;
          return 'PRIVATE';
        },
      );

      expect(
        () => generator.generate(
          const IdentityDocumentRequest(
            locale: IdentityLocale.us,
            type: IdentityDocumentType.cpf,
          ),
        ),
        throwsA(
          isA<IdentityDocumentGenerationException>()
              .having(
                (error) => error.kind,
                'kind',
                IdentityDocumentFailureKind.validation,
              )
              .having(
                (error) => error.code,
                'code',
                'document.locale-type-mismatch',
              ),
        ),
      );
      expect(called, isFalse);
    },
  );

  test('GivenInvalidCount_WhenGenerated_ThenValidationPrecedesAllocation', () {
    var allocated = false;
    final generator = IdentityDocumentGenerator.forTesting(
      candidate: (_, _, _) => 'PRIVATE',
      allocate: (_) {
        allocated = true;
        return <String>[];
      },
    );

    expect(
      () => generator.generate(
        const IdentityDocumentRequest(
          locale: IdentityLocale.us,
          type: IdentityDocumentType.ssn,
          count: 0,
        ),
      ),
      throwsA(
        isA<IdentityDocumentGenerationException>()
            .having(
              (error) => error.kind,
              'kind',
              IdentityDocumentFailureKind.validation,
            )
            .having((error) => error.code, 'code', 'document.invalid-count'),
      ),
    );
    expect(allocated, isFalse);
  });

  test(
    'GivenRejectedCandidatesThenValid_WhenGenerated_ThenReplacementReturns',
    () {
      var attempts = 0;
      final result =
          IdentityDocumentGenerator.forTesting(
            candidate: (_, _, _) => ++attempts == 3 ? '219099999' : 'PRIVATE',
          ).generate(
            const IdentityDocumentRequest(
              locale: IdentityLocale.us,
              type: IdentityDocumentType.ssn,
            ),
          );

      expect(attempts, 3);
      expect(result.values, ['219-09-9999']);
    },
  );

  test(
    'GivenValidFirstThenExhaustion_WhenGenerated_ThenNoPartialBatchReturns',
    () {
      var attempts = 0;
      final generator = IdentityDocumentGenerator.forTesting(
        candidate: (_, _, _) => ++attempts == 1 ? '219099999' : 'PRIVATE',
      );

      expect(
        () => generator.generate(
          const IdentityDocumentRequest(
            locale: IdentityLocale.us,
            type: IdentityDocumentType.ssn,
            count: 2,
          ),
        ),
        throwsA(
          isA<IdentityDocumentGenerationException>()
              .having(
                (error) => error.kind,
                'kind',
                IdentityDocumentFailureKind.processing,
              )
              .having(
                (error) => error.code,
                'code',
                'document.generation-failed',
              ),
        ),
      );
      expect(attempts, 33);
    },
  );

  test(
    'GivenCandidateSourceFailure_WhenGenerated_ThenRedactedProcessingFailure',
    () {
      final generator = IdentityDocumentGenerator.forTesting(
        candidate: (_, _, _) => throw StateError('PRIVATE'),
      );
      expect(
        () => generator.generate(
          const IdentityDocumentRequest(
            locale: IdentityLocale.us,
            type: IdentityDocumentType.ssn,
          ),
        ),
        throwsA(
          isA<IdentityDocumentGenerationException>()
              .having(
                (error) => error.code,
                'code',
                'document.source-unavailable',
              )
              .having(
                (error) => error.toString(),
                'redacted',
                isNot(contains('PRIVATE')),
              ),
        ),
      );
    },
  );

  test('GivenAllocationFailure_WhenGenerated_ThenResourceFailureReturns', () {
    final generator = IdentityDocumentGenerator.forTesting(
      candidate: (_, _, _) => '219099999',
      allocate: (_) => throw RangeError('PRIVATE'),
    );
    expect(
      () => generator.generate(
        const IdentityDocumentRequest(
          locale: IdentityLocale.us,
          type: IdentityDocumentType.ssn,
        ),
      ),
      throwsA(
        isA<IdentityDocumentGenerationException>()
            .having(
              (error) => error.kind,
              'kind',
              IdentityDocumentFailureKind.resource,
            )
            .having((error) => error.code, 'code', 'document.resource-limit'),
      ),
    );
  });

  test(
    'GivenProductionGenerator_WhenAllTypesGenerated_ThenEveryValueValid',
    () {
      const generator = IdentityDocumentGenerator();
      for (final locale in IdentityLocale.values) {
        for (final type in IdentityDocumentType.values.where(
          (type) => locale == IdentityLocale.us
              ? {
                  IdentityDocumentType.ssn,
                  IdentityDocumentType.itin,
                  IdentityDocumentType.ein,
                }.contains(type)
              : {
                  IdentityDocumentType.cpf,
                  IdentityDocumentType.cnpj,
                  IdentityDocumentType.cnh,
                  IdentityDocumentType.cin,
                }.contains(type),
        )) {
          final formats = type == IdentityDocumentType.cnpj
              ? CnpjFormat.values
              : const [CnpjFormat.alphanumeric];
          for (final format in formats) {
            final result = generator.generate(
              IdentityDocumentRequest(
                locale: locale,
                type: type,
                cnpjFormat: format,
                count: 8,
              ),
            );
            expect(result.values, hasLength(8));
            for (final value in result.values) {
              expect(
                validator.isValid(
                  locale: locale,
                  type: type,
                  cnpjFormat: format,
                  value: value,
                ),
                isTrue,
              );
            }
          }
        }
      }
    },
  );
}
