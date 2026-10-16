import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenValidObjectArray_WhenServiceExecutes_ThenStableOutputIsReturned',
    () async {
      final result = await const JsonTableService().execute(
        const JsonTableOperationRequest(
          source: '[{"name":"Ada"},{"name":"Lin","active":true}]',
          includeRowNumbers: true,
        ),
      );

      expect(result, isA<ChimeraSuccess<JsonTableOutput>>());
      expect(
        (result as ChimeraSuccess<JsonTableOutput>).value.toJson(),
        <String, Object?>{
          'columns': <String>['name', 'active'],
          'rows': <List<String>>[
            <String>['Ada', ''],
            <String>['Lin', 'true'],
          ],
          'includeRowNumbers': true,
          'rowCount': 2,
        },
      );
    },
  );

  test(
    'GivenInvalidMember_WhenServiceExecutes_ThenLocationAwareFailureIsReturned',
    () async {
      final result = await const JsonTableService().execute(
        const JsonTableOperationRequest(
          source: '[{"name":"Ada"},false]',
          includeRowNumbers: false,
        ),
      );

      final failure = result as ChimeraFailure<JsonTableOutput>;
      expect(failure.kind, FailureKind.validation);
      expect(failure.code, 'json-table.not-object');
      expect(failure.messageKey, 'error.jsonTable.validation');
      expect(failure.details, <String, Object?>{'path': r'$[1]'});
    },
  );

  test(
    'GivenMalformedJson_WhenServiceExecutes_ThenOffsetIsReturnedWithoutInput',
    () async {
      final result = await const JsonTableService().execute(
        const JsonTableOperationRequest(
          source: '[{"secret":}]',
          includeRowNumbers: false,
        ),
      );

      final failure = result as ChimeraFailure<JsonTableOutput>;
      expect(failure.details['offset'], isA<int>());
      expect(failure.details.values, isNot(contains('secret')));
    },
  );

  test(
    'GivenCellBudgetExceeded_WhenServiceExecutes_ThenResourceFailureIsReturned',
    () async {
      final result =
          await const JsonTableService(
            converter: JsonTableConverter(maxCells: 1),
          ).execute(
            const JsonTableOperationRequest(
              source: '[{"a":1},{"a":2}]',
              includeRowNumbers: false,
            ),
          );

      final failure = result as ChimeraFailure<JsonTableOutput>;
      expect(failure.kind, FailureKind.resource);
      expect(failure.code, 'json-table.resource-limit');
      expect(failure.messageKey, 'error.jsonTable.resource');
      expect(failure.details, isEmpty);
    },
  );
}
