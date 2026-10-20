import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _AlphabetDecodeSource { text, utf8Bytes }

final class AlphabetDecodeOperationRequest {
  factory AlphabetDecodeOperationRequest.text(
    String input, {
    required String alphabet,
  }) => AlphabetDecodeOperationRequest._(
    source: _AlphabetDecodeSource.text,
    text: input,
    alphabet: alphabet,
  );

  factory AlphabetDecodeOperationRequest.utf8Bytes(
    List<int> input, {
    required String alphabet,
  }) => AlphabetDecodeOperationRequest._(
    source: _AlphabetDecodeSource.utf8Bytes,
    bytes: List<int>.unmodifiable(input),
    alphabet: alphabet,
  );

  const AlphabetDecodeOperationRequest._({
    required this._source,
    this._text,
    this._bytes,
    required this.alphabet,
  });

  final _AlphabetDecodeSource _source;
  final String? _text;
  final List<int>? _bytes;
  final String alphabet;
}

final class AlphabetDecodeOutput {
  const AlphabetDecodeOutput(this.result);

  final AlphabetDecodeResult result;

  String get decoded => result.decoded;
  String get alphabet => result.alphabet.wireName;
  AlphabetMapping get mapping => result.mapping;

  Map<String, Object?> toJson() => <String, Object?>{
    'decoded': decoded,
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

typedef AlphabetDecodeFunction = AlphabetDecodeResult Function(
  AlphabetDecodeRequest request,
);

final class AlphabetDecodeService
    implements
        OperationService<AlphabetDecodeOperationRequest, AlphabetDecodeOutput> {
  const AlphabetDecodeService({
    this.decoder = const AlphabetDecoder(),
    this.decodeOverride,
  });

  final AlphabetDecoder decoder;
  final AlphabetDecodeFunction? decodeOverride;

  @override
  Future<ChimeraResult<AlphabetDecodeOutput>> execute(
    AlphabetDecodeOperationRequest request,
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

      final result = (decodeOverride ?? decoder.decode)(
        AlphabetDecodeRequest(input: _decodeInput(request), alphabet: alphabet),
      );
      return ChimeraSuccess<AlphabetDecodeOutput>(AlphabetDecodeOutput(result));
    } on AlphabetException catch (error) {
      return ChimeraFailure<AlphabetDecodeOutput>(
        kind: switch (error.kind) {
          AlphabetFailureKind.validation => FailureKind.validation,
          AlphabetFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          AlphabetFailureKind.validation => 'error.alphabetDecode.validation',
          AlphabetFailureKind.resource => 'error.alphabetDecode.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
          if (error.position != null) 'position': error.position,
        },
      );
    } on OutOfMemoryError {
      return const ChimeraFailure<AlphabetDecodeOutput>(
        kind: FailureKind.resource,
        code: 'alphabet.resource-limit',
        messageKey: 'error.alphabetDecode.resource',
        details: <String, Object?>{
          'field': 'input',
          'reason': 'allocation-limit',
        },
      );
    } on Object {
      return const ChimeraFailure<AlphabetDecodeOutput>(
        kind: FailureKind.processing,
        code: 'alphabet.processing-failed',
        messageKey: 'error.alphabetDecode.processing',
      );
    }
  }

  String _decodeInput(AlphabetDecodeOperationRequest request) {
    if (request._source == _AlphabetDecodeSource.text) return request._text!;
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
