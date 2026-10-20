import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _CipherDecodeSource { text, utf8Bytes }

final class CipherDecodeOperationRequest {
  factory CipherDecodeOperationRequest.text(
    String input, {
    required String cipher,
    String characterPolicy = 'preserve',
    String? shift,
    String? key,
    String? affineA,
    String? affineB,
    String? rails,
  }) => CipherDecodeOperationRequest._(
    source: _CipherDecodeSource.text,
    text: input,
    cipher: cipher,
    characterPolicy: characterPolicy,
    shift: shift,
    key: key,
    affineA: affineA,
    affineB: affineB,
    rails: rails,
  );

  factory CipherDecodeOperationRequest.utf8Bytes(
    List<int> input, {
    required String cipher,
    String characterPolicy = 'preserve',
    String? shift,
    String? key,
    String? affineA,
    String? affineB,
    String? rails,
  }) => CipherDecodeOperationRequest._(
    source: _CipherDecodeSource.utf8Bytes,
    bytes: List<int>.unmodifiable(input),
    cipher: cipher,
    characterPolicy: characterPolicy,
    shift: shift,
    key: key,
    affineA: affineA,
    affineB: affineB,
    rails: rails,
  );

  const CipherDecodeOperationRequest._({
    required this._source,
    this._text,
    this._bytes,
    required this.cipher,
    required this.characterPolicy,
    this.shift,
    this.key,
    this.affineA,
    this.affineB,
    this.rails,
  });

  final _CipherDecodeSource _source;
  final String? _text;
  final List<int>? _bytes;
  final String cipher;
  final String characterPolicy;
  final String? shift;
  final String? key;
  final String? affineA;
  final String? affineB;
  final String? rails;
}

final class CipherDecodeOutput {
  const CipherDecodeOutput(this.result);

  final CipherDecodeResult result;

  String get decoded => result.decoded;
  String get cipher => result.algorithm.wireName;
  String get characterPolicy => result.characterPolicy.wireName;

  Map<String, Object?> toJson() => <String, Object?>{
    'decoded': decoded,
    'cipher': cipher,
    'characterPolicy': characterPolicy,
  };
}

typedef CipherDecodeFunction = CipherDecodeResult Function(
  CipherDecodeRequest request,
);

final class CipherDecodeService
    implements
        OperationService<CipherDecodeOperationRequest, CipherDecodeOutput> {
  const CipherDecodeService({
    this.decoder = const CipherDecoder(),
    this.decodeOverride,
  });

  final CipherDecoder decoder;
  final CipherDecodeFunction? decodeOverride;

  @override
  Future<ChimeraResult<CipherDecodeOutput>> execute(
    CipherDecodeOperationRequest request,
  ) async {
    try {
      final algorithm = CipherAlgorithm.tryParse(request.cipher);
      if (algorithm == null) {
        throw const CipherException(
          kind: CipherFailureKind.validation,
          code: 'cipher.invalid-cipher',
          field: 'cipher',
          reason: 'unsupported-cipher',
        );
      }
      final policy = CipherCharacterPolicy.tryParse(request.characterPolicy);
      if (policy == null) {
        throw const CipherException(
          kind: CipherFailureKind.validation,
          code: 'cipher.invalid-character-policy',
          field: 'characterPolicy',
          reason: 'unsupported-policy',
        );
      }

      final input = _decodeInput(request);
      final result = (decodeOverride ?? decoder.decode)(
        CipherDecodeRequest(
          input: input,
          algorithm: algorithm,
          characterPolicy: policy,
          shift: _parseOptionalInteger(request.shift, field: 'shift'),
          key: request.key,
          affineA: _parseOptionalInteger(request.affineA, field: 'a'),
          affineB: _parseOptionalInteger(request.affineB, field: 'b'),
          rails: _parseOptionalInteger(request.rails, field: 'rails'),
        ),
      );
      return ChimeraSuccess<CipherDecodeOutput>(CipherDecodeOutput(result));
    } on CipherException catch (error) {
      return ChimeraFailure<CipherDecodeOutput>(
        kind: switch (error.kind) {
          CipherFailureKind.validation => FailureKind.validation,
          CipherFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          CipherFailureKind.validation => 'error.cipherDecode.validation',
          CipherFailureKind.resource => 'error.cipherDecode.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
          if (error.position != null) 'position': error.position,
        },
      );
    } on OutOfMemoryError {
      return const ChimeraFailure<CipherDecodeOutput>(
        kind: FailureKind.resource,
        code: 'cipher.resource-limit',
        messageKey: 'error.cipherDecode.resource',
        details: <String, Object?>{
          'field': 'input',
          'reason': 'allocation-limit',
        },
      );
    } on Object {
      return const ChimeraFailure<CipherDecodeOutput>(
        kind: FailureKind.processing,
        code: 'cipher.processing-failed',
        messageKey: 'error.cipherDecode.processing',
      );
    }
  }

  String _decodeInput(CipherDecodeOperationRequest request) {
    if (request._source == _CipherDecodeSource.text) return request._text!;
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
      throw const CipherException(
        kind: CipherFailureKind.validation,
        code: 'cipher.invalid-input',
        field: 'input',
        reason: 'invalid-utf8',
      );
    }
  }

  int? _parseOptionalInteger(String? value, {required String field}) {
    if (value == null) return null;
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw CipherException(
        kind: CipherFailureKind.validation,
        code: 'cipher.invalid-parameter',
        field: field,
        reason: 'invalid-integer',
      );
    }
    return parsed;
  }
}
