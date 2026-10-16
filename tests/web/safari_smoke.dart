import 'dart:async';
import 'dart:io';

import 'package:webdriver/async_io.dart';

Future<void> main() async {
  final driver = await createDriver(
    uri: Uri.parse('http://127.0.0.1:4444/'),
    desired: <String, dynamic>{Capabilities.browserName: Browser.safari},
    spec: WebDriverSpec.W3c,
  );

  try {
    await driver.get('http://127.0.0.1:4173');
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    while (DateTime.now().isBefore(deadline)) {
      final title = await driver.title;
      final flutterRoot = await driver.execute(
        "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
        const <Object?>[],
      );
      if (title == 'Chimera' && flutterRoot == true) {
        stdout.writeln('Safari smoke: OK');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    throw StateError(
      'Chimera did not finish loading in Safari within 30 seconds.',
    );
  } finally {
    await driver.quit();
  }
}
