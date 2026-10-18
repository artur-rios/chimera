import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _HtmlDecodeSource { text, utf8Bytes }

final class HtmlDecodeOperationRequest {
  factory HtmlDecodeOperationRequest.text(String input) =>
      HtmlDecodeOperationRequest._(source: _HtmlDecodeSource.text, text: input);

  factory HtmlDecodeOperationRequest.utf8Bytes(List<int> input) =>
      HtmlDecodeOperationRequest._(
        source: _HtmlDecodeSource.utf8Bytes,
        bytes: input,
      );

  const HtmlDecodeOperationRequest._({
    required this._source,
    this._text,
    this._bytes,
  });

  final _HtmlDecodeSource _source;
  final String? _text;
  final List<int>? _bytes;
}

final class HtmlDecodeOutput {
  const HtmlDecodeOutput(this.result);

  final HtmlEntityDecodeResult result;

  String get decoded => result.decoded;

  Map<String, Object?> toJson() => <String, Object?>{'decoded': decoded};
}

final class HtmlDecodeService
    implements OperationService<HtmlDecodeOperationRequest, HtmlDecodeOutput> {
  const HtmlDecodeService({this.decoder = const HtmlEntityDecoder()});

  final HtmlEntityDecoder decoder;

  @override
  Future<ChimeraResult<HtmlDecodeOutput>> execute(
    HtmlDecodeOperationRequest request,
  ) async {
    try {
      final result = switch (request._source) {
        _HtmlDecodeSource.text => decoder.decodeText(
          HtmlEntityDecodeRequest(input: request._text!),
        ),
        _HtmlDecodeSource.utf8Bytes => decoder.decodeUtf8(request._bytes!),
      };
      return ChimeraSuccess<HtmlDecodeOutput>(HtmlDecodeOutput(result));
    } on HtmlEntityDecodeException catch (error) {
      return ChimeraFailure<HtmlDecodeOutput>(
        kind: switch (error.kind) {
          HtmlEntityDecodeFailureKind.validation => FailureKind.validation,
          HtmlEntityDecodeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          HtmlEntityDecodeFailureKind.validation =>
            'error.htmlDecode.validation',
          HtmlEntityDecodeFailureKind.resource => 'error.htmlDecode.resource',
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
