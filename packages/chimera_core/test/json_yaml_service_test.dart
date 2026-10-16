import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenValidJson_WhenYamlServiceExecutes_ThenStableOutputIsReturned',
    () async {
      final result = await const JsonYamlService().execute(
        const JsonYamlOperationRequest(
          source: '{"name":"Ada"}',
          indent: 4,
          quoteStrings: true,
        ),
      );

      final output = (result as ChimeraSuccess<JsonYamlOutput>).value;
      expect(output.yaml, 'name: "Ada"');
      expect(output.toJson(), <String, Object?>{
        'yaml': 'name: "Ada"',
        'indent': 4,
        'quoteStrings': true,
      });
    },
  );

  test(
    'GivenMalformedJson_WhenYamlServiceExecutes_ThenOffsetIsRedacted',
    () async {
      final result = await const JsonYamlService().execute(
        const JsonYamlOperationRequest(
          source: '{"secret":}',
          indent: 2,
          quoteStrings: false,
        ),
      );

      final failure = result as ChimeraFailure<JsonYamlOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, 'json-yaml.invalid-json');
      expect(failure.details['offset'], isA<int>());
      expect(failure.details.values, isNot(contains('secret')));
    },
  );

  test('GivenNodeBudgetExceeded_WhenYamlServiceExecutes_ThenResourceFailureIsReturned', () async {
    final result =
        await const JsonYamlService(converter: JsonYamlConverter(maxNodes: 1))
            .execute(
              const JsonYamlOperationRequest(
                source: '[1,2]',
                indent: 2,
                quoteStrings: false,
              ),
            );

    final failure = result as ChimeraFailure<JsonYamlOutput>;
    expect(failure.kind, FailureKind.resource);
    expect(failure.code, 'json-yaml.resource-limit');
    expect(failure.messageKey, 'error.jsonYaml.resource');
  });
}
