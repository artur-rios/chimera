import 'package:chimera_core/chimera_core.dart';
import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  test(
    'GivenValidSql_WhenServiceExecutes_ThenStableOutputIsReturned',
    () async {
      final result = await const SqlFormatService().execute(
        const SqlFormatOperationRequest(
          source: 'select id,name from users',
          dialect: SqlDialect.postgresql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      result.fold(
        onSuccess: (value) {
          expect(value.formatted, 'SELECT\n  id,\n  name\nFROM users');
          expect(value.toJson(), <String, Object?>{
            'formatted': 'SELECT\n  id,\n  name\nFROM users',
            'dialect': 'postgresql',
            'indent': 2,
            'keywordCase': 'upper',
          });
        },
        onFailure: (failure) => fail(failure.code),
      );
    },
  );

  test('GivenMalformedSql_WhenServiceExecutes_ThenDetailsAreSafe', () async {
    final result = await const SqlFormatService().execute(
      const SqlFormatOperationRequest(
        source: "select 'secret",
        dialect: SqlDialect.postgresql,
        indent: 2,
        keywordCase: SqlKeywordCase.upper,
      ),
    );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.validation);
        expect(failure.code, 'sql-format.invalid-sql');
        expect(failure.details['offset'], isNotNull);
        expect(failure.details['reason'], 'unterminated-literal');
        expect(failure.details.toString(), isNot(contains('secret')));
      },
    );
  });

  test('GivenTokenBudgetExceeded_WhenServiceExecutes_ThenResourceFailureIsReturned', () async {
    final result =
        await const SqlFormatService(formatter: SqlFormatter(maxTokens: 1))
            .execute(
              const SqlFormatOperationRequest(
                source: 'select value from sample',
                dialect: SqlDialect.sqlite,
                indent: 2,
                keywordCase: SqlKeywordCase.lower,
              ),
            );

    result.fold(
      onSuccess: (_) => fail('Expected failure'),
      onFailure: (failure) {
        expect(failure.kind, FailureKind.resource);
        expect(failure.code, 'sql-format.resource-limit');
      },
    );
  });
}
