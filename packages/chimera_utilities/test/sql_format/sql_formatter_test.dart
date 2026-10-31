import 'package:chimera_utilities/chimera_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('SqlFormatter', () {
    test('GivenPostgreSql_WhenFormatted_ThenClausesAndListsAreStable', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: "select id,name from users where active=true and role='admin' order by name;",
          dialect: SqlDialect.postgresql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(
        result.formatted,
        'SELECT\n'
        '  id,\n'
        '  name\n'
        'FROM users\n'
        'WHERE active = TRUE\n'
        "  AND role = 'admin'\n"
        'ORDER BY name;',
      );
    });

    test('GivenEveryDialect_WhenFormatted_ThenDialectLexemesArePreserved', () {
      final cases = <SqlDialect, String>{
        SqlDialect.postgresql:
            r'select "user", $1::text from accounts where id=$2;',
        SqlDialect.mysql: 'select `user`,? from accounts where id=? limit 1;',
        SqlDialect.sqlServer:
            'select top 1 [user],@id from accounts where id=@id;',
        SqlDialect.sqlite:
            'select `user`,:id from accounts where id=:id limit 1;',
      };

      for (final entry in cases.entries) {
        final result = const SqlFormatter().format(
          SqlFormatRequest(
            source: entry.value,
            dialect: entry.key,
            indent: 2,
            keywordCase: SqlKeywordCase.upper,
          ),
        );

        expect(result.formatted, contains('SELECT'), reason: entry.key.name);
        expect(result.formatted, contains('FROM accounts'));
      }
    });

    test('GivenFourSpaceAndLowerCase_WhenFormatted_ThenOptionsApply', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: 'SELECT a,b FROM t WHERE a=1 OR b=2',
          dialect: SqlDialect.sqlite,
          indent: 4,
          keywordCase: SqlKeywordCase.lower,
        ),
      );

      expect(result.formatted, contains('\n    a,'));
      expect(result.formatted, contains('\n    or b = 2'));
      expect(result.formatted, isNot(contains('SELECT')));
    });

    test('GivenPreserveCase_WhenFormatted_ThenKeywordLexemesRemain', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: 'Select value From sample Where value Is Not Null',
          dialect: SqlDialect.postgresql,
          indent: 2,
          keywordCase: SqlKeywordCase.preserve,
        ),
      );

      expect(result.formatted, startsWith('Select'));
      expect(result.formatted, contains('\nFrom sample'));
      expect(result.formatted, contains('\nWhere value Is Not Null'));
    });

    test(
      'GivenNestedQueryAndComments_WhenFormatted_ThenContentIsPreserved',
      () {
        final result = const SqlFormatter().format(
          const SqlFormatRequest(
            source:
                'select u.id,(select count(*) from posts p where p.user_id=u.id) as total '
                'from users u -- local comment\nwhere u.active=true;',
            dialect: SqlDialect.postgresql,
            indent: 2,
            keywordCase: SqlKeywordCase.upper,
          ),
        );

        expect(result.formatted, contains('count(*)'));
        expect(result.formatted, contains('-- local comment'));
        expect(result.formatted, contains('WHERE u.active = TRUE'));
      },
    );

    test('GivenDollarQuotedString_WhenFormatted_ThenBodyIsUntouched', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: r"select $body$select 'secret';$body$ as script;",
          dialect: SqlDialect.postgresql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(result.formatted, contains(r"$body$select 'secret';$body$"));
    });

    test('GivenSQLiteParameters_WhenFormatted_ThenBindingsStayAdjacent', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: r'select ?1,$name,:value,@other from sample where id=?2;',
          dialect: SqlDialect.sqlite,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(result.formatted, contains(r'?1'));
      expect(result.formatted, contains(r'$name'));
      expect(result.formatted, contains(':value'));
      expect(result.formatted, contains('@other'));
      expect(result.formatted, contains(r'id = ?2'));
    });

    test('GivenPostgreSqlOperators_WhenFormatted_ThenNativeSyntaxIsKept', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: r'''select payload @> '{"a":1}',payload #> '{a}',items[1],payload ? 'a',point <-> center from sample;''',
          dialect: SqlDialect.postgresql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(result.formatted, contains(r'''payload @> '{"a":1}' '''.trim()));
      expect(result.formatted, contains("payload #> '{a}'"));
      expect(result.formatted, contains('items[1]'));
      expect(result.formatted, contains("payload ? 'a'"));
      expect(result.formatted, contains('point <-> center'));
    });

    test('GivenMySqlVariablesAndMinus_WhenFormatted_ThenMeaningIsKept', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: 'select @user,@@session.sql_mode,1--2 from sample -- comment\nwhere id=1;',
          dialect: SqlDialect.mysql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(result.formatted, contains('@user'));
      expect(result.formatted, contains('@@session.sql_mode'));
      expect(result.formatted, contains('1 - - 2'));
      expect(result.formatted, contains('-- comment'));
    });

    test('GivenSqlServerTemporaryTable_WhenFormatted_ThenNameIsKept', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: 'select * from #temp where id=@@identity;',
          dialect: SqlDialect.sqlServer,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(result.formatted, contains('FROM #temp'));
      expect(result.formatted, contains('id = @@identity'));
    });

    test('GivenDialectOperators_WhenFormatted_ThenLexemesStayWhole', () {
      final cases = <SqlDialect, ({String source, String operator})>{
        SqlDialect.postgresql: (
          source: r'select left_value @`? right_value from sample;',
          operator: r'@`?',
        ),
        SqlDialect.mysql: (
          source: 'select left_value <=> right_value from sample;',
          operator: '<=>',
        ),
        SqlDialect.sqlServer: (
          source: 'update sample set value+=1;',
          operator: '+=',
        ),
        SqlDialect.sqlite: (
          source: "select payload ->> 'name' from sample;",
          operator: '->>',
        ),
      };

      for (final entry in cases.entries) {
        final result = const SqlFormatter().format(
          SqlFormatRequest(
            source: entry.value.source,
            dialect: entry.key,
            indent: 2,
            keywordCase: SqlKeywordCase.upper,
          ),
        );

        expect(
          result.formatted,
          contains(' ${entry.value.operator} '),
          reason: entry.key.name,
        );
      }
    });

    test('GivenDialectLiterals_WhenFormatted_ThenPrefixesStayAdjacent', () {
      final cases = <SqlDialect, String>{
        SqlDialect.postgresql: r'''select U&'d\0061t',U&"d\0061t",E'line\\n',B'101',X'FF' from sample;''',
        SqlDialect.mysql: r"select _utf8mb4'name',N'name',X'FF',0xFF,0b101,'a\'b' from sample;",
        SqlDialect.sqlServer:
            "select N'secret',0xFF from [sample] where id=@id;",
        SqlDialect.sqlite: "select X'FF',0xFF from sample;",
      };

      for (final entry in cases.entries) {
        final result = const SqlFormatter().format(
          SqlFormatRequest(
            source: entry.value,
            dialect: entry.key,
            indent: 2,
            keywordCase: SqlKeywordCase.upper,
          ),
        );

        expect(
          result.formatted,
          isNot(contains("N '")),
          reason: entry.key.name,
        );
        expect(
          result.formatted,
          isNot(contains("E '")),
          reason: entry.key.name,
        );
        expect(
          result.formatted,
          isNot(contains("B '")),
          reason: entry.key.name,
        );
        expect(
          result.formatted,
          isNot(contains("X '")),
          reason: entry.key.name,
        );
        if (entry.key != SqlDialect.postgresql) {
          expect(result.formatted, contains('0xFF'), reason: entry.key.name);
        } else {
          expect(result.formatted, contains(r"U&'d\0061t'"));
          expect(result.formatted, contains(r'''U&"d\0061t"'''));
        }
        if (entry.key == SqlDialect.mysql) {
          expect(result.formatted, contains('0b101'));
          expect(result.formatted, contains("_utf8mb4'name'"));
        }
      }
    });

    test('GivenExtendedParameters_WhenFormatted_ThenLexemesStayWhole', () {
      final mysql = const SqlFormatter().format(
        const SqlFormatRequest(
          source: r'''select @'user-name',@`other-name` from sample;''',
          dialect: SqlDialect.mysql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );
      final sqlite = const SqlFormatter().format(
        const SqlFormatRequest(
          source: r'select $name::suffix(detail) from sample;',
          dialect: SqlDialect.sqlite,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(mysql.formatted, contains("@'user-name'"));
      expect(mysql.formatted, contains('@`other-name`'));
      expect(sqlite.formatted, contains(r'$name::suffix(detail)'));
    });

    test('GivenNestedDialectComment_WhenFormatted_ThenCommentIsPreserved', () {
      for (final dialect in <SqlDialect>[
        SqlDialect.postgresql,
        SqlDialect.sqlServer,
      ]) {
        final result = const SqlFormatter().format(
          SqlFormatRequest(
            source: 'select 1 /* outer /* inner */ outer */ from sample;',
            dialect: dialect,
            indent: 2,
            keywordCase: SqlKeywordCase.upper,
          ),
        );

        expect(
          result.formatted,
          contains('/* outer /* inner */ outer */'),
          reason: dialect.name,
        );
      }
    });

    test('GivenInvalidStructure_WhenFormatted_ThenLocationIsReturned', () {
      for (final source in <String>[
        'select where;',
        'select value +;',
        'insert into;',
        'update set value=1;',
      ]) {
        expect(
          () => const SqlFormatter().format(
            SqlFormatRequest(
              source: source,
              dialect: SqlDialect.postgresql,
              indent: 2,
              keywordCase: SqlKeywordCase.upper,
            ),
          ),
          throwsA(
            isA<SqlFormatException>()
                .having((error) => error.code, 'code', 'sql-format.invalid-sql')
                .having((error) => error.offset, 'offset', isNotNull)
                .having((error) => error.reason, 'reason', isNotEmpty),
          ),
          reason: source,
        );
      }
    });

    test('GivenPostgreSqlEmptyTargetList_WhenFormatted_ThenItIsAccepted', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: 'select; select where false; select from sample;',
          dialect: SqlDialect.postgresql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(result.formatted, contains('SELECT;'));
      expect(result.formatted, contains('SELECT\nWHERE FALSE;'));
      expect(result.formatted, endsWith('SELECT\nFROM sample;'));
    });

    test('GivenUnaryAndLeadingDecimal_WhenFormatted_ThenTheyAreAccepted', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: 'select !enabled,.5 from sample;',
          dialect: SqlDialect.mysql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(result.formatted, contains('! enabled'));
      expect(result.formatted, contains('.5'));
    });

    test('GivenCommonDdl_WhenCased_ThenDialectKeywordsAreCased', () {
      final result = const SqlFormatter().format(
        const SqlFormatRequest(
          source: 'create view v as select id from t; create table t(id integer constraint positive check(id>0),name varchar(20)); alter table t add column enabled boolean;',
          dialect: SqlDialect.postgresql,
          indent: 2,
          keywordCase: SqlKeywordCase.upper,
        ),
      );

      expect(result.formatted, contains('CREATE TABLE'));
      expect(result.formatted, contains('CREATE VIEW'));
      expect(result.formatted, contains('INTEGER CONSTRAINT'));
      expect(result.formatted, contains('CHECK'));
      expect(result.formatted, contains('ADD COLUMN'));
    });

    test('GivenInvalidOptions_WhenFormatted_ThenValidationFailureIsThrown', () {
      for (final request in <SqlFormatRequest>[
        const SqlFormatRequest(
          source: 'select 1',
          dialect: SqlDialect.postgresql,
          indent: 3,
          keywordCase: SqlKeywordCase.upper,
        ),
      ]) {
        expect(
          () => const SqlFormatter().format(request),
          throwsA(
            isA<SqlFormatException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  SqlFormatFailureKind.validation,
                )
                .having(
                  (error) => error.code,
                  'code',
                  'sql-format.invalid-indent',
                ),
          ),
        );
      }
    });

    test('GivenMalformedSql_WhenFormatted_ThenSafeLocationIsReturned', () {
      for (final source in <String>[
        "select 'secret",
        'select (1',
        'select items[1 from sample',
        'vacuum secret',
      ]) {
        expect(
          () => const SqlFormatter().format(
            SqlFormatRequest(
              source: source,
              dialect: SqlDialect.postgresql,
              indent: 2,
              keywordCase: SqlKeywordCase.upper,
            ),
          ),
          throwsA(
            isA<SqlFormatException>()
                .having((error) => error.code, 'code', 'sql-format.invalid-sql')
                .having((error) => error.offset, 'offset', isNotNull)
                .having((error) => error.reason, 'reason', isNotEmpty)
                .having(
                  (error) => error.reason,
                  'redacted reason',
                  isNot(contains('secret')),
                ),
          ),
          reason: source,
        );
      }
    });

    test('GivenWrongDialectQuote_WhenFormatted_ThenDialectFailureIsThrown', () {
      expect(
        () => const SqlFormatter().format(
          const SqlFormatRequest(
            source: 'select `value` from sample',
            dialect: SqlDialect.sqlServer,
            indent: 2,
            keywordCase: SqlKeywordCase.upper,
          ),
        ),
        throwsA(
          isA<SqlFormatException>()
              .having((error) => error.code, 'code', 'sql-format.invalid-sql')
              .having(
                (error) => error.reason,
                'reason',
                'unsupported-dialect-syntax',
              ),
        ),
      );
    });

    test(
      'GivenResourceBudgetExceeded_WhenFormatted_ThenNoResultIsReturned',
      () {
        final cases = <SqlFormatter>[
          const SqlFormatter(maxSourceChars: 1),
          const SqlFormatter(maxTokens: 1),
          const SqlFormatter(maxDepth: 0),
          const SqlFormatter(maxOutputChars: 1),
        ];

        for (final formatter in cases) {
          expect(
            () => formatter.format(
              const SqlFormatRequest(
                source: 'select (1) from sample',
                dialect: SqlDialect.postgresql,
                indent: 2,
                keywordCase: SqlKeywordCase.upper,
              ),
            ),
            throwsA(
              isA<SqlFormatException>()
                  .having(
                    (error) => error.kind,
                    'kind',
                    SqlFormatFailureKind.resource,
                  )
                  .having(
                    (error) => error.code,
                    'code',
                    'sql-format.resource-limit',
                  ),
            ),
          );
        }
      },
    );
  });
}
