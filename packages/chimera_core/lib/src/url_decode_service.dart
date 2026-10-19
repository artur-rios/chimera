import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _UrlDecodeSource { text, utf8Bytes }

final class UrlDecodeOperationRequest {
  factory UrlDecodeOperationRequest.text(String input) =>
      UrlDecodeOperationRequest._(source: _UrlDecodeSource.text, text: input);

  factory UrlDecodeOperationRequest.utf8Bytes(List<int> input) =>
      UrlDecodeOperationRequest._(
        source: _UrlDecodeSource.utf8Bytes,
        bytes: input,
      );

  const UrlDecodeOperationRequest._({
    required this._source,
    this._text,
    this._bytes,
  });

  final _UrlDecodeSource _source;
  final String? _text;
  final List<int>? _bytes;
}

final class UrlDecodeOutput {
  const UrlDecodeOutput(this.result);

  final UrlDecodeResult result;

  String get decoded => result.decoded;

  Map<String, Object?> toJson() => <String, Object?>{'decoded': decoded};
}

final class UrlDecodeService
    implements OperationService<UrlDecodeOperationRequest, UrlDecodeOutput> {
  const UrlDecodeService({this.decoder = const UrlDecoder()});

  final UrlDecoder decoder;

  @override
  Future<ChimeraResult<UrlDecodeOutput>> execute(
    UrlDecodeOperationRequest request,
  ) async {
    try {
      final result = switch (request._source) {
        _UrlDecodeSource.text => decoder.decodeText(
          UrlDecodeRequest(input: request._text!),
        ),
        _UrlDecodeSource.utf8Bytes => decoder.decodeUtf8(request._bytes!),
      };
      return ChimeraSuccess<UrlDecodeOutput>(UrlDecodeOutput(result));
    } on UrlDecodeException catch (error) {
      return ChimeraFailure<UrlDecodeOutput>(
        kind: switch (error.kind) {
          UrlDecodeFailureKind.validation => FailureKind.validation,
          UrlDecodeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          UrlDecodeFailureKind.validation => 'error.urlDecode.validation',
          UrlDecodeFailureKind.resource => 'error.urlDecode.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
          'offset': ?error.offset,
        },
      );
    }
  }
}
