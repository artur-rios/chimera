import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  for (final source in ['text', 'bytes']) {
    test(
      'Given${source}Abc_WhenChecksumGenerated_ThenStableSourceFreeJson',
      () async {
        final result = await const ChecksumGenerateService().execute(
          source == 'text'
              ? ChecksumGenerateOperationRequest.text('abc')
              : ChecksumGenerateOperationRequest.bytes([97, 98, 99]),
        );
        final output = (result as ChimeraSuccess<ChecksumGenerateOutput>).value;
        expect(output.toJson(), {'algorithm': 'crc32', 'checksum': '352441c2'});
      },
    );
  }
  test('GivenInvalidAlgorithm_WhenExecuted_ThenTypedValidation', () async {
    final result = await const ChecksumGenerateService().execute(
      ChecksumGenerateOperationRequest.text('SECRET', algorithm: 'SECRET'),
    );
    expect(
      result,
      isA<ChimeraFailure<ChecksumGenerateOutput>>()
          .having((e) => e.kind, 'kind', FailureKind.validation)
          .having(
            (e) => e.messageKey,
            'message',
            'error.checksumGenerate.validation',
          )
          .having(
            (e) => e.details.toString(),
            'details',
            isNot(contains('SECRET')),
          ),
    );
  });
  test('GivenAllocationFailure_WhenExecuted_ThenTypedResource', () async {
    final result = await ChecksumGenerateService(
      generator: ChecksumGenerator.forTesting(
        checksum: (_, _) => throw OutOfMemoryError(),
      ),
    ).execute(ChecksumGenerateOperationRequest.bytes([0, 255]));
    expect(
      result,
      isA<ChimeraFailure<ChecksumGenerateOutput>>().having(
        (e) => e.kind,
        'kind',
        FailureKind.resource,
      ),
    );
  });
}
