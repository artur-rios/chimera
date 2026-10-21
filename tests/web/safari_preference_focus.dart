import 'package:webdriver/async_io.dart';

typedef SafariSendKeys = Future<void> Function(String keys);
typedef SafariFocusOrigin = Future<bool> Function();

final class SafariPreferenceFocusNavigator {
  SafariPreferenceFocusNavigator({
    required this.focusOrigin,
    required this.sendKeys,
  });

  final SafariFocusOrigin focusOrigin;
  final SafariSendKeys sendKeys;
  bool _hasFocusOrigin = false;

  Future<void> advance() async {
    if (!_hasFocusOrigin) {
      _hasFocusOrigin = await focusOrigin();
      if (!_hasFocusOrigin) return;
    }
    for (var step = 0; step < 4; step += 1) {
      await sendKeys(Keyboard.tab);
    }
  }
}
