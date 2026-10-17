import 'package:chimera_utilities/chimera_utilities.dart';

import 'operation_service.dart';
import 'result.dart';

final class XmlFormatOperationRequest {
  const XmlFormatOperationRequest({required this.source, required this.indent});

  final String source;
  final int indent;
}

final class XmlFormatOutput {
  const XmlFormatOutput(this.result);

  final XmlFormatResult result;

  String get formatted => result.formatted;

  Map<String, Object?> toJson() => <String, Object?>{
    'formatted': result.formatted,
    'indent': result.indent,
  };
}

final class XmlFormatService
    implements OperationService<XmlFormatOperationRequest, XmlFormatOutput> {
  const XmlFormatService({this.formatter = const XmlFormatter()});

  final XmlFormatter formatter;

  @override
  Future<ChimeraResult<XmlFormatOutput>> execute(
    XmlFormatOperationRequest request,
  ) async {
    try {
      return ChimeraSuccess<XmlFormatOutput>(
        XmlFormatOutput(
          formatter.format(
            XmlFormatRequest(source: request.source, indent: request.indent),
          ),
        ),
      );
    } on XmlFormatException catch (error) {
      return ChimeraFailure<XmlFormatOutput>(
        kind: switch (error.kind) {
          XmlFormatFailureKind.validation => FailureKind.validation,
          XmlFormatFailureKind.resource => FailureKind.resource,
        },
        code: error.code,
        messageKey: switch (error.kind) {
          XmlFormatFailureKind.validation => 'error.xmlFormat.validation',
          XmlFormatFailureKind.resource => 'error.xmlFormat.resource',
        },
        details: <String, Object?>{
          'offset': ?error.offset,
          'line': ?error.line,
          'column': ?error.column,
          'reason': ?error.reason,
        },
      );
    }
  }
}
