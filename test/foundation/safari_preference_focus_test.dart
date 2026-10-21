import 'package:test/test.dart';
import 'package:webdriver/async_io.dart';

import '../../tests/web/safari_preference_focus.dart';

void main() {
  test(
    'GivenSafariPreferences_WhenFocusAdvances_ThenEachTabUsesItsOwnCommand',
    () async {
      final commands = <String>[];

      await advanceSafariPreferenceFocus((keys) async {
        commands.add(keys);
      });

      expect(commands, <String>[
        Keyboard.tab,
        Keyboard.tab,
        Keyboard.tab,
        Keyboard.tab,
      ]);
    },
  );
}
