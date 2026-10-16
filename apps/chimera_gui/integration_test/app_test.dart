import 'package:chimera_gui/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GivenApplicationLaunch_WhenRootRouteLoads_ThenShellIsVisible', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeraApp(localeTag: 'en'));
    await tester.pumpAndSettle();

    expect(find.text('Chimera'), findsOneWidget);
    expect(find.text('Developer toolbox'), findsOneWidget);
  });
}
