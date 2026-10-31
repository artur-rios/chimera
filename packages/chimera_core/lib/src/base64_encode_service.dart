import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _Base64EncodeSource { bytes, text, utf8Bytes }

final class Base64EncodeOperationRequest {
  factory Base64EncodeOperationRequest.bytes(List<int> input) =>
      Base64EncodeOperationRequest._(
        source: _Base64EncodeSource.bytes,
        bytes: input,
      );

  factory Base64EncodeOperationRequest.text(String input) =>
      Base64EncodeOperationRequest._(
        source: _Base64EncodeSource.text,
        text: input,
      );

  factory Base64EncodeOperationRequest.utf8Bytes(List<int> input) =>
      Base64EncodeOperationRequest._(
        source: _Base64EncodeSource.utf8Bytes,
        bytes: input,
      );

  const Base64EncodeOperationRequest._({
    required this._source,
    this._bytes,
    this._text,
  });

  final _Base64EncodeSource _source;
  final List<int>? _bytes;
  final String? _text;
}

final class Base64EncodeOutput {
  const Base64EncodeOutput(this.result);

  final Base64EncodeResult result;

  String get encoded => result.encoded;
  int get inputByteCount => result.inputByteCount;
  int get outputCharacterCount => result.outputCharacterCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'encoded': result.encoded,
    'inputByteCount': result.inputByteCount,
    'outputCharacterCount': result.outputCharacterCount,
  };
}

final class Base64EncodeService
    implements
        OperationService<Base64EncodeOperationRequest, Base64EncodeOutput> {
  const Base64EncodeService({this.encoder = const Base64ByteEncoder()});

  final Base64ByteEncoder encoder;

  @override
  Future<ChimeraResult<Base64EncodeOutput>> execute(
    Base64EncodeOperationRequest request,
  ) async {
    try {
      final encoded = switch (request._source) {
        _Base64EncodeSource.bytes => encoder.encodeBytes(request._bytes!),
        _Base64EncodeSource.text => encoder.encodeText(request._text!),
        _Base64EncodeSource.utf8Bytes => encoder.encodeUtf8(request._bytes!),
      };

      return ChimeraSuccess<Base64EncodeOutput>(Base64EncodeOutput(encoded));
    } on Base64EncodeException catch (error) {
      return ChimeraFailure<Base64EncodeOutput>(
        kind: switch (error.kind) {
          Base64EncodeFailureKind.validation => FailureKind.validation,
          Base64EncodeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          Base64EncodeFailureKind.validation => 'error.base64Encode.validation',
          Base64EncodeFailureKind.resource => 'error.base64Encode.resource',
        },
        details: <String, Object?>{
          'field': ?error.field,
          'reason': ?error.reason,
        },
      );
    }
  }
}
