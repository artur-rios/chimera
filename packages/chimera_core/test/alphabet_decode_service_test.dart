import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const service = AlphabetDecodeService();

  test(
    'GivenRawRequest_WhenDecoded_ThenStableOutputAndMappingReturn',
    () async {
      final result = await service.execute(
        AlphabetDecodeOperationRequest.text(
          '... --- ... / ..---',
          alphabet: 'morse',
        ),
      );

      final success = result as ChimeraSuccess<AlphabetDecodeOutput>;
      expect(success.value.decoded, 'SOS 2');
      expect(success.value.alphabet, 'morse');
      expect(success.value.mapping.id, 'itu-r-m.1677-1');
      expect(success.value.toJson(), <String, Object?>{
        'decoded': 'SOS 2',
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

  test('GivenUtf8Bytes_WhenDecoded_ThenExactBrailleTextReturns', () async {
    final result = await service.execute(
      AlphabetDecodeOperationRequest.utf8Bytes(
        '\u2820\u2801\u283c\u2801'.codeUnits.expand(_utf8).toList(),
        alphabet: 'braille',
      ),
    );

    expect(
      (result as ChimeraSuccess<AlphabetDecodeOutput>).value.decoded,
      'A1',
    );
  });

  test(
    'GivenMutableUtf8Bytes_WhenRequestConstructed_ThenPrivateCopyIsUsed',
    () async {
      final bytes = <int>[0x41, 0x6c, 0x66, 0x61];
      final request = AlphabetDecodeOperationRequest.utf8Bytes(
        bytes,
        alphabet: 'nato',
      );
      bytes[0] = 0x5a;

      final result = await service.execute(request);

      expect(
        (result as ChimeraSuccess<AlphabetDecodeOutput>).value.decoded,
        'A',
      );
    },
  );

  group('AlphabetDecodeService validation', () {
    final cases =
        <
          ({
            AlphabetDecodeOperationRequest request,
            String code,
            String field,
            int? position,
          })
        >[
          (
            request: AlphabetDecodeOperationRequest.text(
              'text',
              alphabet: 'unknown',
            ),
            code: 'alphabet.invalid-alphabet',
            field: 'alphabet',
            position: null,
          ),
          (
            request: AlphabetDecodeOperationRequest.text(
              '.-  -...',
              alphabet: 'morse',
            ),
            code: 'alphabet.invalid-input',
            field: 'input',
            position: 3,
          ),
          (
            request: AlphabetDecodeOperationRequest.utf8Bytes(<int>[
              0xc3,
              0x28,
            ], alphabet: 'nato'),
            code: 'alphabet.invalid-input',
            field: 'input',
            position: null,
          ),
          (
            request: AlphabetDecodeOperationRequest.utf8Bytes(<int>[
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

        final failure = result as ChimeraFailure<AlphabetDecodeOutput>;
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, fixture.code);
        expect(failure.messageKey, 'error.alphabetDecode.validation');
        expect(failure.details['field'], fixture.field);
        expect(failure.details['position'], fixture.position);
        expect(failure.details.toString(), isNot(contains('.-')));
        expect(failure.details.toString(), isNot(contains('text')));
      });
    }
  });

  test(
    'GivenDecoderResourceFailure_WhenExecuted_ThenTypedFailureReturns',
    () async {
      const limited = AlphabetDecodeService(
        decoder: AlphabetDecoder(maxOutputCharacters: 0),
      );

      final result = await limited.execute(
        AlphabetDecodeOperationRequest.text('.-', alphabet: 'morse'),
      );

      final failure = result as ChimeraFailure<AlphabetDecodeOutput>;
      expect(failure.kind, FailureKind.resource);
      expect(failure.code, 'alphabet.resource-limit');
      expect(failure.messageKey, 'error.alphabetDecode.resource');
      expect(failure.details, <String, Object?>{
        'field': 'output',
        'reason': 'output-limit',
      });
    },
  );

  test(
    'GivenUnexpectedDecoderFailure_WhenExecuted_ThenRedactedFailureReturns',
    () async {
      const failing = AlphabetDecodeService(
        decodeOverride: _throwUnexpectedFailure,
      );

      final result = await failing.execute(
        AlphabetDecodeOperationRequest.text('secret', alphabet: 'nato'),
      );

      final failure = result as ChimeraFailure<AlphabetDecodeOutput>;
      expect(failure.kind, FailureKind.processing);
      expect(failure.code, 'alphabet.processing-failed');
      expect(failure.messageKey, 'error.alphabetDecode.processing');
      expect(failure.details, isEmpty);
      expect(failure.toString(), isNot(contains('secret')));
      expect(
        failure.toString(),
        isNot(contains('private decoder diagnostics')),
      );
    },
  );
}

Iterable<int> _utf8(int codeUnit) {
  if (codeUnit <= 0x7f) return <int>[codeUnit];
  return <int>[
    0xe0 | (codeUnit >> 12),
    0x80 | ((codeUnit >> 6) & 0x3f),
    0x80 | (codeUnit & 0x3f),
  ];
}

AlphabetDecodeResult _throwUnexpectedFailure(AlphabetDecodeRequest request) =>
    throw StateError('private decoder diagnostics');
