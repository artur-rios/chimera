import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class ListCompareOperationRequest {
  const ListCompareOperationRequest({
    required this.left,
    required this.right,
    this.caseMode = 'sensitive',
    this.whitespaceMode = 'preserve',
    this.duplicateMode = 'preserve',
  });

  final String left;
  final String right;
  final String caseMode;
  final String whitespaceMode;
  final String duplicateMode;
}

final class ListCompareOutput {
  const ListCompareOutput(this.result);

  final ListCompareResult result;

  List<String> get leftOnly => result.leftOnly;
  List<String> get rightOnly => result.rightOnly;
  List<String> get intersection => result.intersection;
  bool get equal => result.equal;
  String get caseMode => result.caseMode;
  String get whitespaceMode => result.whitespaceMode;
  String get duplicateMode => result.duplicateMode;

  Map<String, Object?> toJson() => <String, Object?>{
    'leftOnly': result.leftOnly,
    'rightOnly': result.rightOnly,
    'intersection': result.intersection,
    'equal': result.equal,
    'options': <String, Object?>{
      'case': result.caseMode,
      'whitespace': result.whitespaceMode,
      'duplicates': result.duplicateMode,
    },
  };
}

final class ListCompareService
    implements
        OperationService<ListCompareOperationRequest, ListCompareOutput> {
  const ListCompareService({this.comparator = const ListComparator()});

  final ListComparator comparator;

  @override
  Future<ChimeraResult<ListCompareOutput>> execute(
    ListCompareOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<ListCompareOutput>(
        ListCompareOutput(
          comparator.compare(
            ListCompareRequest(
              left: request.left,
              right: request.right,
              caseMode: request.caseMode,
              whitespaceMode: request.whitespaceMode,
              duplicateMode: request.duplicateMode,
            ),
          ),
        ),
      );
    } on ListCompareException catch (error) {
      return ChimeraFailure<ListCompareOutput>(
        kind: switch (error.kind) {
          ListCompareFailureKind.validation => FailureKind.validation,
          ListCompareFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          ListCompareFailureKind.validation => 'error.listCompare.validation',
          ListCompareFailureKind.resource => 'error.listCompare.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
