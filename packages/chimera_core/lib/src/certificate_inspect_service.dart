import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class CertificateInspectOperationRequest {
  const CertificateInspectOperationRequest.fromText(
    String input, {
    this.representation = CertificateInputRepresentation.auto,
  }) : _text = input,
       _bytes = null;

  const CertificateInspectOperationRequest.fromBytes(
    List<int> input, {
    this.representation = CertificateInputRepresentation.auto,
  }) : _bytes = input,
       _text = null;

  final CertificateInputRepresentation representation;
  final String? _text;
  final List<int>? _bytes;
}

/// An immutable view of certificate metadata, without source or key material.
final class CertificateInspectOutput {
  const CertificateInspectOutput({required this.result});

  final CertificateInspectionResult result;

  CertificateInputRepresentation get representation => result.representation;
  int get version => result.version;
  String get serialNumberHex => result.serialNumberHex;
  List<CertificateAttribute> get subject => result.subject;
  List<CertificateAttribute> get issuer => result.issuer;
  DateTime get notBefore => result.notBefore;
  DateTime get notAfter => result.notAfter;
  CertificateAlgorithm get signatureAlgorithm => result.signatureAlgorithm;
  CertificateAlgorithm get publicKeyAlgorithm => result.publicKeyAlgorithm;
  List<CertificateExtensionMetadata> get extensions => result.extensions;
  int get inputByteCount => result.inputByteCount;
  int get derByteCount => result.derByteCount;

  Map<String, Object?> toJson() => Map<String, Object?>.unmodifiable({
    'representation': representation.name,
    'version': version,
    'serialNumberHex': serialNumberHex,
    'subject': _attributes(subject),
    'issuer': _attributes(issuer),
    'notBefore': _timestamp(notBefore),
    'notAfter': _timestamp(notAfter),
    'signatureAlgorithm': _algorithm(signatureAlgorithm),
    'publicKeyAlgorithm': _algorithm(publicKeyAlgorithm),
    'extensions': List<Map<String, Object?>>.unmodifiable([
      for (final extension in extensions)
        Map<String, Object?>.unmodifiable({
          'oid': extension.oid,
          'name': extension.name,
          'critical': extension.critical,
        }),
    ]),
    'inputByteCount': inputByteCount,
    'derByteCount': derByteCount,
  });

  static List<Map<String, Object?>> _attributes(
    List<CertificateAttribute> attributes,
  ) => List<Map<String, Object?>>.unmodifiable([
    for (final attribute in attributes)
      Map<String, Object?>.unmodifiable({
        'oid': attribute.oid,
        'name': attribute.name,
        'value': attribute.value,
      }),
  ]);

  static Map<String, Object?> _algorithm(CertificateAlgorithm algorithm) =>
      Map<String, Object?>.unmodifiable({
        'oid': algorithm.oid,
        'name': algorithm.name,
      });

  static String _timestamp(DateTime value) =>
      DateTime.fromMillisecondsSinceEpoch(
        value.millisecondsSinceEpoch,
        isUtc: true,
      ).toIso8601String();
}

final class CertificateInspectService
    implements
        OperationService<
          CertificateInspectOperationRequest,
          CertificateInspectOutput
        > {
  const CertificateInspectService({
    this.inspector = const CertificateInspector(),
  });

  final CertificateInspector inspector;

  @override
  Future<ChimeraResult<CertificateInspectOutput>> execute(
    CertificateInspectOperationRequest request,
  ) async {
    try {
      final result = switch (request._text) {
        final text? => inspector.inspectText(
          text,
          representation: request.representation,
        ),
        null => inspector.inspectBytes(
          request._bytes!,
          representation: request.representation,
        ),
      };
      return ChimeraSuccess<CertificateInspectOutput>(
        CertificateInspectOutput(result: result),
      );
    } on CertificateInspectionException catch (error) {
      return ChimeraFailure<CertificateInspectOutput>(
        kind: FailureKind.validation,
        code: error.code,
        messageKey: 'error.certificateInspect.validation',
        details: Map<String, Object?>.unmodifiable({
          'field': error.field,
          'reason': error.reason,
        }),
      );
    } on CertificateInspectionResourceException catch (error) {
      return ChimeraFailure<CertificateInspectOutput>(
        kind: FailureKind.resource,
        code: error.code,
        messageKey: 'error.certificateInspect.resource',
        details: Map<String, Object?>.unmodifiable({
          'field': error.field,
          'reason': error.reason,
        }),
      );
    }
  }
}
