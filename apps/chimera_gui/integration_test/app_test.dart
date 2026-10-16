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
}
