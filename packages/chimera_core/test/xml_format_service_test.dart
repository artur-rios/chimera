import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenValidXml_WhenServiceExecutes_ThenStableOutputIsReturned',
    () async {
      final result = await const XmlFormatService().execute(
        const XmlFormatOperationRequest(source: '<root><a/></root>', indent: 2),
      );

      result.fold(
        onSuccess: (value) {
          expect(value.formatted, '<root>\n  <a/>\n</root>');
          expect(value.toJson(), <String, Object?>{
            'formatted': '<root>\n  <a/>\n</root>',
            'indent': 2,
          });
        },
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test('GivenMalformedXml_WhenServiceExecutes_ThenDetailsAreSafe', () async {
    final result = await const XmlFormatService().execute(
      const XmlFormatOperationRequest(
        source: '<root>\n<secret></root>',
        indent: 2,
      ),
    );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'xml-format.invalid-xml');
        expect(failure.details['line'], 2);
        expect(failure.details['reason'], 'malformed-xml');
        expect(failure.details.toString(), isNot(contains('secret')));
      },
    );
  });

  test(
    'GivenBudgetExceeded_WhenServiceExecutes_ThenResourceFailureIsReturned',
    () async {
      final result = await const XmlFormatService(
        formatter: XmlFormatter(maxOutputChars: 1),
      ).execute(const XmlFormatOperationRequest(source: '<root/>', indent: 2));

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.resource);
          expect(failure.code, 'xml-format.resource-limit');
        },
      );
    },
  );
}
