import 'package:test/test.dart';
import 'package:webdriver/async_io.dart';

import '../../tests/web/safari_preference_focus.dart';

void main() {
  test(
    'GivenMissingFocusOrigin_WhenTraversalAdvances_ThenTabsWaitForStableFocus',
    () async {
      final events = <String>[];
      var focusAttempt = 0;
      final navigator = SafariPreferenceFocusNavigator(
        focusOrigin: () async {
          events.add('focus');
          focusAttempt += 1;
          return focusAttempt > 1;
        },
        sendChord: (keys) async {
          events.add(keys.join());
        },
      );

      await navigator.advance();
      expect(events, <String>['focus']);

      await navigator.advance();
      expect(events, <String>[
        'focus',
        'focus',
        '${Keyboard.alt}${Keyboard.tab}',
        '${Keyboard.alt}${Keyboard.tab}',
        '${Keyboard.alt}${Keyboard.tab}',
        '${Keyboard.alt}${Keyboard.tab}',
      ]);
    },
  );

  test(
    'GivenStableFocusOrigin_WhenTraversalRepeats_ThenFocusIsNotReset',
    () async {
      var focusCalls = 0;
      final commands = <List<String>>[];
      final navigator = SafariPreferenceFocusNavigator(
        focusOrigin: () async {
          focusCalls += 1;
          return true;
        },
        sendChord: (keys) async {
          commands.add(List<String>.of(keys));
        },
      );

      await navigator.advance();
      await navigator.advance();

      expect(focusCalls, 1);
      expect(
        commands,
        List<List<String>>.generate(
          8,
          (_) => <String>[Keyboard.alt, Keyboard.tab],
        ),
      );
    },
  );
}
