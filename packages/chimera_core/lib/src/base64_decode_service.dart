import 'dart:typed_data';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _Base64DecodeSource { text, utf8Bytes }

final class Base64DecodeOperationRequest {
  factory Base64DecodeOperationRequest.text(
    String input, {
    required Base64DecodeMode mode,
  }) => Base64DecodeOperationRequest._(
    source: _Base64DecodeSource.text,
    text: input,
    mode: mode,
  );

  factory Base64DecodeOperationRequest.utf8Bytes(
    List<int> input, {
    required Base64DecodeMode mode,
  }) => Base64DecodeOperationRequest._(
    source: _Base64DecodeSource.utf8Bytes,
    bytes: input,
    mode: mode,
  );

  const Base64DecodeOperationRequest._({
    required this._source,
    required this.mode,
    this._bytes,
    this._text,
  });

  final _Base64DecodeSource _source;
  final Base64DecodeMode mode;
  final List<int>? _bytes;
  final String? _text;
}

final class Base64DecodeOutput {
  const Base64DecodeOutput({required this.mode, required this.result});

  final Base64DecodeMode mode;
  final Base64DecodeResult result;

  Uint8List get bytes => result.bytes;
  String? get text => result.text;
  int get inputCharacterCount => result.inputCharacterCount;
  int get outputByteCount => result.outputByteCount;
  String? get imageCandidateMediaType => result.imageCandidateMediaType;

  Map<String, Object?> toJson() => <String, Object?>{
    'mode': mode.name,
    'text': mode == Base64DecodeMode.text ? result.text : null,
    'bytes': mode == Base64DecodeMode.binary
        ? result.bytes.toList(growable: false)
        : null,
    'inputCharacterCount': result.inputCharacterCount,
    'outputByteCount': result.outputByteCount,
    'imageCandidateMediaType': result.imageCandidateMediaType,
  };
}

final class Base64DecodeService
    implements
        OperationService<Base64DecodeOperationRequest, Base64DecodeOutput> {
  const Base64DecodeService({this.decoder = const Base64ByteDecoder()});

  final Base64ByteDecoder decoder;

  @override
  Future<ChimeraResult<Base64DecodeOutput>> execute(
    Base64DecodeOperationRequest request,
  ) async {
    try {
      final decoded = switch (request._source) {
        _Base64DecodeSource.text => decoder.decodeString(
          request._text!,
          mode: request.mode,
        ),
        _Base64DecodeSource.utf8Bytes => decoder.decodeUtf8(
          request._bytes!,
          mode: request.mode,
        ),
      };

      return ChimeraSuccess<Base64DecodeOutput>(
        Base64DecodeOutput(mode: request.mode, result: decoded),
      );
    } on Base64DecodeException catch (error) {
      return ChimeraFailure<Base64DecodeOutput>(
        kind: switch (error.kind) {
          Base64DecodeFailureKind.validation => FailureKind.validation,
          Base64DecodeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          Base64DecodeFailureKind.validation => 'error.base64Decode.validation',
          Base64DecodeFailureKind.resource => 'error.base64Decode.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
