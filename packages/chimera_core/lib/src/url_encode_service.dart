import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

enum _UrlEncodeSource { text, utf8Bytes }

final class UrlEncodeOperationRequest {
  factory UrlEncodeOperationRequest.text(
    String input, {
    String mode = 'component',
  }) => UrlEncodeOperationRequest._(
    source: _UrlEncodeSource.text,
    text: input,
    mode: mode,
  );

  factory UrlEncodeOperationRequest.utf8Bytes(
    List<int> input, {
    String mode = 'component',
  }) => UrlEncodeOperationRequest._(
    source: _UrlEncodeSource.utf8Bytes,
    bytes: input,
    mode: mode,
  );

  const UrlEncodeOperationRequest._({
    required this._source,
    this._text,
    this._bytes,
    required this.mode,
  });

  final _UrlEncodeSource _source;
  final String? _text;
  final List<int>? _bytes;
  final String mode;
}

final class UrlEncodeOutput {
  const UrlEncodeOutput(this.result);

  final UrlEncodeResult result;

  String get encoded => result.encoded;
  String get mode => result.mode;

  Map<String, Object?> toJson() => <String, Object?>{
    'encoded': encoded,
    'mode': mode,
  };
}

final class UrlEncodeService
    implements OperationService<UrlEncodeOperationRequest, UrlEncodeOutput> {
  const UrlEncodeService({this.encoder = const UrlEncoder()});

  final UrlEncoder encoder;

  @override
  Future<ChimeraResult<UrlEncodeOutput>> execute(
    UrlEncodeOperationRequest request,
  ) async {
    try {
      final result = switch (request._source) {
        _UrlEncodeSource.text => encoder.encodeText(
          UrlEncodeRequest(input: request._text!, mode: request.mode),
        ),
        _UrlEncodeSource.utf8Bytes => encoder.encodeUtf8(
          request._bytes!,
          mode: request.mode,
        ),
      };
      return ChimeraSuccess<UrlEncodeOutput>(UrlEncodeOutput(result));
    } on UrlEncodeException catch (error) {
      return ChimeraFailure<UrlEncodeOutput>(
        kind: switch (error.kind) {
          UrlEncodeFailureKind.validation => FailureKind.validation,
          UrlEncodeFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          UrlEncodeFailureKind.validation => 'error.urlEncode.validation',
          UrlEncodeFailureKind.resource => 'error.urlEncode.resource',
        },
        details: <String, Object?>{
          'field': error.field,
          'reason': error.reason,
        },
      );
    }
  }
}
