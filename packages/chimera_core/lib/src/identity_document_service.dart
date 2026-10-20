import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class IdentityDocumentOperationRequest {
  const IdentityDocumentOperationRequest({
    this.locale = 'us',
    this.type = 'ssn',
    this.cnpjFormat,
    this.count = '1',
  });

  final String locale;
  final String type;
  final String? cnpjFormat;
  final String count;
}

final class IdentityDocumentOutput {
  const IdentityDocumentOutput(this.result);

  final IdentityDocumentResult result;

  String get locale => result.locale.name;
  String get type => result.type.name;
  String? get cnpjFormat =>
      result.type == IdentityDocumentType.cnpj ? result.cnpjFormat.name : null;
  int get count => result.values.length;
  bool get synthetic => result.synthetic;
  String get label => 'synthetic-test-data';
  List<String> get values => result.values;

  Map<String, Object?> toJson() => {
    'locale': locale,
    'type': type,
    if (cnpjFormat case final format?) 'cnpjFormat': format,
    'count': count,
    'synthetic': synthetic,
    'label': label,
    'values': values,
  };
}

final class IdentityDocumentService
    implements
        OperationService<
          IdentityDocumentOperationRequest,
          IdentityDocumentOutput
        > {
  const IdentityDocumentService({
    this.generator = const IdentityDocumentGenerator(),
  });

  final IdentityDocumentGenerator generator;

  @override
  Future<ChimeraResult<IdentityDocumentOutput>> execute(
    IdentityDocumentOperationRequest request,
  ) async {
    final locale = switch (request.locale) {
      'us' => IdentityLocale.us,
      'br' => IdentityLocale.br,
      _ => null,
    };
    if (locale == null) {
      return _validation(
        'document.invalid-locale',
        'locale',
        'us-or-br-required',
      );
    }
    if (request.type == 'rg') {
      return _validation(
        'document.rg-jurisdiction-required',
        'type',
        'legacy-rg-is-state-specific-use-cin',
      );
    }
    final type = switch (request.type) {
      'ssn' => IdentityDocumentType.ssn,
      'itin' => IdentityDocumentType.itin,
      'ein' => IdentityDocumentType.ein,
      'cpf' => IdentityDocumentType.cpf,
      'cnpj' => IdentityDocumentType.cnpj,
      'cnh' => IdentityDocumentType.cnh,
      'cin' => IdentityDocumentType.cin,
      _ => null,
    };
    if (type == null) {
      return _validation(
        'document.invalid-type',
        'type',
        'supported-document-type-required',
      );
    }
    if (type != IdentityDocumentType.cnpj && request.cnpjFormat != null) {
      return _validation(
        'document.invalid-cnpj-format',
        'cnpjFormat',
        'format-only-applies-to-cnpj',
      );
    }
    final cnpjFormat = switch (request.cnpjFormat) {
      null || 'alphanumeric' => CnpjFormat.alphanumeric,
      'numeric' => CnpjFormat.numeric,
      _ => null,
    };
    if (cnpjFormat == null) {
      return _validation(
        'document.invalid-cnpj-format',
        'cnpjFormat',
        'numeric-or-alphanumeric-required',
      );
    }
    final count = tryParsePositiveDecimalInteger(request.count);
    if (count == null) {
      return _validation(
        'document.invalid-count',
        'count',
        'positive-integer-required',
      );
    }

    try {
      return ChimeraSuccess(
        IdentityDocumentOutput(
          generator.generate(
            IdentityDocumentRequest(
              locale: locale,
              type: type,
              cnpjFormat: cnpjFormat,
              count: count,
            ),
          ),
        ),
      );
    } on IdentityDocumentGenerationException catch (error) {
      final kind = switch (error.kind) {
        IdentityDocumentFailureKind.validation => FailureKind.validation,
        IdentityDocumentFailureKind.processing => FailureKind.processing,
        IdentityDocumentFailureKind.resource => FailureKind.resource,
      };
      final messageKey = switch (error.kind) {
        IdentityDocumentFailureKind.validation => 'error.document.validation',
        IdentityDocumentFailureKind.processing => 'error.document.processing',
        IdentityDocumentFailureKind.resource => 'error.document.resource',
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
        code: 'document.resource-limit',
        messageKey: 'error.document.resource',
      );
    }
  }
}

ChimeraFailure<IdentityDocumentOutput> _validation(
  String code,
  String field,
  String reason,
) => ChimeraFailure(
  kind: FailureKind.validation,
  code: code,
  messageKey: 'error.document.validation',
  details: {'field': field, 'reason': reason},
);
