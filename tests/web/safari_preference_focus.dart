import 'package:webdriver/async_io.dart';

typedef SafariSendKeys = Future<void> Function(String keys);

Future<void> advanceSafariPreferenceFocus(SafariSendKeys sendKeys) async {
  for (var step = 0; step < 4; step += 1) {
    await sendKeys(Keyboard.tab);
  }
}
