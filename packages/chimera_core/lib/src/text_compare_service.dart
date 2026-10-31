import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class TextCompareOperationRequest {
  const TextCompareOperationRequest({
    required this.left,
    required this.right,
    required this.granularity,
  });

  final String left;
  final String right;
  final String granularity;
}

final class TextCompareOutput {
  const TextCompareOutput(this.result);

  final TextCompareResult result;

  String get granularity => result.granularity.slug;
  List<TextDiffSpan> get spans => result.spans;
  TextCompareSummary get summary => result.summary;

  Map<String, Object?> toJson() => <String, Object?>{
    'granularity': granularity,
    'spans': <Map<String, Object?>>[
      for (final span in spans)
        <String, Object?>{
          'kind': span.kind.slug,
          'text': span.text,
          'tokenCount': span.tokenCount,
        },
    ],
    'summary': <String, Object?>{
      'added': summary.added,
      'removed': summary.removed,
      'unchanged': summary.unchanged,
    },
  };
}

final class TextCompareService
    implements
        OperationService<TextCompareOperationRequest, TextCompareOutput> {
  const TextCompareService({this.comparer = const TextComparer()});

  final TextComparer comparer;

  @override
  Future<ChimeraResult<TextCompareOutput>> execute(
    TextCompareOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<TextCompareOutput>(
        TextCompareOutput(
          comparer.compare(
            left: request.left,
            right: request.right,
            granularity: request.granularity,
          ),
        ),
      );
    } on TextCompareException catch (error) {
      return ChimeraFailure<TextCompareOutput>(
        kind: switch (error.kind) {
          TextCompareFailureKind.validation => FailureKind.validation,
          TextCompareFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          TextCompareFailureKind.validation => 'error.textCompare.validation',
          TextCompareFailureKind.resource => 'error.textCompare.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
