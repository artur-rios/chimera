import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class CardOperationRequest {
  const CardOperationRequest({this.network = 'visa', this.count = '1'});

  final String network;
  final String count;
}

final class CardOutput {
  const CardOutput(this.result);

  final CardGenerationResult result;
  String get network => switch (result.network) {
    CardNetwork.visa => 'visa',
    CardNetwork.mastercard => 'mastercard',
    CardNetwork.americanExpress => 'amex',
    CardNetwork.discover => 'discover',
  };
  int get count => result.values.length;
  bool get synthetic => result.synthetic;
  String get label => 'synthetic-test-data';
  List<String> get values => result.values;

  Map<String, Object?> toJson() => {
    'network': network,
    'count': count,
    'synthetic': synthetic,
    'label': label,
    'values': values,
  };
}

final class CardService
    implements OperationService<CardOperationRequest, CardOutput> {
  const CardService({this.generator = const CardGenerator()});

  final CardGenerator generator;

  @override
  Future<ChimeraResult<CardOutput>> execute(
    CardOperationRequest request,
  ) async {
    final network = switch (request.network) {
      'visa' => CardNetwork.visa,
      'mastercard' => CardNetwork.mastercard,
      'amex' => CardNetwork.americanExpress,
      'discover' => CardNetwork.discover,
      _ => null,
    };
    if (network == null) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'card.invalid-network',
        messageKey: 'error.card.validation',
        details: {
          'field': 'network',
          'reason': 'visa-mastercard-amex-or-discover-required',
        },
      );
    }
    final count = tryParsePositiveDecimalInteger(request.count);
    if (count == null) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'card.invalid-count',
        messageKey: 'error.card.validation',
        details: {'field': 'count', 'reason': 'positive-integer-required'},
      );
    }

    try {
      return ChimeraSuccess(
        CardOutput(
          generator.generate(
            CardGenerationRequest(network: network, count: count),
          ),
        ),
      );
    } on CardGenerationException catch (error) {
      final kind = switch (error.kind) {
        CardGenerationFailureKind.validation => FailureKind.validation,
        CardGenerationFailureKind.processing => FailureKind.processing,
        CardGenerationFailureKind.resource => FailureKind.resource,
      };
      final messageKey = switch (error.kind) {
        CardGenerationFailureKind.validation => 'error.card.validation',
        CardGenerationFailureKind.processing => 'error.card.processing',
        CardGenerationFailureKind.resource => 'error.card.resource',
      };
      return ChimeraFailure(
        kind: kind,
        code: error.code,
        messageKey: messageKey,
        details: {'field': error.field, 'reason': error.reason},
      );
    } on OutOfMemoryError {
      return const ChimeraFailure(
        kind: FailureKind.resource,
        code: 'card.resource-limit',
        messageKey: 'error.card.resource',
      );
    }
  }
}
