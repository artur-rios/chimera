import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const service = AlphabetEncodeService();

  test(
    'GivenRawRequest_WhenEncoded_ThenStableOutputAndMappingReturn',
    () async {
      final result = await service.execute(
        AlphabetEncodeOperationRequest.text('SOS 2', alphabet: 'morse'),
      );

      final success = result as ChimeraSuccess<AlphabetEncodeOutput>;
      expect(success.value.encoded, '... --- ... / ..---');
      expect(success.value.alphabet, 'morse');
      expect(success.value.mapping.id, 'itu-r-m.1677-1');
      expect(success.value.toJson(), <String, Object?>{
        'encoded': '... --- ... / ..---',
        'alphabet': 'morse',
        'mapping': <String, Object?>{
          'id': 'itu-r-m.1677-1',
          'edition': '10/2009',
          'sources': <String>[
            'https://www.itu.int/rec/R-REC-M.1677-1-200910-I/en',
          ],
          'symbols': alphabetMappingFor(AlphabetKind.morse).symbols,
          'rules': alphabetMappingFor(AlphabetKind.morse).rules,
        },
      });
    },
  );

  test('GivenUtf8Bytes_WhenEncoded_ThenExactUnicodeBrailleReturns', () async {
    final result = await service.execute(
      AlphabetEncodeOperationRequest.utf8Bytes(<int>[
        0x41,
        0x31,
        0x30,
        0x61,
      ], alphabet: 'braille'),
    );

    expect(
      (result as ChimeraSuccess<AlphabetEncodeOutput>).value.encoded,
      '\u2820\u2801\u283c\u2801\u281a\u2830\u2801',
    );
  });

  test(
    'GivenMutableUtf8Bytes_WhenRequestConstructed_ThenPrivateCopyIsUsed',
    () async {
      final bytes = <int>[0x41];
      final request = AlphabetEncodeOperationRequest.utf8Bytes(
        bytes,
        alphabet: 'nato',
      );
      bytes[0] = 0x5a;

      final result = await service.execute(request);

      expect(
        (result as ChimeraSuccess<AlphabetEncodeOutput>).value.encoded,
        'Alfa',
      );
    },
  );

  group('AlphabetEncodeService validation', () {
    final cases =
        <
          ({
            AlphabetEncodeOperationRequest request,
            String code,
            String field,
            int? position,
          })
        >[
          (
            request: AlphabetEncodeOperationRequest.text(
              'text',
              alphabet: 'unknown',
            ),
            code: 'alphabet.invalid-alphabet',
            field: 'alphabet',
            position: null,
          ),
          (
            request: AlphabetEncodeOperationRequest.text(
              'AB\tC',
              alphabet: 'nato',
            ),
            code: 'alphabet.unsupported-symbol',
            field: 'input',
            position: 2,
          ),
          (
            request: AlphabetEncodeOperationRequest.utf8Bytes(<int>[
              0xc3,
              0x28,
            ], alphabet: 'morse'),
            code: 'alphabet.invalid-input',
            field: 'input',
            position: null,
          ),
          (
            request: AlphabetEncodeOperationRequest.utf8Bytes(<int>[
              256,
            ], alphabet: 'braille'),
            code: 'alphabet.invalid-input',
            field: 'input',
            position: null,
          ),
        ];

    for (final fixture in cases) {
      test('Given${fixture.code}_WhenExecuted_ThenRedactedFailure', () async {
        final result = await service.execute(fixture.request);

        final failure = result as ChimeraFailure<AlphabetEncodeOutput>;
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, fixture.code);
        expect(failure.messageKey, 'error.alphabetEncode.validation');
        expect(failure.details['field'], fixture.field);
        expect(failure.details['position'], fixture.position);
        expect(failure.details.toString(), isNot(contains('AB')));
        expect(failure.details.toString(), isNot(contains('text')));
        expect(failure.details.toString(), isNot(contains('\t')));
      });
    }
  });

  test(
    'GivenEncoderResourceFailure_WhenExecuted_ThenTypedResourceFailureReturns',
    () async {
      const limited = AlphabetEncodeService(
        encoder: AlphabetEncoder(maxOutputCharacters: 0),
      );

      final result = await limited.execute(
        AlphabetEncodeOperationRequest.text('A', alphabet: 'morse'),
      );

      final failure = result as ChimeraFailure<AlphabetEncodeOutput>;
      expect(failure.kind, FailureKind.resource);
      expect(failure.code, 'alphabet.resource-limit');
      expect(failure.messageKey, 'error.alphabetEncode.resource');
      expect(failure.details, <String, Object?>{
        'field': 'output',
        'reason': 'output-limit',
      });
    },
  );

  test('GivenUnexpectedEncoderFailure_WhenExecuted_ThenTypedProcessingFailureReturns', () async {
    const failing = AlphabetEncodeService(
      encodeOverride: _throwUnexpectedFailure,
    );

    final result = await failing.execute(
      AlphabetEncodeOperationRequest.text('secret', alphabet: 'nato'),
    );

    final failure = result as ChimeraFailure<AlphabetEncodeOutput>;
    expect(failure.kind, FailureKind.processing);
    expect(failure.code, 'alphabet.processing-failed');
    expect(failure.messageKey, 'error.alphabetEncode.processing');
    expect(failure.details, isEmpty);
    expect(failure.toString(), isNot(contains('secret')));
    expect(failure.toString(), isNot(contains('private encoder diagnostics')));
  });
}

AlphabetEncodeResult _throwUnexpectedFailure(AlphabetEncodeRequest request) =>
    throw StateError('private encoder diagnostics');
