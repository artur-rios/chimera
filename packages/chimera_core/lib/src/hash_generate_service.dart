import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class HashGenerateOperationRequest {
  HashGenerateOperationRequest.text(String input, {this.algorithm = 'sha256'})
    : _text = input,
      _bytes = null;
  HashGenerateOperationRequest.bytes(
    List<int> input, {
    this.algorithm = 'sha256',
  }) : _bytes = input,
       _text = null;
  final String algorithm;
  final String? _text;
  final List<int>? _bytes;
}

final class HashGenerateOutput {
  const HashGenerateOutput(this.result);
  final HashGenerateResult result;
  String get algorithm => result.algorithm;
  String get digest => result.digest;
  bool get legacy => result.legacy;
  String? get warningKey => legacy ? 'hashGenerate.legacyWarning' : null;
  Map<String, Object?> toJson() => {
    'algorithm': algorithm,
    'digest': digest,
    'legacy': legacy,
    'warningKey': warningKey,
  };
}

final class HashGenerateService
    implements
        OperationService<HashGenerateOperationRequest, HashGenerateOutput> {
  const HashGenerateService({this.generator = const HashGenerator()});
  final HashGenerator generator;
  @override
  Future<ChimeraResult<HashGenerateOutput>> execute(
    HashGenerateOperationRequest request,
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
      return ChimeraSuccess(HashGenerateOutput(output));
    } on HashGenerateException catch (error) {
      return ChimeraFailure(
        kind: error.kind == HashGenerateFailureKind.validation
            ? FailureKind.validation
            : FailureKind.resource,
        code: error.code,
        messageKey: error.kind == HashGenerateFailureKind.validation
            ? 'error.hashGenerate.validation'
            : 'error.hashGenerate.resource',
        details: {'field': error.field, 'reason': error.reason},
      );
    }
  }
}
