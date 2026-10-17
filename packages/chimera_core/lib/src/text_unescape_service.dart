import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class TextUnescapeOperationRequest {
  const TextUnescapeOperationRequest({required this.input, required this.mode});

  final String input;
  final String mode;
}

final class TextUnescapeOutput {
  const TextUnescapeOutput(this.result);

  final TextUnescapeResult result;

  String get unescaped => result.unescaped;
  String get mode => result.mode;

  Map<String, Object?> toJson() => <String, Object?>{
    'unescaped': result.unescaped,
    'mode': result.mode,
  };
}

final class TextUnescapeService
    implements
        OperationService<TextUnescapeOperationRequest, TextUnescapeOutput> {
  const TextUnescapeService({this.unescaper = const TextUnescaper()});

  final TextUnescaper unescaper;

  @override
  Future<ChimeraResult<TextUnescapeOutput>> execute(
    TextUnescapeOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<TextUnescapeOutput>(
        TextUnescapeOutput(
          unescaper.unescape(
            TextUnescapeRequest(input: request.input, mode: request.mode),
          ),
        ),
      );
    } on TextUnescapeException catch (error) {
      return ChimeraFailure<TextUnescapeOutput>(
        kind: switch (error.kind) {
          TextUnescapeFailureKind.validation => FailureKind.validation,
          TextUnescapeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          TextUnescapeFailureKind.validation => 'error.textUnescape.validation',
          TextUnescapeFailureKind.resource => 'error.textUnescape.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
          'offset': ?error.offset,
        },
      );
    }
  }
}
