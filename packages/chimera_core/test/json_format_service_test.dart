import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenValidJson_WhenFormatServiceExecutes_ThenStableOutputIsReturned',
    () async {
      final result = await const JsonFormatService().execute(
        const JsonFormatOperationRequest(source: '{"a":1}', indent: 2),
      );

      result.fold(
        onSuccess: (value) {
          expect(value.formatted, '{\n  "a": 1\n}');
          expect(value.toJson(), <String, Object?>{
            'formatted': '{\n  "a": 1\n}',
            'indent': 2,
          });
        },
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test(
    'GivenMalformedJson_WhenFormatServiceExecutes_ThenDetailsAreSafe',
    () async {
      final result = await const JsonFormatService().execute(
        const JsonFormatOperationRequest(source: '{"secret":}', indent: 2),
      );

      result.fold(
        onSuccess: (_) => fail('Expected failure'),
        onFailure: (failure) {
          expect(failure.kind, FailureKind.validation);
          expect(failure.code, 'json-format.invalid-json');
          expect(failure.details['offset'], isNotNull);
          expect(failure.details['reason'], 'unexpected-character');
          expect(failure.details.toString(), isNot(contains('secret')));
        },
      );
    },
  );

  test('GivenOutputBudgetExceeded_WhenFormatServiceExecutes_ThenResourceFailureIsReturned', () async {
    final result = await const JsonFormatService(
      formatter: JsonFormatter(maxOutputChars: 1),
    ).execute(const JsonFormatOperationRequest(source: '{"a":1}', indent: 2));

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.resource);
        expect(failure.code, 'json-format.resource-limit');
      },
    );
  });
}
