import 'package:chimera_gui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GivenApplicationLaunch_WhenRootRouteLoads_ThenShellIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChimeraApp(
        localeTag: 'en',
        currentTime: () => DateTime.utc(2026, 1, 5, 12),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chimera'), findsOneWidget);
    expect(find.text('Developer toolbox'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-cron')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('cron-expression')),
      '0 9 * * MON-FRI',
    );
    await tester.enterText(find.byKey(const Key('cron-time-zone')), 'UTC');
    await tester.enterText(find.byKey(const Key('cron-count')), '1');
    await tester.enterText(
      find.byKey(const Key('cron-reference')),
      '2026-01-05T12:00:00Z',
    );
    await tester.tap(find.byKey(const Key('cron-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Cron schedule: 0 9 * * 1-5'), findsOneWidget);
    expect(
      find.textContaining('Next: 2026-01-06T09:00:00.000+00:00'),
      findsOneWidget,
    );
  });

  testWidgets('GivenDateRoute_WhenConversionRuns_ThenSharedResultIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/date/convert'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('date-value')),
      '2026-01-15T12:30:45Z',
    );
    await tester.enterText(
      find.byKey(const Key('date-target-time-zone')),
      'America/Sao_Paulo',
    );
    await tester.tap(find.byKey(const Key('date-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Converted value: 2026-01-15T09:30:45.000-03:00'),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenNumberBaseRoute_WhenArbitraryPrecisionConversionRuns_ThenSharedResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(
          localeTag: 'en',
          initialLocation: '/number/convert-base',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('number-base-input')),
        '184467440737095516160',
      );
      await tester.tap(find.byKey(const Key('number-base-submit')));
      await tester.pumpAndSettle();

      expect(find.text('a0000000000000000'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextEscapeRoute_WhenUnicodeContentEscapes_ThenSharedResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/escape'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-escape-input')),
        'A"\\\né',
      );
      await tester.tap(find.byKey(const Key('text-escape-submit')));
      await tester.pumpAndSettle();

      expect(find.text(r'A\"\\\né'), findsOneWidget);
    },
  );

  testWidgets(
    'GivenTextUnescapeRoute_WhenUnicodeEscapesDecode_ThenSharedResultIsVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/text/unescape'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('text-unescape-input')),
        r'A\"\\\né\u0021',
      );
      await tester.tap(find.byKey(const Key('text-unescape-submit')));
      await tester.pumpAndSettle();

      expect(find.text('A"\\\né!'), findsOneWidget);
    },
  );

  testWidgets('GivenJsonTableRoute_WhenConversionRuns_ThenTableIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(
        localeTag: 'en',
        initialLocation: '/json/array-to-table',
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-table-input')),
      '[{"name":"Ada","languages":["Dart","C"]}]',
    );
    await tester.tap(find.byKey(const Key('json-table-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('["Dart","C"]'), findsOneWidget);
  });

  testWidgets('GivenJsonCsvRoute_WhenConversionRuns_ThenCsvIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/array-to-csv'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-csv-input')),
      '[{"name":"Ada","languages":["Dart","C"]}]',
    );
    await tester.tap(find.byKey(const Key('json-csv-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('name,languages\r\nAda,"[""Dart"",""C""]"'),
      findsOneWidget,
    );
  });

  testWidgets('GivenJsonYamlRoute_WhenConversionRuns_ThenYamlIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/to-yaml'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-yaml-input')),
      '{"name":"Ada","languages":["Dart","C"]}',
    );
    await tester.tap(find.byKey(const Key('json-yaml-submit')));
    await tester.pumpAndSettle();

    expect(find.text('name: Ada\nlanguages:\n  - Dart\n  - C'), findsOneWidget);
  });

  testWidgets('GivenJsonFormatRoute_WhenFormattingRuns_ThenJsonIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/json/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('json-format-input')),
      '{"name":"Ada","languages":["Dart","C"]}',
    );
    await tester.tap(find.byKey(const Key('json-format-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '{\n'
        '  "name": "Ada",\n'
        '  "languages": [\n'
        '    "Dart",\n'
        '    "C"\n'
        '  ]\n'
        '}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenSqlFormatRoute_WhenFormattingRuns_ThenSqlIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/sql/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('sql-format-input')),
      'select name,language from developers where active=true',
    );
    await tester.tap(find.byKey(const Key('sql-format-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'SELECT\n'
        '  name,\n'
        '  language\n'
        'FROM developers\n'
        'WHERE active = TRUE',
      ),
      findsOneWidget,
    );
  });

  testWidgets('GivenXmlFormatRoute_WhenFormattingRuns_ThenXmlIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ChimeraApp(localeTag: 'en', initialLocation: '/xml/format'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('xml-format-input')),
      '<developers><developer name="Ada"/></developers>',
    );
    await tester.tap(find.byKey(const Key('xml-format-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '<developers>\n'
        '  <developer name="Ada"/>\n'
        '</developers>',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'GivenListCompareRoute_WhenListsCompared_ThenStableSetsAreVisible',
    (tester) async {
      await tester.pumpWidget(
        const ChimeraApp(localeTag: 'en', initialLocation: '/list/compare'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('list-compare-left-input')),
        'alpha\nleft',
      );
      await tester.enterText(
        find.byKey(const Key('list-compare-right-input')),
        'alpha\nright',
      );
      await tester.tap(find.byKey(const Key('list-compare-submit')));
      await tester.pumpAndSettle();

      expect(find.text('left'), findsOneWidget);
      expect(find.text('right'), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('Equal: no'), findsOneWidget);
    },
  );
}
