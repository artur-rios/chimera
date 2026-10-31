import 'dart:typed_data';

import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class CertificateConvertOperationRequest {
  const CertificateConvertOperationRequest.fromText(
    String input, {
    this.source = CertificateInputRepresentation.auto,
    required this.target,
  }) : _text = input,
       _bytes = null;

  const CertificateConvertOperationRequest.fromBytes(
    List<int> input, {
    this.source = CertificateInputRepresentation.auto,
    required this.target,
  }) : _bytes = input,
       _text = null;

  final CertificateInputRepresentation source;
  final CertificateOutputRepresentation target;
  final String? _text;
  final List<int>? _bytes;
}

/// The utility's one immutable output byte list, with transient text/JSON views.
final class CertificateConvertOutput {
  const CertificateConvertOutput({required this.result});

  final CertificateConversionResult result;

  CertificateInputRepresentation get sourceRepresentation =>
      result.sourceRepresentation;
  CertificateOutputRepresentation get targetRepresentation =>
      result.targetRepresentation;
  Uint8List get bytes => result.bytes;
  String? get text => result.text;
  int get inputByteCount => result.inputByteCount;
  int get derByteCount => result.derByteCount;
  int get outputByteCount => result.outputByteCount;

  Map<String, Object?> toJson() => Map<String, Object?>.unmodifiable({
    'sourceRepresentation': sourceRepresentation.name,
    'targetRepresentation': targetRepresentation.name,
    'text': text,
    'bytes': targetRepresentation == CertificateOutputRepresentation.der
        ? List<int>.unmodifiable(bytes)
        : null,
    'inputByteCount': inputByteCount,
    'derByteCount': derByteCount,
    'outputByteCount': outputByteCount,
  });
}

final class CertificateConvertService
    implements
        OperationService<
          CertificateConvertOperationRequest,
          CertificateConvertOutput
        > {
  const CertificateConvertService({
    this.converter = const CertificateConverter(),
  });

  final CertificateConverter converter;

  @override
  Future<ChimeraResult<CertificateConvertOutput>> execute(
    CertificateConvertOperationRequest request,
  ) async {
    try {
      final result = switch (request._text) {
        final text? => converter.convertText(
          text,
          source: request.source,
          target: request.target,
        ),
        null => converter.convertBytes(
          request._bytes!,
          source: request.source,
          target: request.target,
        ),
      };
      return ChimeraSuccess<CertificateConvertOutput>(
        CertificateConvertOutput(result: result),
      );
    } on CertificateConversionException catch (error) {
      return ChimeraFailure<CertificateConvertOutput>(
        kind: FailureKind.validation,
        code: error.code,
        messageKey: 'error.certificateConvert.validation',
        details: Map<String, Object?>.unmodifiable({
          'field': error.field,
          'reason': error.reason,
        }),
      );
    } on CertificateConversionResourceException catch (error) {
      return ChimeraFailure<CertificateConvertOutput>(
        kind: FailureKind.resource,
        code: error.code,
        messageKey: 'error.certificateConvert.resource',
        details: Map<String, Object?>.unmodifiable({
          'field': error.field,
          'reason': error.reason,
        }),
      );
    }
  }
}
