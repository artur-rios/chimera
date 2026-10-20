import 'dart:convert';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _CipherEncodeSource { text, utf8Bytes }

final class CipherEncodeOperationRequest {
  factory CipherEncodeOperationRequest.text(
    String input, {
    required String cipher,
    String characterPolicy = 'preserve',
    String? shift,
    String? key,
    String? affineA,
    String? affineB,
    String? rails,
  }) => CipherEncodeOperationRequest._(
    source: _CipherEncodeSource.text,
    text: input,
    cipher: cipher,
    characterPolicy: characterPolicy,
    shift: shift,
    key: key,
    affineA: affineA,
    affineB: affineB,
    rails: rails,
  );

  factory CipherEncodeOperationRequest.utf8Bytes(
    List<int> input, {
    required String cipher,
    String characterPolicy = 'preserve',
    String? shift,
    String? key,
    String? affineA,
    String? affineB,
    String? rails,
  }) => CipherEncodeOperationRequest._(
    source: _CipherEncodeSource.utf8Bytes,
    bytes: List<int>.unmodifiable(input),
    cipher: cipher,
    characterPolicy: characterPolicy,
    shift: shift,
    key: key,
    affineA: affineA,
    affineB: affineB,
    rails: rails,
  );

  const CipherEncodeOperationRequest._({
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

  final _CipherEncodeSource _source;
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

final class CipherEncodeOutput {
  const CipherEncodeOutput(this.result);

  final CipherEncodeResult result;

  String get encoded => result.encoded;
  String get cipher => result.algorithm.wireName;
  String get characterPolicy => result.characterPolicy.wireName;

  Map<String, Object?> toJson() => <String, Object?>{
    'encoded': encoded,
    'cipher': cipher,
    'characterPolicy': characterPolicy,
  };
}

final class CipherEncodeService
    implements
        OperationService<CipherEncodeOperationRequest, CipherEncodeOutput> {
  const CipherEncodeService({this.encoder = const CipherEncoder()});

  final CipherEncoder encoder;

  @override
  Future<ChimeraResult<CipherEncodeOutput>> execute(
    CipherEncodeOperationRequest request,
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
      final result = encoder.encode(
        CipherEncodeRequest(
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
      return ChimeraSuccess<CipherEncodeOutput>(CipherEncodeOutput(result));
    } on CipherException catch (error) {
      return ChimeraFailure<CipherEncodeOutput>(
        kind: switch (error.kind) {
          CipherFailureKind.validation => FailureKind.validation,
          CipherFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          CipherFailureKind.validation => 'error.cipherEncode.validation',
          CipherFailureKind.resource => 'error.cipherEncode.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
          if (error.position != null) 'position': error.position,
        },
      );
    } on OutOfMemoryError {
      return const ChimeraFailure<CipherEncodeOutput>(
        kind: FailureKind.resource,
        code: 'cipher.resource-limit',
        messageKey: 'error.cipherEncode.resource',
        details: <String, Object?>{
          'field': 'input',
          'reason': 'allocation-limit',
        },
      );
    }
  }

  String _decodeInput(CipherEncodeOperationRequest request) {
    if (request._source == _CipherEncodeSource.text) return request._text!;
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
