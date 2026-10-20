import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _AlphabetEncodeSource { text, utf8Bytes }

final class AlphabetEncodeOperationRequest {
  factory AlphabetEncodeOperationRequest.text(
    String input, {
    required String alphabet,
  }) => AlphabetEncodeOperationRequest._(
    source: _AlphabetEncodeSource.text,
    text: input,
    alphabet: alphabet,
  );

  factory AlphabetEncodeOperationRequest.utf8Bytes(
    List<int> input, {
    required String alphabet,
  }) => AlphabetEncodeOperationRequest._(
    source: _AlphabetEncodeSource.utf8Bytes,
    bytes: List<int>.unmodifiable(input),
    alphabet: alphabet,
  );

  const AlphabetEncodeOperationRequest._({
    required this._source,
    this._text,
    this._bytes,
    required this.alphabet,
  });

  final _AlphabetEncodeSource _source;
  final String? _text;
  final List<int>? _bytes;
  final String alphabet;
}

final class AlphabetEncodeOutput {
  const AlphabetEncodeOutput(this.result);

  final AlphabetEncodeResult result;

  String get encoded => result.encoded;
  String get alphabet => result.alphabet.wireName;
  AlphabetMapping get mapping => result.mapping;

  Map<String, Object?> toJson() => <String, Object?>{
    'encoded': encoded,
    'alphabet': alphabet,
    'mapping': <String, Object?>{
      'id': mapping.id,
      'edition': mapping.edition,
      'sources': mapping.sources,
      'symbols': mapping.symbols,
      'rules': mapping.rules,
    },
  };
}

typedef AlphabetEncodeFunction = AlphabetEncodeResult Function(
  AlphabetEncodeRequest request,
);

final class AlphabetEncodeService
    implements
        OperationService<AlphabetEncodeOperationRequest, AlphabetEncodeOutput> {
  const AlphabetEncodeService({
    this.encoder = const AlphabetEncoder(),
    this.encodeOverride,
  });

  final AlphabetEncoder encoder;
  final AlphabetEncodeFunction? encodeOverride;

  @override
  Future<ChimeraResult<AlphabetEncodeOutput>> execute(
    AlphabetEncodeOperationRequest request,
  ) async {
    try {
      final alphabet = AlphabetKind.tryParse(request.alphabet);
      if (alphabet == null) {
        throw const AlphabetException(
          kind: AlphabetFailureKind.validation,
          code: 'alphabet.invalid-alphabet',
          field: 'alphabet',
          reason: 'unsupported-alphabet',
        );
      }

      final result = (encodeOverride ?? encoder.encode)(
        AlphabetEncodeRequest(input: _decodeInput(request), alphabet: alphabet),
      );
      return ChimeraSuccess<AlphabetEncodeOutput>(AlphabetEncodeOutput(result));
    } on AlphabetException catch (error) {
      return ChimeraFailure<AlphabetEncodeOutput>(
        kind: switch (error.kind) {
          AlphabetFailureKind.validation => FailureKind.validation,
          AlphabetFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          AlphabetFailureKind.validation => 'error.alphabetEncode.validation',
          AlphabetFailureKind.resource => 'error.alphabetEncode.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
          if (error.position != null) 'position': error.position,
        },
      );
    } on OutOfMemoryError {
      return const ChimeraFailure<AlphabetEncodeOutput>(
        kind: FailureKind.resource,
        code: 'alphabet.resource-limit',
        messageKey: 'error.alphabetEncode.resource',
        details: <String, Object?>{
          'field': 'input',
          'reason': 'allocation-limit',
        },
      );
    } on Object {
      return const ChimeraFailure<AlphabetEncodeOutput>(
        kind: FailureKind.processing,
        code: 'alphabet.processing-failed',
        messageKey: 'error.alphabetEncode.processing',
      );
    }
  }

  String _decodeInput(AlphabetEncodeOperationRequest request) {
    if (request._source == _AlphabetEncodeSource.text) return request._text!;
    final bytes = request._bytes!;
    try {
      for (final byte in bytes) {
        if (byte < 0 || byte > 0xff) throw const FormatException();
      }
      final decoded = utf8.decode(bytes, allowMalformed: false);
      final hasBom =
          bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf;
      return hasBom ? '\uFEFF$decoded' : decoded;
    } on FormatException {
      throw const AlphabetException(
        kind: AlphabetFailureKind.validation,
        code: 'alphabet.invalid-input',
        field: 'input',
        reason: 'invalid-utf8',
      );
    }
  }
}
