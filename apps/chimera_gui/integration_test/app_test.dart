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
}
