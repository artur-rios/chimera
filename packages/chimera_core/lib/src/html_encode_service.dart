import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _HtmlEncodeSource { text, utf8Bytes }

final class HtmlEncodeOperationRequest {
  factory HtmlEncodeOperationRequest.text(
    String input, {
    String context = 'all',
  }) => HtmlEncodeOperationRequest._(
    source: _HtmlEncodeSource.text,
    text: input,
    context: context,
  );

  factory HtmlEncodeOperationRequest.utf8Bytes(
    List<int> input, {
    String context = 'all',
  }) => HtmlEncodeOperationRequest._(
    source: _HtmlEncodeSource.utf8Bytes,
    bytes: input,
    context: context,
  );

  const HtmlEncodeOperationRequest._({
    required this._source,
    this._text,
    this._bytes,
    required this.context,
  });

  final _HtmlEncodeSource _source;
  final String? _text;
  final List<int>? _bytes;
  final String context;
}

final class HtmlEncodeOutput {
  const HtmlEncodeOutput(this.result);

  final HtmlEntityEncodeResult result;

  String get encoded => result.encoded;
  String get context => result.context;

  Map<String, Object?> toJson() => <String, Object?>{
    'encoded': encoded,
    'context': context,
  };
}

final class HtmlEncodeService
    implements OperationService<HtmlEncodeOperationRequest, HtmlEncodeOutput> {
  const HtmlEncodeService({this.encoder = const HtmlEntityEncoder()});

  final HtmlEntityEncoder encoder;

  @override
  Future<ChimeraResult<HtmlEncodeOutput>> execute(
    HtmlEncodeOperationRequest request,
  ) async {
    try {
      final result = switch (request._source) {
        _HtmlEncodeSource.text => encoder.encodeText(
          HtmlEntityEncodeRequest(
            input: request._text!,
            context: request.context,
          ),
        ),
        _HtmlEncodeSource.utf8Bytes => encoder.encodeUtf8(
          request._bytes!,
          context: request.context,
        ),
      };
      return ChimeraSuccess<HtmlEncodeOutput>(HtmlEncodeOutput(result));
    } on HtmlEntityEncodeException catch (error) {
      return ChimeraFailure<HtmlEncodeOutput>(
        kind: switch (error.kind) {
          HtmlEntityEncodeFailureKind.validation => FailureKind.validation,
          HtmlEntityEncodeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          HtmlEntityEncodeFailureKind.validation =>
            'error.htmlEncode.validation',
          HtmlEntityEncodeFailureKind.resource => 'error.htmlEncode.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
        },
      );
    }
  }
}
