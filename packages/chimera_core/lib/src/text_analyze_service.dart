import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class TextAnalyzeOperationRequest {
  const TextAnalyzeOperationRequest({required this.input});

  final String input;
}

final class TextAnalyzeOutput {
  const TextAnalyzeOutput(this.result);

  final TextAnalyzeResult result;

  int get characterCount => result.characterCount;
  int get wordCount => result.wordCount;
  int get lineCount => result.lineCount;
  int get byteCount => result.byteCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'characters': characterCount,
    'words': wordCount,
    'lines': lineCount,
    'bytes': byteCount,
  };
}

final class TextAnalyzeService
    implements
        OperationService<TextAnalyzeOperationRequest, TextAnalyzeOutput> {
  const TextAnalyzeService({this.analyzer = const TextAnalyzer()});

  final TextAnalyzer analyzer;

  @override
  Future<ChimeraResult<TextAnalyzeOutput>> execute(
    TextAnalyzeOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<TextAnalyzeOutput>(
        TextAnalyzeOutput(analyzer.analyze(request.input)),
      );
    } on TextAnalyzeException catch (error) {
      return ChimeraFailure<TextAnalyzeOutput>(
        kind: FailureKind.resource,
        code: error.code,
        messageKey: 'error.textAnalyze.resource',
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
