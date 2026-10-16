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

    await _clickButton(driver, 'Parse a cron expression');
    await _waitUntil(
      () => _pageContains(driver, 'Parse cron expression'),
      'Cron page did not open',
    );

    await _fillTextBox(driver, 'Cron expression', '0 9 * * MON-FRI');
    await _fillTextBox(driver, 'Time zone', 'UTC');
    await _fillTextBox(driver, 'Occurrence count', '1');
    await _fillTextBox(driver, 'Reference instant', '2026-01-05T12:00:00Z');
    await _clickButton(driver, 'Calculate occurrences');

    await _waitUntil(
      () => _pageContains(driver, 'Cron schedule: 0 9 * * 1-5'),
      'Cron result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Next: 2026-01-06T09:00:00.000+00:00'),
      'Cron next occurrence was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'cron');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(() async {
      final flutterRoot = await driver.execute(
        "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
        const <Object?>[],
      );
      return flutterRoot == true;
    }, 'Chimera did not reload for date flow');
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Convert a date'),
      'Home page did not return for date flow',
    );
    await _clickButton(driver, 'Convert a date');
    await _waitUntil(
      () => _pageContains(driver, 'Date value'),
      'Date page did not open',
    );
    await _fillTextBox(driver, 'Date value', '2026-01-15T12:30:45Z');
    await _fillTextBox(driver, 'Target time zone', 'America/Sao_Paulo');
    await _clickButton(driver, 'Convert date');
    await _waitUntil(
      () => _pageContains(
        driver,
        'Converted value: 2026-01-15T09:30:45.000-03:00',
      ),
      'Date result did not render',
    );

    await _assertNoExternalRequests(driver, flow: 'date');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for JSON table flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Convert a JSON array to a table'),
      'Home page did not return for JSON table flow',
    );
    await _clickButton(driver, 'Convert a JSON array to a table');
    await _waitUntil(
      () => _pageContains(driver, 'JSON array'),
      'JSON table page did not open',
    );
    await _fillTextBox(driver, 'JSON array', '[{"name":"Ada","meta":{"x":1}}]');
    await _clickButton(driver, 'Create table');
    await _waitUntil(
      () => _pageContains(driver, 'Ada'),
      'JSON table row did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, '{"x":1}'),
      'Nested JSON table value did not render',
    );
    await _assertNoExternalRequests(driver, flow: 'JSON table');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for JSON CSV flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Convert a JSON array to CSV'),
      'Home page did not return for JSON CSV flow',
    );
    await _clickButton(driver, 'Convert a JSON array to CSV');
    await _waitUntil(
      () => _pageContains(driver, 'Create CSV'),
      'JSON CSV page did not open',
    );
    await _fillTextBox(
      driver,
      'JSON array',
      '[{"name":"Ada","meta":{"x":1}}]',
    );
    await _clickButton(driver, 'Create CSV');
    await _waitUntil(
      () => _pageContains(driver, 'CSV result name,meta'),
      'JSON CSV headers did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Ada,"{""x"":1}"'),
      'JSON CSV row did not render',
    );
    await _assertNoExternalRequests(driver, flow: 'JSON CSV');

    stdout.writeln('Safari cron, date, JSON table, and JSON CSV smoke: OK');
  } finally {
    await driver.quit();
  }
}

Future<void> _assertNoExternalRequests(
  WebDriver driver, {
  required String flow,
}) async {
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
    throw StateError('Safari $flow flow made external requests: $externalUrls');
  }
}

Future<void> _clickButton(WebDriver driver, String text) async {
  await _waitUntil(() async {
    final result = await driver.execute(
      '''
          const expected = arguments[0];
          const button = [...document.querySelectorAll('[role="button"]')]
            .find(element => element.textContent.trim() === expected);
          if (!button) return false;
          button.click();
          return true;
        ''',
      <Object?>[text],
    );
    return result == true;
  }, 'Button did not become available: $text');
}

Future<void> _fillTextBox(WebDriver driver, String label, String value) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    await _waitUntil(() async {
      final result = await driver.execute(
        '''
          const label = arguments[0];
          const input = [...document.querySelectorAll('input[aria-label], textarea[aria-label]')]
            .find(element => element.getAttribute('aria-label') === label);
          if (!input) return false;
          input.focus();
          input.select();
          return document.activeElement === input;
        ''',
        <Object?>[label],
      );
      return result == true;
    }, 'Text box did not become active: $label');

    var entered = '';
    var attemptSucceeded = true;
    for (final character in value.split('')) {
      await driver.keyboard.sendKeys(character);
      entered += character;
      try {
        await _waitUntil(
          () => _inputHasValue(driver, label, entered),
          'Text box did not accept its value: $label',
          timeout: const Duration(seconds: 3),
        );
      } on StateError {
        attemptSucceeded = false;
        break;
      }
    }
    if (attemptSucceeded) {
      await driver.keyboard.sendKeys(Keyboard.tab);
      return;
    }
  }
  throw StateError(
    'Text box did not accept its value after 3 attempts: $label',
  );
}

Future<bool> _inputHasValue(
  WebDriver driver,
  String label,
  String expected,
) async {
  final result = await driver.execute(
    '''
      const label = arguments[0];
      const expected = arguments[1];
      const input = [...document.querySelectorAll('input[aria-label], textarea[aria-label]')]
        .find(element => element.getAttribute('aria-label') === label);
      return input?.value === expected;
    ''',
    <Object?>[label, expected],
  );
  return result == true;
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
  String failureMessage, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('$failureMessage within ${timeout.inSeconds} seconds.');
}
