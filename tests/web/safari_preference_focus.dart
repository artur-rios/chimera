import 'package:webdriver/async_io.dart';

typedef SafariSendChord = Future<void> Function(Iterable<String> keys);
typedef SafariFocusOrigin = Future<bool> Function();

final class SafariPreferenceFocusNavigator {
  SafariPreferenceFocusNavigator({
    required this.focusOrigin,
    required this.sendChord,
  });

  final SafariFocusOrigin focusOrigin;
  final SafariSendChord sendChord;
  bool _hasFocusOrigin = false;

  Future<void> advance() async {
    if (!_hasFocusOrigin) {
      _hasFocusOrigin = await focusOrigin();
      if (!_hasFocusOrigin) return;
    }
    for (var step = 0; step < 4; step += 1) {
      await sendChord(<String>[Keyboard.alt, Keyboard.tab]);
    }
  }
}
