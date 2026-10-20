import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const service = CipherDecodeService();

  test('GivenRawRequest_WhenDecoded_ThenStableOutputIsReturned', () async {
    final result = await service.execute(
      CipherDecodeOperationRequest.text(
        'LXFOPV EF RNHR',
        cipher: 'vigenere',
        key: 'LEMON',
        characterPolicy: 'preserve',
      ),
    );

    final success = result as ChimeraSuccess<CipherDecodeOutput>;
    expect(success.value.decoded, 'ATTACK AT DAWN');
    expect(success.value.toJson(), <String, Object?>{
      'decoded': 'ATTACK AT DAWN',
      'cipher': 'vigenere',
      'characterPolicy': 'preserve',
    });
    expect(success.value.toJson().toString(), isNot(contains('LEMON')));
  });

  test('GivenUtf8Bytes_WhenDecoded_ThenBomAndUnicodeArePreserved', () async {
    final bytes = <int>[0xef, 0xbb, 0xbf, 0x5a, 0xc3, 0xa9];
    final request = CipherDecodeOperationRequest.utf8Bytes(
      bytes,
      cipher: 'atbash',
    );
    bytes[3] = 0x41;

    final result = await service.execute(request);

    expect(
      (result as ChimeraSuccess<CipherDecodeOutput>).value.decoded,
      '\uFEFFA\u00E9',
    );
  });

  group('CipherDecodeService validation', () {
    final cases =
        <({CipherDecodeOperationRequest request, String code, String field})>[
          (
            request: CipherDecodeOperationRequest.text(
              'text',
              cipher: 'unknown',
            ),
            code: 'cipher.invalid-cipher',
            field: 'cipher',
          ),
          (
            request: CipherDecodeOperationRequest.text(
              'text',
              cipher: 'atbash',
              characterPolicy: 'drop',
            ),
            code: 'cipher.invalid-character-policy',
            field: 'characterPolicy',
          ),
          (
            request: CipherDecodeOperationRequest.text(
              'text',
              cipher: 'caesar',
              shift: 'x',
            ),
            code: 'cipher.invalid-parameter',
            field: 'shift',
          ),
          (
            request: CipherDecodeOperationRequest.text(
              'Z\u{1F9EA}Y',
              cipher: 'atbash',
              characterPolicy: 'reject',
            ),
            code: 'cipher.unsupported-symbol',
            field: 'input',
          ),
          (
            request: CipherDecodeOperationRequest.utf8Bytes(<int>[
              0xc3,
              0x28,
            ], cipher: 'atbash'),
            code: 'cipher.invalid-input',
            field: 'input',
          ),
        ];

    for (final fixture in cases) {
      test('Given${fixture.code}_WhenExecuted_ThenRedactedFailure', () async {
        final result = await service.execute(fixture.request);

        final failure = result as ChimeraFailure<CipherDecodeOutput>;
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, fixture.code);
        expect(failure.messageKey, 'error.cipherDecode.validation');
        expect(failure.details['field'], fixture.field);
        expect(failure.details.toString(), isNot(contains('\u{1F9EA}')));
        expect(failure.details.toString(), isNot(contains('text')));
      });
    }
  });

  test(
    'GivenSupplementarySymbol_WhenRejected_ThenScalarPositionReturns',
    () async {
      final result = await service.execute(
        CipherDecodeOperationRequest.text(
          'Z\u{1F9EA}Y',
          cipher: 'atbash',
          characterPolicy: 'reject',
        ),
      );

      final failure = result as ChimeraFailure<CipherDecodeOutput>;
      expect(failure.details['position'], 1);
      expect(failure.details, isNot(containsValue('\u{1F9EA}')));
    },
  );

  test(
    'GivenResourceLimit_WhenExecuted_ThenTypedResourceFailureReturns',
    () async {
      const boundedService = CipherDecodeService(
        decoder: CipherDecoder(maxOutputCharacters: 0),
      );

      final result = await boundedService.execute(
        CipherDecodeOperationRequest.text('Z', cipher: 'atbash'),
      );

      final failure = result as ChimeraFailure<CipherDecodeOutput>;
      expect(failure.kind, FailureKind.resource);
      expect(failure.code, 'cipher.resource-limit');
      expect(failure.messageKey, 'error.cipherDecode.resource');
      expect(failure.details['field'], 'output');
    },
  );

  test('GivenUnexpectedDecoderFailure_WhenExecuted_ThenTypedProcessingFailureReturns', () async {
    const failingService = CipherDecodeService(
      decodeOverride: _throwUnexpectedFailure,
    );

    final result = await failingService.execute(
      CipherDecodeOperationRequest.text('secret', cipher: 'atbash'),
    );

    final failure = result as ChimeraFailure<CipherDecodeOutput>;
    expect(failure.kind, FailureKind.processing);
    expect(failure.code, 'cipher.processing-failed');
    expect(failure.messageKey, 'error.cipherDecode.processing');
    expect(failure.details, isEmpty);
    expect(failure.toString(), isNot(contains('secret')));
  });
}

CipherDecodeResult _throwUnexpectedFailure(CipherDecodeRequest request) =>
    throw StateError('private decoder diagnostics');
