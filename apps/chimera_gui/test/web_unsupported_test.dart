import 'package:chimera_gui/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'GivenUpdateCapabilityDisabled_WhenHomeLoads_ThenUpdateActionIsAbsent',
    (tester) async {
      await tester.pumpWidget(const ChimeraApp(updateChecksEnabled: false));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open-update-check')), findsNothing);
    },
  );
}
