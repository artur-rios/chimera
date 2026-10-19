import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

/// Raw count text lets every adapter use the same strict integer validation.
final class LoremOperationRequest {
  const LoremOperationRequest({this.unit = 'paragraphs', this.count = '1'});
  final String unit;
  final String count;
}

final class LoremOutput {
  const LoremOutput(this.result);
  final LoremResult result;
  String get unit => result.unit;
  int get count => result.count;
  String get text => result.text;
  Map<String, Object?> toJson() => {'unit': unit, 'count': count, 'text': text};
}

final class LoremService
    implements OperationService<LoremOperationRequest, LoremOutput> {
  const LoremService({this.generator = const LoremGenerator()});
  final LoremGenerator generator;

  @override
  Future<ChimeraResult<LoremOutput>> execute(
    LoremOperationRequest request,
  ) async {
    try {
      final count = int.tryParse(request.count);
      if (!RegExp(r'^[0-9]+$').hasMatch(request.count) ||
          count == null ||
          count < 1) {
        throw const LoremException(
          LoremFailureKind.validation,
          'lorem.invalid-count',
          'count',
          'positive-integer-required',
        );
      }
      return ChimeraSuccess(
        LoremOutput(
          generator.generate(LoremRequest(unit: request.unit, count: count)),
        ),
      );
    } on LoremException catch (error) {
      return ChimeraFailure(
        kind: error.kind == LoremFailureKind.validation
            ? FailureKind.validation
            : FailureKind.resource,
        code: error.code,
        messageKey: error.kind == LoremFailureKind.validation
            ? 'error.lorem.validation'
            : 'error.lorem.resource',
        details: {'field': error.field, 'reason': error.reason},
      );
    } on OutOfMemoryError {
      return const ChimeraFailure(
        kind: FailureKind.resource,
        code: 'lorem.resource-limit',
        messageKey: 'error.lorem.resource',
      );
    }
  }
}
