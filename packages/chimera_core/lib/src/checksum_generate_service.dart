import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class ChecksumGenerateOperationRequest {
  ChecksumGenerateOperationRequest.text(
    String input, {
    this.algorithm = 'crc32',
  }) : _text = input,
       _bytes = null;
  ChecksumGenerateOperationRequest.bytes(
    List<int> input, {
    this.algorithm = 'crc32',
  }) : _bytes = input,
       _text = null;
  final String algorithm;
  final String? _text;
  final List<int>? _bytes;
}

final class ChecksumGenerateOutput {
  const ChecksumGenerateOutput(this.result);
  final ChecksumGenerateResult result;
  String get algorithm => result.algorithm;
  String get checksum => result.checksum;
  Map<String, Object?> toJson() => {
    'algorithm': algorithm,
    'checksum': checksum,
  };
}

final class ChecksumGenerateService
    implements
        OperationService<
          ChecksumGenerateOperationRequest,
          ChecksumGenerateOutput
        > {
  const ChecksumGenerateService({this.generator = const ChecksumGenerator()});
  final ChecksumGenerator generator;
  @override
  Future<ChimeraResult<ChecksumGenerateOutput>> execute(
    ChecksumGenerateOperationRequest request,
  ) async {
    try {
      final output = request._bytes != null
          ? generator.generateBytes(
              request._bytes,
              algorithm: request.algorithm,
            )
          : generator.generateText(
              request._text!,
              algorithm: request.algorithm,
            );
      return ChimeraSuccess(ChecksumGenerateOutput(output));
    } on ChecksumGenerateException catch (error) {
      return ChimeraFailure(
        kind: error.kind == ChecksumGenerateFailureKind.validation
            ? FailureKind.validation
            : FailureKind.resource,
        code: error.code,
        messageKey: error.kind == ChecksumGenerateFailureKind.validation
            ? 'error.checksumGenerate.validation'
            : 'error.checksumGenerate.resource',
        details: {'field': error.field, 'reason': error.reason},
      );
    }
  }
}
