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
    await _waitUntil(() async {
      final flutterRoot = await driver.execute(
        "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
        const <Object?>[],
      );
      return await driver.title == 'Chimera' && flutterRoot == true;
    }, 'Chimera did not finish loading');

    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') === null;",
            const <Object?>[],
          ) ==
          true,
      'Flutter semantics did not become available',
    );

    await (await _findElement(
      driver,
      '[role="button"]',
      text: 'Parse a cron expression',
    )).click();
    await _waitUntil(
      () => _pageContains(driver, 'Parse cron expression'),
      'Cron page did not open',
    );

    await _fillTextBox(
      driver,
      'input[aria-label="Cron expression"]',
      '0 9 * * MON-FRI',
    );
    await _fillTextBox(driver, 'input[aria-label="Time zone"]', 'UTC');
    await _fillTextBox(driver, 'input[aria-label="Occurrence count"]', '1');
    await _fillTextBox(
      driver,
      'input[aria-label="Reference instant"]',
      '2026-01-05T12:00:00Z',
    );
    await (await _findElement(
      driver,
      '[role="button"]',
      text: 'Calculate occurrences',
    )).click();

    await _waitUntil(
      () => _pageContains(driver, 'Cron schedule: 0 9 * * 1-5'),
      'Cron result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Next: 2026-01-06T09:00:00.000+00:00'),
      'Cron next occurrence was incorrect',
    );

    final resourceUrls = await driver.execute(
      "return performance.getEntriesByType('resource').map(entry => entry.name);",
      const <Object?>[],
    );
    final externalUrls = resourceUrls is List
        ? resourceUrls
              .map((entry) => entry.toString())
              .where((url) => Uri.parse(url).host != '127.0.0.1')
              .toList()
        : <String>[];
    if (externalUrls.isNotEmpty) {
      throw StateError('Safari made external requests: $externalUrls');
    }

    stdout.writeln('Safari cron smoke: OK');
  } finally {
    await driver.quit();
  }
}

Future<WebElement> _findElement(
  WebDriver driver,
  String selector, {
  String? text,
}) async {
  WebElement? element;
  await _waitUntil(
    () async {
      try {
        final candidates = await driver
            .findElements(By.cssSelector(selector))
            .toList();
        for (final candidate in candidates) {
          if (text != null && (await candidate.text).trim() != text) {
            continue;
          }
          if (await candidate.displayed) {
            element = candidate;
            return true;
          }
        }
        return false;
      } on WebDriverException {
        return false;
      }
    },
    'Element did not become available: $selector${text == null ? '' : ' ($text)'}',
  );
  return element!;
}

Future<void> _fillTextBox(
  WebDriver driver,
  String selector,
  String value,
) async {
  final textBox = await _findElement(driver, selector);
  await textBox.click();
  await textBox.clear();
  await textBox.sendKeys(value);
  await _waitUntil(
    () async => await textBox.properties['value'] == value,
    'Text box did not accept its value: $selector',
  );
  await textBox.sendKeys(Keyboard.tab);
}

Future<bool> _pageContains(WebDriver driver, String expected) async {
  final result = await driver.execute(
    '''
      const expected = arguments[0];
      if (document.body.innerText.includes(expected)) return true;
      return [...document.querySelectorAll('[aria-label]')]
        .some(element => element.getAttribute('aria-label').includes(expected));
    ''',
    <Object?>[expected],
  );
  return result == true;
}

Future<void> _waitUntil(
  Future<bool> Function() predicate,
  String failureMessage,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('$failureMessage within 30 seconds.');
}
