import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class TextTransformOperationRequest {
  const TextTransformOperationRequest({
    required this.input,
    required this.mode,
  });

  final String input;
  final String mode;
}

final class TextTransformOutput {
  const TextTransformOutput(this.result);

  final TextTransformResult result;

  String get mode => result.mode.slug;
  String get output => result.output;

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode,
    'output': output,
  };
}

final class TextTransformService
    implements
        OperationService<TextTransformOperationRequest, TextTransformOutput> {
  const TextTransformService({this.transformer = const TextTransformer()});

  final TextTransformer transformer;

  @override
  Future<ChimeraResult<TextTransformOutput>> execute(
    TextTransformOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<TextTransformOutput>(
        TextTransformOutput(
          transformer.transform(input: request.input, mode: request.mode),
        ),
      );
    } on TextTransformException catch (error) {
      return ChimeraFailure<TextTransformOutput>(
        kind: switch (error.kind) {
          TextTransformFailureKind.validation => FailureKind.validation,
          TextTransformFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          TextTransformFailureKind.validation =>
            'error.textTransform.validation',
          TextTransformFailureKind.resource => 'error.textTransform.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
