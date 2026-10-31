import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  for (final source in ['text', 'bytes']) {
    test('Given${source}Abc_WhenHashGenerated_ThenStableSourceFreeJson', () async {
      final result = await const HashGenerateService().execute(
        source == 'text'
            ? HashGenerateOperationRequest.text('abc')
            : HashGenerateOperationRequest.bytes([97, 98, 99]),
      );
      final output = (result as ChimeraSuccess<HashGenerateOutput>).value;
      expect(output.toJson(), {
        'algorithm': 'sha256',
        'digest':
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        'legacy': false,
        'warningKey': null,
      });
    });
  }
  for (final algorithm in ['md5', 'sha1']) {
    test(
      'Given${algorithm}_WhenGenerated_ThenExplicitLegacyWarningKey',
      () async {
        final result = await const HashGenerateService().execute(
          HashGenerateOperationRequest.text('', algorithm: algorithm),
        );
        final output = (result as ChimeraSuccess<HashGenerateOutput>).value;
        expect(output.legacy, isTrue);
        expect(output.warningKey, 'hashGenerate.legacyWarning');
      },
    );
  }
  test('GivenInvalidAlgorithm_WhenExecuted_ThenTypedValidation', () async {
    final result = await const HashGenerateService().execute(
      HashGenerateOperationRequest.text('SECRET', algorithm: 'SECRET'),
    );
    expect(
      result,
      isA<ChimeraFailure<HashGenerateOutput>>()
          .having((e) => e.kind, 'kind', FailureKind.validation)
          .having(
            (e) => e.messageKey,
            'message',
            'error.hashGenerate.validation',
          )
          .having(
            (e) => e.details.toString(),
            'details',
            isNot(contains('SECRET')),
          ),
    );
  });
  test('GivenAllocationFailure_WhenExecuted_ThenTypedResource', () async {
    final result = await HashGenerateService(
      generator: HashGenerator.forTesting(
        hash: (_, _) => throw OutOfMemoryError(),
      ),
    ).execute(HashGenerateOperationRequest.bytes([0, 255]));
    expect(
      result,
      isA<ChimeraFailure<HashGenerateOutput>>().having(
        (e) => e.kind,
        'kind',
        FailureKind.resource,
      ),
    );
  });
}
