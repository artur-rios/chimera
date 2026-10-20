import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

/// Raw length text lets every adapter use the same strict integer validation.
final class PasswordOperationRequest {
  const PasswordOperationRequest({
    this.length = '16',
    this.lowercase = true,
    this.uppercase = true,
    this.digits = true,
    this.symbols = true,
  });

  final String length;
  final bool lowercase;
  final bool uppercase;
  final bool digits;
  final bool symbols;
}

final class PasswordOutput {
  const PasswordOutput(this.result);

  final PasswordResult result;
  String get password => result.password;
  int get length => result.length;
  List<String> get characterClasses => result.characterClasses;

  Map<String, Object?> toJson() => {
    'length': length,
    'characterClasses': characterClasses,
    'password': password,
  };
}

final class PasswordService
    implements OperationService<PasswordOperationRequest, PasswordOutput> {
  const PasswordService({this.generator = const PasswordGenerator()});

  final PasswordGenerator generator;

  @override
  Future<ChimeraResult<PasswordOutput>> execute(
    PasswordOperationRequest request,
  ) async {
    final length = tryParsePositiveDecimalInteger(request.length);
    if (length == null) {
      return const ChimeraFailure(
        kind: FailureKind.validation,
        code: 'password.invalid-length',
        messageKey: 'error.password.validation',
        details: {
          'field': 'length',
          'reason': 'positive-decimal-integer-required',
        },
      );
    }
    try {
      return ChimeraSuccess(
        PasswordOutput(
          generator.generate(
            PasswordRequest(
              length: length,
              lowercase: request.lowercase,
              uppercase: request.uppercase,
              digits: request.digits,
              symbols: request.symbols,
            ),
          ),
        ),
      );
    } on PasswordException catch (error) {
      final kind = switch (error.kind) {
        PasswordFailureKind.validation => FailureKind.validation,
        PasswordFailureKind.processing => FailureKind.processing,
        PasswordFailureKind.resource => FailureKind.resource,
      };
      final messageKey = switch (error.kind) {
        PasswordFailureKind.validation => 'error.password.validation',
        PasswordFailureKind.processing => 'error.password.processing',
        PasswordFailureKind.resource => 'error.password.resource',
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
        code: 'password.resource-limit',
        messageKey: 'error.password.resource',
      );
    }
  }
}
