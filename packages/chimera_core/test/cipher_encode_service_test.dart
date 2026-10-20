import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  const service = CipherEncodeService();

  test('GivenRawRequest_WhenEncoded_ThenStableOutputIsReturned', () async {
    final result = await service.execute(
      CipherEncodeOperationRequest.text(
        'ATTACK AT DAWN',
        cipher: 'vigenere',
        key: 'LEMON',
        characterPolicy: 'preserve',
      ),
    );

    final success = result as ChimeraSuccess<CipherEncodeOutput>;
    expect(success.value.encoded, 'LXFOPV EF RNHR');
    expect(success.value.toJson(), <String, Object?>{
      'encoded': 'LXFOPV EF RNHR',
      'cipher': 'vigenere',
      'characterPolicy': 'preserve',
    });
    expect(success.value.toJson().toString(), isNot(contains('LEMON')));
  });

  test('GivenUtf8Bytes_WhenEncoded_ThenBomAndUnicodeArePreserved', () async {
    final result = await service.execute(
      CipherEncodeOperationRequest.utf8Bytes(<int>[
        0xef,
        0xbb,
        0xbf,
        0x41,
        0xc3,
        0xa9,
      ], cipher: 'atbash'),
    );

    expect(
      (result as ChimeraSuccess<CipherEncodeOutput>).value.encoded,
      '\uFEFFZé',
    );
  });

  group('CipherEncodeService validation', () {
    final cases =
        <({CipherEncodeOperationRequest request, String code, String field})>[
          (
            request: CipherEncodeOperationRequest.text(
              'text',
              cipher: 'unknown',
            ),
            code: 'cipher.invalid-cipher',
            field: 'cipher',
          ),
          (
            request: CipherEncodeOperationRequest.text(
              'text',
              cipher: 'atbash',
              characterPolicy: 'drop',
            ),
            code: 'cipher.invalid-character-policy',
            field: 'characterPolicy',
          ),
          (
            request: CipherEncodeOperationRequest.text(
              'text',
              cipher: 'caesar',
              shift: 'x',
            ),
            code: 'cipher.invalid-parameter',
            field: 'shift',
          ),
          (
            request: CipherEncodeOperationRequest.text(
              'A😀B',
              cipher: 'atbash',
              characterPolicy: 'reject',
            ),
            code: 'cipher.unsupported-symbol',
            field: 'input',
          ),
          (
            request: CipherEncodeOperationRequest.utf8Bytes(<int>[
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

        final failure = result as ChimeraFailure<CipherEncodeOutput>;
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, fixture.code);
        expect(failure.messageKey, 'error.cipherEncode.validation');
        expect(failure.details['field'], fixture.field);
        expect(failure.details.toString(), isNot(contains('A😀B')));
        expect(failure.details.toString(), isNot(contains('text')));
      });
    }
  });

  test('GivenUnexpectedEncoderFailure_WhenExecuted_ThenTypedProcessingFailureReturns', () async {
    const failingService = CipherEncodeService(
      encodeOverride: _throwUnexpectedFailure,
    );

    final result = await failingService.execute(
      CipherEncodeOperationRequest.text('secret', cipher: 'atbash'),
    );

    final failure = result as ChimeraFailure<CipherEncodeOutput>;
    expect(failure.kind, FailureKind.processing);
    expect(failure.code, 'cipher.processing-failed');
    expect(failure.messageKey, 'error.cipherEncode.processing');
    expect(failure.details, isEmpty);
    expect(failure.toString(), isNot(contains('secret')));
  });
}

CipherEncodeResult _throwUnexpectedFailure(CipherEncodeRequest request) =>
    throw StateError('private encoder diagnostics');
