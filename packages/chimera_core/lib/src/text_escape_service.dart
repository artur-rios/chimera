import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class TextEscapeOperationRequest {
  const TextEscapeOperationRequest({required this.input, required this.mode});

  final String input;
  final String mode;
}

final class TextEscapeOutput {
  const TextEscapeOutput(this.result);

  final TextEscapeResult result;

  String get escaped => result.escaped;
  String get mode => result.mode;

  Map<String, Object?> toJson() => <String, Object?>{
    'escaped': result.escaped,
    'mode': result.mode,
  };
}

final class TextEscapeService
    implements OperationService<TextEscapeOperationRequest, TextEscapeOutput> {
  const TextEscapeService({this.escaper = const TextEscaper()});

  final TextEscaper escaper;

  @override
  Future<ChimeraResult<TextEscapeOutput>> execute(
    TextEscapeOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<TextEscapeOutput>(
        TextEscapeOutput(
          escaper.escape(
            TextEscapeRequest(input: request.input, mode: request.mode),
          ),
        ),
      );
    } on TextEscapeException catch (error) {
      return ChimeraFailure<TextEscapeOutput>(
        kind: switch (error.kind) {
          TextEscapeFailureKind.validation => FailureKind.validation,
          TextEscapeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          TextEscapeFailureKind.validation => 'error.textEscape.validation',
          TextEscapeFailureKind.resource => 'error.textEscape.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
