import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:webdriver/async_io.dart';

// Public fixture pinned by tests/fixtures/certificates/manifest.json.
const _certificatePem = '''-----BEGIN CERTIFICATE-----
MIICEjCCAXugAwIBAgICAaswDQYJKoZIhvcNAQELBQAwMDETMBEGA1UEAwwKRXhh
bXBsZSBDQTEZMBcGA1UECgwQQ2hpbWVyYSBmaXh0dXJlczAeFw0yNDAxMDEwMDAw
MDBaFw0zNDAxMDEwMDAwMDBaME4xFTATBgNVBAMMDGV4YW1wbGUudGVzdDEZMBcG
A1UECgwQQ2hpbWVyYSBmaXh0dXJlczEaMBgGAyoDBAwRVW5rbm93biBhdHRyaWJ1
dGUwgZ4wDQYJKoZIhvcNAQEBBQADgYwAMIGIAoGAAIAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAoMCAwEAAaMeMBwwDwYDVR0TAQH/BAUwAwEB/zAJBgMqAwUE
AgUAMA0GCSqGSIb3DQEBCwUAA4GBAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAA
-----END CERTIFICATE-----
''';
// Literal public metadata, independent of the parser and serializer under test.
const _certificateJsonFields =
    '"version":3,"serialNumberHex":"01AB",'
    '"subject":[{"oid":"2.5.4.3","name":"commonName","value":"example.test"},'
    '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"},'
    '{"oid":"1.2.3.4","name":null,"value":"Unknown attribute"}],'
    '"issuer":[{"oid":"2.5.4.3","name":"commonName","value":"Example CA"},'
    '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"}],'
    '"notBefore":"2024-01-01T00:00:00.000Z",'
    '"notAfter":"2034-01-01T00:00:00.000Z",'
    '"signatureAlgorithm":{"oid":"1.2.840.113549.1.1.11",'
    '"name":"sha256WithRSAEncryption"},'
    '"publicKeyAlgorithm":{"oid":"1.2.840.113549.1.1.1","name":"rsaEncryption"},'
    '"extensions":[{"oid":"2.5.29.19","name":"basicConstraints","critical":true},'
    '{"oid":"1.2.3.5","name":null,"critical":false}],';

Future<String> _loadGzipSaveObserver() =>
    File.fromUri(Platform.script.resolve('gzip_save_observer.js'))
        .readAsString();

// These exact helper bodies also run in the compiled Playwright matrix.
const _htmlSetupScript = r'''
  window.__chimeraHtmlCopiedText = null;
  window.__chimeraHtmlCopies = 0;
  window.__chimeraHtmlReads = 0;
  window.__chimeraHtmlClipboardSource = '&<>"\'/ &amp; Olá 🌍';
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: {
      readText: async () => {
        window.__chimeraHtmlReads++;
        return window.__chimeraHtmlClipboardSource;
      },
      writeText: async value => {
        window.__chimeraHtmlCopies++;
        window.__chimeraHtmlCopiedText = value;
      },
    },
  });
  performance.clearResourceTimings();
''';
const _htmlContextOpenScript = r'''
  const normalize = value => value.replace(/\s+/g, ' ').trim();
  const button = [...document.querySelectorAll('[role="button"]')]
    .find(element => normalize(element.getAttribute('aria-label') || element.textContent) === 'HTML context All characters' &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!button) return false;
  button.click();
  return true;
''';
const _htmlContextSelectScript = r'''
  const option = [...document.querySelectorAll('[role="menuitem"]')]
    .find(element => (element.getAttribute('aria-label') || element.textContent).trim() === arguments[0] &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!option) return false;
  option.click();
  return true;
''';
const _htmlResultScript = r'''
  const result = [...document.querySelectorAll('[role="region"][tabindex="0"]')]
    .find(element => element.getAttribute('aria-label') === 'HTML encoded result HTML encoding succeeded.');
  return result !== undefined;
''';
const _htmlCopyScript = r'''
  const button = [...document.querySelectorAll('[role="button"]')]
    .find(element => element.textContent.trim() === 'Copy encoded text' &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!button) return false;
  button.focus();
  return document.activeElement === button;
''';
const _htmlCopiedScript = r'''
  return window.__chimeraHtmlCopies === arguments[1] &&
    window.__chimeraHtmlCopiedText === arguments[0];
''';
const _htmlSaveScript = r'''
  return window.__chimeraSavedName === 'chimera-html-encoded.txt' &&
    window.__chimeraSaveCount === arguments[1] &&
    window.__chimeraSavedMime === 'text/plain; charset=utf-8' &&
    window.__chimeraLiveDownloadUrlCount === 0 &&
    window.__chimeraGzipSaveErrors.length === 0 &&
    JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(arguments[0]);
''';
const _htmlFileScript = r'''
  const picker = document.querySelector('input[type="file"]');
  if (!picker) return false;
  const transfer = new DataTransfer();
  transfer.items.add(new File([new Uint8Array(arguments[0])],
    'source.txt', {type: 'text/plain'}));
  picker.files = transfer.files;
  picker.dispatchEvent(new Event('change', {bubbles: true}));
  return true;
''';
const _htmlNoResultScript = r'''
  const labels = [...document.querySelectorAll('[aria-label]')]
    .map(element => element.getAttribute('aria-label'));
  const buttons = [...document.querySelectorAll('[role="button"]')]
    .map(element => element.textContent.trim());
  return !labels.some(label => label.startsWith('HTML encoded result')) &&
    !buttons.includes('Copy encoded text') && !buttons.includes('Save encoded text');
''';

Future<void> main(List<String> arguments) async {
  // Exercise the same source loader without needing a SafariDriver session.
  if (arguments case ['--verify-gzip-save-observer']) {
    final observer = await _loadGzipSaveObserver();
    if (observer.isEmpty) throw StateError('GZIP save observer is empty');
    stdout.writeln('GZIP save observer source loaded successfully.');
    return;
  }
  if (arguments case ['--verify-html-helpers']) {
    final observer = await _loadGzipSaveObserver();
    final helpers = [
      _htmlSetupScript,
      _htmlContextOpenScript,
      _htmlContextSelectScript,
      _htmlResultScript,
      _htmlCopyScript,
      _htmlCopiedScript,
      _htmlSaveScript,
      _htmlFileScript,
      _htmlNoResultScript,
    ];
    if (!observer.contains('function observeGzipSaves') ||
        helpers.any((source) => source.isEmpty)) {
      throw StateError('HTML helper or save observer source is missing');
    }
    stdout.writeln(
      'HTML helpers (9) and save observer source loaded successfully.',
    );
    return;
  }
  WebDriver? createdDriver;
  try {
    final driver = createdDriver = await createDriver(
      uri: Uri.parse('http://127.0.0.1:4444/'),
      desired: <String, dynamic>{Capabilities.browserName: Browser.safari},
      spec: WebDriverSpec.W3c,
    );
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
      'Chimera did not reload for number base flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Convert a number base'),
      'Home page did not return for number base flow',
    );
    await _clickButton(driver, 'Convert a number base');
    await _waitUntil(
      () => _pageContains(driver, 'Number value'),
      'Number base page did not open',
    );
    await _fillTextBox(driver, 'Number value', '65535');
    await _clickButton(driver, 'Convert number');
    await _waitUntil(
      () => _pageContains(driver, 'Converted value'),
      'Number base result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, 'ffff'),
      'Number base result was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'number base');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for text escape flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Escape text'),
      'Home page did not return for text escape flow',
    );
    await _clickButton(driver, 'Escape text');
    await _waitUntil(
      () => _pageContains(driver, 'Input text'),
      'Text escape page did not open',
    );
    // The built-in bounded sample avoids SafariDriver text synthesis quirks;
    // custom Unicode/control input is covered by native and Playwright flows.
    await _clickButton(driver, 'Escape text');
    await _waitUntil(
      () => _pageContains(driver, 'Escaped text'),
      'Text escape result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, r'Hello, \"Chimera\"!'),
      'Text escape result was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'text escape');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for text unescape flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Unescape text'),
      'Home page did not return for text unescape flow',
    );
    await _clickButton(driver, 'Unescape text');
    await _waitUntil(
      () => _pageContains(driver, 'Escaped input text'),
      'Text unescape page did not open',
    );
    // The built-in bounded sample avoids SafariDriver text synthesis quirks;
    // custom Unicode/control input is covered by native and Playwright flows.
    await _clickButton(driver, 'Unescape text');
    await _waitUntil(
      () => _pageContains(driver, 'Unescaped text'),
      'Text unescape result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Hello, "Chimera"!'),
      'Text unescape result was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'text unescape');

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
    await _fillTextBox(driver, 'JSON array', '[{"name":"Ada","meta":{"x":1}}]');
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

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for JSON YAML flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Convert JSON to YAML'),
      'Home page did not return for JSON YAML flow',
    );
    await _clickButton(driver, 'Convert JSON to YAML');
    await _waitUntil(
      () => _pageContains(driver, 'Create YAML'),
      'JSON YAML page did not open',
    );
    await _fillTextBox(driver, 'JSON value', '{"name":"Ada","meta":{"x":1}}');
    await _clickButton(driver, 'Create YAML');
    await _waitUntil(
      () => _pageContains(driver, 'YAML result name: Ada'),
      'JSON YAML result did not render',
    );
    await _assertNoExternalRequests(driver, flow: 'JSON YAML');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for JSON format flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Format JSON'),
      'Home page did not return for JSON format flow',
    );
    await _clickButton(driver, 'Format JSON');
    await _waitUntil(
      () => _pageContains(driver, 'Paste JSON'),
      'JSON format page did not open',
    );
    await _fillTextBox(driver, 'JSON value', '{"name":"Ada","meta":{"x":1}}');
    await _clickButton(driver, 'Format JSON');
    await _waitUntil(
      () => _pageContains(driver, 'Formatted JSON result'),
      'Formatted JSON result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, '"name": "Ada"'),
      'Formatted JSON content was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'JSON format');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for SQL format flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Format SQL'),
      'Home page did not return for SQL format flow',
    );
    await _clickButton(driver, 'Format SQL');
    await _waitUntil(
      () => _pageContains(driver, 'SQL statement'),
      'SQL format page did not open',
    );
    await _fillTextBox(
      driver,
      'SQL statement',
      'select id,name from users where active=true',
    );
    await _clickButton(driver, 'Format SQL');
    await _waitUntil(
      () => _pageContains(driver, 'Formatted SQL result'),
      'Formatted SQL result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, 'WHERE active = TRUE'),
      'Formatted SQL content was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'SQL format');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for XML format flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Format XML'),
      'Home page did not return for XML format flow',
    );
    await _clickButton(driver, 'Format XML');
    await _waitUntil(
      () => _pageContains(driver, 'XML document'),
      'XML format page did not open',
    );
    // SafariDriver cannot reliably synthesize "<" into Flutter's semantics
    // proxy. Exercise the formatter with the page's built-in valid sample;
    // custom XML editing is covered by the cross-browser and widget suites.
    await _clickButton(driver, 'Format XML');
    await _waitUntil(
      () => _pageContains(driver, 'Formatted XML result'),
      'Formatted XML result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, '<root/>'),
      'Formatted XML content was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'XML format');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for list comparison flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Compare lists'),
      'Home page did not return for list comparison flow',
    );
    await _clickButton(driver, 'Compare lists');
    await _waitUntil(
      () => _pageContains(driver, 'Left list'),
      'List comparison page did not open',
    );
    await _fillTextBox(driver, 'Left list', 'alpha');
    await _fillTextBox(driver, 'Right list', 'alpha');
    await _clickButton(driver, 'Compare lists');
    await _waitUntil(
      () => _pageContains(driver, 'Intersection Items: 1 alpha'),
      'List comparison intersection was incorrect',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Equal: yes'),
      'List comparison equality was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'list comparison');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for text analysis flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Analyze text'),
      'Home page did not return for text analysis flow',
    );
    await _clickButton(driver, 'Analyze text');
    await _waitUntil(
      () => _pageContains(driver, 'Text to analyze'),
      'Text analysis page did not open',
    );
    await _fillTextBox(driver, 'Text to analyze', 'A\nB');
    await _clickButton(driver, 'Analyze text');
    await _waitUntil(
      () => _pageContains(
        driver,
        'Analyze text Characters: 3 Words: 2 Lines: 2 UTF-8 bytes: 3',
      ),
      'Text analysis counts were incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'text analysis');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for text transformation flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Transform text'),
      'Home page did not return for text transformation flow',
    );
    await _clickButton(driver, 'Transform text');
    await _waitUntil(
      () => _pageContains(driver, 'Input text'),
      'Text transformation page did not open',
    );
    await _fillTextBox(driver, 'Input text', 'ÉCOLE');
    await _clickButton(driver, 'Transform text');
    await _waitUntil(
      () => _pageContains(driver, 'Transformed text école'),
      'Text transformation result was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'text transformation');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for text comparison flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Compare text'),
      'Home page did not return for text comparison flow',
    );
    await _clickButton(driver, 'Compare text');
    await _waitUntil(
      () => _pageContains(driver, 'Left text'),
      'Text comparison page did not open',
    );
    // Use the built-in bounded line sample to avoid SafariDriver multiline
    // synthesis differences; edited inputs are covered by native and Playwright.
    await _clickButton(driver, 'Compare text');
    await _waitUntil(
      () => _pageContains(driver, 'Text comparison result'),
      'Text comparison result did not render',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Added: 1 Removed: 1 Unchanged: 1'),
      'Text comparison summary was incorrect',
    );
    await _assertNoExternalRequests(driver, flow: 'text comparison');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for Base64 encoding flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Encode Base64'),
      'Home page did not return for Base64 encoding flow',
    );
    await _clickButton(driver, 'Encode Base64');
    await _waitUntil(
      () => _pageContains(driver, 'Text to encode'),
      'Base64 encoding page did not open',
    );
    await driver.execute('''
        window.__chimeraCopiedText = null;
        Object.defineProperty(navigator, 'clipboard', {
          configurable: true,
          value: {
            writeText: async value => {
              window.__chimeraCopiedText = value;
            },
          },
        });
        window.__chimeraOriginalFileInputClick = HTMLInputElement.prototype.click;
        HTMLInputElement.prototype.click = function() {
          if (this.type === 'file') {
            window.__chimeraFileInput = this;
            return;
          }
          return window.__chimeraOriginalFileInputClick.call(this);
        };
      ''', const <Object?>[]);
    await driver.execute(
      'performance.clearResourceTimings();',
      const <Object?>[],
    );
    await _clickButton(driver, 'Load bytes from file');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('input[type=\"file\"]') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Base64 file input did not become available',
    );
    final binaryFileDispatched = await driver.execute('''
        const input = document.querySelector('input[type="file"]');
        if (input === null) return false;
        const bytes = new Uint8Array([0x00, 0xff]);
        const transfer = new DataTransfer();
        transfer.items.add(
          new File([bytes], 'bytes.bin', {type: 'application/octet-stream'}),
        );
        input.files = transfer.files;
        input.dispatchEvent(new Event('change', {bubbles: true}));
        return input.files.length === 1 && input.files[0].size === 2;
      ''', const <Object?>[]);
    if (binaryFileDispatched != true) {
      throw StateError('Base64 binary file could not be dispatched');
    }
    await _waitUntil(
      () => _pageContains(driver, 'Input bytes: 2'),
      'Base64 binary fixture was not loaded',
    );
    await _clickButton(driver, 'Encode');
    await _waitUntil(
      () => _pageContains(
        driver,
        'Base64 encoding succeeded. Input bytes: 2 Output characters: 4',
      ),
      'Base64 binary result summary was incorrect',
    );
    await _clickButton(driver, 'Copy Base64');
    await _waitUntil(
      () async =>
          await driver.execute(
            'return window.__chimeraCopiedText === "AP8=";',
            const <Object?>[],
          ) ==
          true,
      'Base64 binary result copy was not exact',
    );
    await _assertNoResourceRequests(driver, flow: 'Base64 interaction');
    await _assertNoExternalRequests(driver, flow: 'Base64 encoding');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Chimera did not reload for Base64 decoding flow',
    );
    await driver.execute(
      "document.querySelector('flt-semantics-placeholder')?.click();",
      const <Object?>[],
    );
    await _waitUntil(
      () => _pageContains(driver, 'Decode Base64'),
      'Home page did not return for Base64 decoding flow',
    );
    await _clickButton(driver, 'Decode Base64');
    await _waitUntil(
      () => _pageContains(driver, 'Base64 to decode'),
      'Base64 decoding page did not open',
    );
    await driver.execute('''
        window.__chimeraSavedName = null;
        window.__chimeraSavedBytes = null;
        window.__chimeraOriginalCreateObjectURL = URL.createObjectURL.bind(URL);
        URL.createObjectURL = function(blob) {
          blob.arrayBuffer().then(buffer => {
            window.__chimeraSavedBytes = [...new Uint8Array(buffer)];
          });
          return window.__chimeraOriginalCreateObjectURL(blob);
        };
        window.__chimeraOriginalAnchorClick = HTMLAnchorElement.prototype.click;
        HTMLAnchorElement.prototype.click = function() {
          window.__chimeraSavedName = this.download;
        };
        window.__chimeraOriginalDecodeFileInputClick = HTMLInputElement.prototype.click;
        HTMLInputElement.prototype.click = function() {
          if (this.type === 'file') {
            window.__chimeraDecodeFileInput = this;
            return;
          }
          return window.__chimeraOriginalDecodeFileInputClick.call(this);
        };
      ''', const <Object?>[]);
    await driver.execute(
      'performance.clearResourceTimings();',
      const <Object?>[],
    );
    await _clickButton(driver, 'Load Base64 from file');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('input[type=\"file\"]') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Base64 decode file input did not become available',
    );
    final decodeFileDispatched = await driver.execute('''
        const input = document.querySelector('input[type="file"]');
        if (input === null) return false;
        const source = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
        const transfer = new DataTransfer();
        transfer.items.add(
          new File(
            [new TextEncoder().encode(source)],
            'pixel.b64',
            {type: 'text/plain'},
          ),
        );
        input.files = transfer.files;
        input.dispatchEvent(new Event('change', {bubbles: true}));
        return input.files.length === 1 && input.files[0].size === source.length;
      ''', const <Object?>[]);
    if (decodeFileDispatched != true) {
      throw StateError('Base64 decode file could not be dispatched');
    }
    await _waitUntil(
      () => _pageContains(driver, 'Input characters: 92'),
      'Base64 PNG source fixture was not loaded',
    );
    await _clickCheckbox(driver, 'Binary');
    await _clickButton(driver, 'Decode');
    await _waitUntil(
      () => _pageContains(
        driver,
        'Base64 decoding succeeded. Output mode: Binary Input characters: 92 Output bytes: 68 Image preview available.',
      ),
      'Base64 PNG preview did not render',
    );
    await _clickButton(driver, 'Save decoded bytes');
    await _waitUntil(
      () async =>
          await driver.execute('''
              const expected = '89504e470d0a1a0a0000000d4948445200000001000000010804000000b51c0c020000000b4944415478da6364f80f00010501012718e3660000000049454e44ae426082';
              const actual = window.__chimeraSavedBytes;
              return window.__chimeraSavedName === 'chimera-decoded.png' &&
                Array.isArray(actual) &&
                actual.map(value => value.toString(16).padStart(2, '0')).join('') === expected;
            ''', const <Object?>[]) ==
          true,
      'Base64 PNG save was not byte-exact',
    );
    await _assertNoNetworkRequests(driver, flow: 'Base64 decoding interaction');

    for (final representation in ['pem', 'der', 'base64']) {
      await driver.get('http://127.0.0.1:4173');
      await _waitUntil(
        () async =>
            await driver.execute(
              "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
              const <Object?>[],
            ) ==
            true,
        'Chimera did not reload for certificate $representation flow',
      );
      await driver.execute(
        "document.querySelector('flt-semantics-placeholder')?.click();",
        const <Object?>[],
      );
      await _clickButton(driver, 'Inspect a certificate');
      await _waitUntil(
        () => _pageContains(driver, 'Certificate (PEM or Base64)'),
        'Certificate page did not open',
      );
      final base64Text = _certificatePem
          .split('\n')
          .where((line) => !line.startsWith('-----') && line.isNotEmpty)
          .join();
      final source = representation == 'pem'
          ? _certificatePem
          : '$base64Text\n';
      await driver.execute(
        '''
        window.__chimeraCopiedText = null;
        const source = arguments[0];
        Object.defineProperty(navigator, 'clipboard', {
          configurable: true,
          value: {
            readText: async () => source,
            writeText: async value => { window.__chimeraCopiedText = value; },
          },
        });
        const originalClick = HTMLInputElement.prototype.click;
        HTMLInputElement.prototype.click = function() {
          if (this.type === 'file') return;
          return originalClick.call(this);
        };
        performance.clearResourceTimings();
      ''',
        <Object?>[source],
      );
      if (representation == 'der') {
        // SafariDriver does not support direct file upload. Exercise the real
        // picker change/read path with a File built in this browser context.
        await _clickButton(driver, 'Load certificate file');
        await _waitUntil(
          () async =>
              await driver.execute(
                """return document.querySelector('input[type="file"]') !== null;""",
                const <Object?>[],
              ) ==
              true,
          'Certificate file input did not become available',
        );
        final dispatched = await driver.execute(
          '''
          const input = document.querySelector('input[type="file"]');
          if (!input) return false;
          const bytes = Uint8Array.from(atob(arguments[0]), c => c.charCodeAt(0));
          const transfer = new DataTransfer();
          transfer.items.add(new File([bytes], 'certificate.der',
            {type: 'application/octet-stream'}));
          input.files = transfer.files;
          input.dispatchEvent(new Event('change', {bubbles: true}));
          return input.files.length === 1 && input.files[0].size === 534;
        ''',
          <Object?>[base64Text],
        );
        if (dispatched != true) {
          throw StateError('Certificate DER file could not be dispatched');
        }
        await _waitUntil(
          () => _pageContains(driver, 'Input bytes: 534'),
          'Certificate DER fixture was not loaded',
        );
        await _clickCheckbox(driver, 'DER');
      } else {
        await _clickButton(driver, 'Paste certificate');
        await _waitUntil(
          () async =>
              await driver.execute(
                '''
                const input = [...document.querySelectorAll('textarea[aria-label]')]
                  .find(element => element.getAttribute('aria-label') === arguments[0]);
                if (!input || input.disabled) return false;
                input.focus();
                return input.value === arguments[1];
              ''',
                <Object?>['Certificate (PEM or Base64)', source],
              ) ==
              true,
          'Certificate clipboard source was not loaded exactly',
        );
        if (representation == 'base64') {
          await _clickCheckbox(driver, 'Base64');
        }
      }
      await _clickButton(driver, 'Inspect');
      final label = representation == 'base64'
          ? 'Base64'
          : representation.toUpperCase();
      await _waitUntil(
        () => _pageContains(
          driver,
          'Certificate metadata Certificate inspection succeeded. '
          'Representation: $label Subject attributes: 3 Issuer attributes: 2 Extensions: 2',
        ),
        'Certificate $representation metadata summary was incorrect',
      );
      await _clickButton(driver, 'Copy certificate JSON');
      final count = representation == 'pem'
          ? 778
          : representation == 'der'
          ? 534
          : 713;
      final expected =
          '{"representation":"$representation",'
          '$_certificateJsonFields'
          '"inputByteCount":$count,"derByteCount":534}';
      await _waitUntil(
        () async =>
            await driver.execute(
              'return window.__chimeraCopiedText === arguments[0];',
              <Object?>[expected],
            ) ==
            true,
        'Certificate $representation copied JSON was not exact',
      );
      await _waitUntil(
        () => _pageContains(driver, 'Certificate JSON copied.'),
        'Certificate copy did not complete',
      );
      await _assertNoNetworkRequests(
        driver,
        flow: 'certificate $representation interaction',
      );
    }

    for (final source in ['pem', 'der']) {
      await _convertCertificate(driver, source);
    }

    for (final source in ['text', 'binary']) {
      await _compressGzip(driver, source);
    }

    await _decompressGzip(driver);
    await _encodeHtml(driver);

    stdout.writeln(
      'Safari cron, date, number base, text escape, text unescape, list comparison, text analysis, text transformation, text comparison, Base64 encoding, Base64 decoding, certificate PEM/DER/Base64 inspection, certificate PEM-to-DER and DER-to-PEM conversion/save, GZIP text/binary compression/save and BOM text decompression/copy/save, HTML context encoding/copy/save/validation, JSON table, JSON CSV, JSON YAML, JSON format, SQL format, and XML format smoke: OK',
    );
  } finally {
    await createdDriver?.quit();
  }
}

Future<void> _encodeHtml(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'HTML semantics placeholder did not load',
  );
  await driver.execute(
    "document.querySelector('flt-semantics-placeholder').click();",
    const <Object?>[],
  );
  await _clickButton(driver, 'Encode HTML');
  await _waitUntil(
    () => _pageContains(driver, 'Text to encode'),
    'HTML page did not open',
  );
  await _assertNoExternalRequests(driver, flow: 'HTML startup');
  final observer = await _loadGzipSaveObserver();
  await driver.execute(
    '$observer\nobserveGzipSaves({suppressDownloads: true});',
    const <Object?>[],
  );
  await driver.execute(_htmlSetupScript, const <Object?>[]);
  // SafariDriver has no upload endpoint; use its existing real File dispatch.
  await driver.execute('''
    const click = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function() {
      if (this.type === 'file') return;
      return click.call(this);
    };
  ''', const <Object?>[]);
  const expected = '&amp;&lt;&gt;&quot;\'/ &amp;amp; Olá 🌍';
  await _clickButton(driver, 'Paste text');
  await _waitUntil(
    () => _inputHasValue(
      driver,
      'Text to encode',
      '&<>"\'/ &amp; Olá 🌍',
      focus: true,
    ),
    'HTML clipboard source was not loaded',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlContextOpenScript, const <Object?>[]) == true,
    'HTML default context was unavailable',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlContextSelectScript, const <Object?>[
          'Double-quoted attribute',
        ]) ==
        true,
    'HTML double-quoted context was unavailable',
  );
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlResultScript, const <Object?>[]) == true,
    'HTML result semantics were incorrect',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Text to encode', '', focus: true),
    'HTML source was retained',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlCopyScript, const <Object?>[]) == true,
    'HTML copy was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_htmlCopiedScript, const <Object?>[expected, 1]) ==
        true,
    'HTML clipboard output was not exact',
  );
  await _clickButton(driver, 'Save encoded text');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlSaveScript, <Object?>[
          utf8.encode(expected),
          1,
        ]) ==
        true,
    'HTML non-empty save/URL cleanup was not exact',
  );
  await _waitUntil(
    () => _pageContains(driver, 'HTML encoded text saved.'),
    'HTML non-empty save did not finish',
  );
  // A second encode has no retained source: it must copy/save exactly zero bytes.
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlResultScript, const <Object?>[]) == true,
    'HTML empty result did not appear',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlCopyScript, const <Object?>[]) == true,
    'HTML empty copy was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_htmlCopiedScript, const <Object?>['', 2]) == true,
    'HTML empty copy was not exact',
  );
  await _clickButton(driver, 'Save encoded text');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlSaveScript, const <Object?>[<int>[], 2]) ==
        true,
    'HTML empty save/URL cleanup was not exact',
  );
  await _waitUntil(
    () => _pageContains(driver, 'HTML encoded text saved.'),
    'HTML empty save did not finish',
  );
  await _clickButton(driver, 'Load UTF-8 file');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlFileScript, const <Object?>[
          <int>[0xc3, 0x28],
        ]) ==
        true,
    'HTML malformed UTF-8 fixture could not be dispatched',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlNoResultScript, const <Object?>[]) == true,
    'HTML file load did not discard the previous result',
  );
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () => _pageContains(driver, 'The HTML encoding request is invalid.'),
    'HTML UTF-8 validation did not appear',
  );
  if (await driver.execute(_htmlNoResultScript, const <Object?>[]) != true) {
    throw StateError('HTML validation retained an output action or result');
  }
  await _waitUntil(
    () => _inputHasValue(driver, 'Text to encode', '', focus: true),
    'HTML validation retained source text',
  );
  final reads = await driver.execute(
    'return window.__chimeraHtmlReads;',
    const <Object?>[],
  );
  if (reads != 1) throw StateError('HTML clipboard source was not read once');
  await _assertNoNetworkRequests(
    driver,
    flow: 'HTML context/copy/save/validation',
  );
}

Future<void> _compressGzip(WebDriver driver, String source) async {
  final input = source == 'text' ? utf8.encode('Olá 🌍') : [0, 255, 128, 1];
  final level = source == 'text' ? 0 : 9;
  final expectedHex = source == 'text'
      ? '1f8b08000000000000ff010900f6ff4f6cc3a120f09f8c8d65c404fa09000000'
      : '1f8b08000000000000ff63f8dfc008002c4358d304000000';
  final outputCount = source == 'text' ? 32 : 24;
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'GZIP semantics placeholder did not load',
  );
  await driver.execute(
    "document.querySelector('flt-semantics-placeholder').click();",
    const <Object?>[],
  );
  await _clickButton(driver, 'Compress to GZIP');
  await _waitUntil(
    () => _pageContains(driver, 'Text to compress'),
    'GZIP page did not open',
  );
  await _assertNoExternalRequests(driver, flow: 'GZIP startup');
  // Resolve beside this script, independent of the CI working directory.
  // Playwright's boundary probes execute this same test-only source unchanged.
  final saveObserver = await _loadGzipSaveObserver();
  await driver.execute(
    '$saveObserver\nobserveGzipSaves({suppressDownloads: true});',
    const <Object?>[],
  );
  await driver.execute('''
    window.__chimeraGzipClipboardReads = 0;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {readText: async () => {
        window.__chimeraGzipClipboardReads++;
        return 'Olá 🌍';
      }},
    });
    const originalInputClick = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function() {
      if (this.type === 'file') return;
      return originalInputClick.call(this);
    };
    performance.clearResourceTimings();
  ''', const <Object?>[]);
  if (source == 'text') {
    await _clickButton(driver, 'Paste text');
    await _waitUntil(
      // Paste recreates the editor to discard undo history. Flutter attaches
      // its DOM editing value only after activating that new field's focus.
      () => _inputHasValue(driver, 'Text to compress', 'Olá 🌍', focus: true),
      'GZIP UTF-8 clipboard source was not loaded',
    );
    final reads = await driver.execute(
      'return window.__chimeraGzipClipboardReads;',
      const <Object?>[],
    );
    if (reads != 1) {
      throw StateError('GZIP clipboard was not read exactly once');
    }
  } else {
    await _clickButton(driver, 'Load file bytes');
    // SafariDriver lacks direct upload; dispatch a real File through the picker.
    await _waitUntil(
      () async =>
          await driver.execute('''
      const picker = document.querySelector('input[type="file"]');
      if (!picker) return false;
      const transfer = new DataTransfer();
      transfer.items.add(new File([new Uint8Array([0, 255, 128, 1])],
        'source.bin', {type: 'application/octet-stream'}));
      picker.files = transfer.files;
      picker.dispatchEvent(new Event('change', {bubbles: true}));
      return true;
    ''', const <Object?>[]) ==
          true,
      'GZIP binary fixture could not be dispatched',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Input bytes: 4'),
      'GZIP binary source was not loaded',
    );
    if (!await _inputHasValue(driver, 'Text to compress', '')) {
      throw StateError('GZIP file source retained text');
    }
  }
  await _waitUntil(
    () async =>
        await driver.execute(r'''
    const normalize = value => value.replace(/\s+/g, ' ').trim();
    const selector = [...document.querySelectorAll('[role="button"]')]
      .find(element => normalize(element.getAttribute('aria-label') || element.textContent) === 'Compression level 6');
    if (!selector) return false;
    selector.click();
    return true;
  ''', const <Object?>[]) ==
        true,
    'GZIP compression level selector was unavailable',
  );
  await _waitUntil(
    () async =>
        await driver.execute(
          '''
    const option = [...document.querySelectorAll('[role="menuitem"]')]
      .find(element => (element.getAttribute('aria-label') || element.textContent).trim() === arguments[0] &&
        element.getAttribute('aria-disabled') !== 'true');
    if (!option) return false;
    option.click();
    return true;
  ''',
          <Object?>['$level'],
        ) ==
        true,
    'GZIP explicit level could not be selected',
  );
  await _clickButton(driver, 'Compress');
  final summary =
      'Compressed binary result Compression succeeded. '
      'Compression level: $level Input bytes: ${input.length} Output bytes: $outputCount';
  await _waitUntil(
    () async =>
        await driver.execute(
          r'''
    const normalize = value => value.replace(/\s+/g, ' ').trim();
    return [...document.querySelectorAll('[role="region"][tabindex="0"]')]
      .some(element => normalize(element.getAttribute('aria-label') || '') === arguments[0]);
  ''',
          <Object?>[summary],
        ) ==
        true,
    'GZIP success semantics/counts were incorrect',
  );
  await _clickButton(driver, 'Save GZIP file');
  await _waitUntil(
    () async =>
        await driver.execute('''
    return window.__chimeraSavedName === 'chimera-compressed.gz' &&
      window.__chimeraSaveCount === 1 &&
      window.__chimeraSavedMime === 'application/gzip' &&
      window.__chimeraGzipSaveErrors.length === 0 &&
      Array.isArray(window.__chimeraSavedBytes);
  ''', const <Object?>[]) ==
        true,
    'GZIP exact save boundary did not complete',
  );
  final raw = await driver.execute(
    'return window.__chimeraSavedBytes;',
    const <Object?>[],
  );
  if (raw is! List) throw StateError('GZIP save returned no byte list');
  final actual = raw.cast<num>().map((value) => value.toInt()).toList();
  if (actual.map((value) => value.toRadixString(16).padLeft(2, '0')).join() !=
          expectedHex ||
      base64.encode(gzip.decode(actual)) != base64.encode(input)) {
    throw StateError(
      'GZIP saved bytes or independent platform decompression differed',
    );
  }
  await _assertNoNetworkRequests(driver, flow: 'GZIP $source compression/save');
}

Future<void> _decompressGzip(WebDriver driver) async {
  const archive = <int>[
    31,
    139,
    8,
    0,
    0,
    0,
    0,
    0,
    2,
    255,
    123,
    191,
    123,
    127,
    34,
    47,
    151,
    2,
    0,
    132,
    190,
    221,
    192,
    7,
    0,
    0,
    0,
  ];
  const expected = <int>[239, 187, 191, 97, 13, 10, 32];
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'GZIP decompression semantics placeholder did not load',
  );
  await driver.execute(
    "document.querySelector('flt-semantics-placeholder').click();",
    const <Object?>[],
  );
  await _clickButton(driver, 'Decompress GZIP');
  await _waitUntil(
    () => _pageContains(driver, 'Load GZIP file'),
    'GZIP decompression page did not open',
  );
  await _assertNoExternalRequests(driver, flow: 'GZIP decompression startup');
  final saveObserver = await _loadGzipSaveObserver();
  await driver.execute(
    '$saveObserver\nobserveGzipSaves({suppressDownloads: true});',
    const <Object?>[],
  );
  await driver.execute('''
    window.__chimeraCopiedText = null;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {writeText: async value => { window.__chimeraCopiedText = value; }},
    });
    const originalInputClick = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function() {
      if (this.type === 'file') return;
      return originalInputClick.call(this);
    };
    performance.clearResourceTimings();
  ''', const <Object?>[]);
  await _clickButton(driver, 'Load GZIP file');
  await _waitUntil(
    () async =>
        await driver.execute(
          '''
      const picker = document.querySelector('input[type="file"]');
      if (!picker) return false;
      const transfer = new DataTransfer();
      transfer.items.add(new File([new Uint8Array(arguments[0])],
        'extension-independent.data', {type: 'application/octet-stream'}));
      picker.files = transfer.files;
      picker.dispatchEvent(new Event('change', {bubbles: true}));
      return true;
    ''',
          const <Object?>[archive],
        ) ==
        true,
    'GZIP decompression fixture could not be dispatched',
  );
  await _waitUntil(
    () => _pageContains(driver, 'Input bytes: 27'),
    'GZIP decompression input count was incorrect',
  );
  await _clickButton(driver, 'Decompress');
  const summary =
      'Decompressed result Decompression succeeded. '
      'Input bytes: 27 Output bytes: 7';
  await _waitUntil(
    () async =>
        await driver.execute(
          r'''
    const normalize = value => value.replace(/\s+/g, ' ').trim();
    return [...document.querySelectorAll('[role="region"][tabindex="0"]')]
      .some(element => normalize(element.getAttribute('aria-label') || '') === arguments[0]);
  ''',
          const <Object?>[summary],
        ) ==
        true,
    'GZIP decompression success semantics/counts were incorrect',
  );
  await _activateGzipCopyButton(driver);
  const expectedCopyCodeUnits = <int>[0xfeff, 0x61, 0x0d, 0x0a, 0x20];
  await _waitUntil(() async {
    final actual = await _copiedTextCodeUnits(driver);
    return actual != null &&
        actual.length == expectedCopyCodeUnits.length &&
        actual.indexed.every(
          (entry) => entry.$2 == expectedCopyCodeUnits[entry.$1],
        );
  }, 'GZIP BOM text was not copied exactly');
  await _clickButton(driver, 'Save decompressed bytes');
  await _waitUntil(
    () async =>
        await driver.execute(
          '''
    return window.__chimeraSavedName === 'chimera-decompressed.txt' &&
      window.__chimeraSaveCount === 1 &&
      window.__chimeraSavedMime === 'text/plain; charset=utf-8' &&
      window.__chimeraLiveDownloadUrlCount === 0 &&
      window.__chimeraGzipSaveErrors.length === 0 &&
      JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(arguments[0]);
  ''',
          const <Object?>[expected],
        ) ==
        true,
    'GZIP decompression exact save or URL cleanup did not complete',
  );
  await _waitUntil(
    () => _pageContains(driver, 'Decompressed bytes saved.'),
    'GZIP decompression save notice did not complete',
  );
  await _assertNoNetworkRequests(
    driver,
    flow: 'GZIP BOM text decompression/copy/save',
  );
}

Future<void> _convertCertificate(WebDriver driver, String source) async {
  final target = source == 'pem' ? 'der' : 'pem';
  final pem = await File.fromUri(
    Platform.script.resolve('../fixtures/certificates/certificate.pem'),
  ).readAsBytes();
  final der = await File.fromUri(
    Platform.script.resolve('../fixtures/certificates/certificate.der'),
  ).readAsBytes();
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
          const <Object?>[],
        ) ==
        true,
    'Chimera did not reload for certificate $source conversion',
  );
  await driver.execute(
    "document.querySelector('flt-semantics-placeholder')?.click();",
    const <Object?>[],
  );
  await _clickButton(driver, 'Convert a certificate');
  await _waitUntil(
    () => _pageContains(driver, 'Certificate (PEM or Base64)'),
    'Certificate conversion page did not open',
  );
  await _assertNoExternalRequests(
    driver,
    flow: 'certificate conversion startup',
  );
  await driver.execute(
    '''
    window.__chimeraCopiedText = null;
    window.__chimeraSavedName = null;
    window.__chimeraSavedBytes = null;
    window.__chimeraSaveCount = 0;
    const pem = arguments[0];
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        readText: async () => pem,
        writeText: async value => { window.__chimeraCopiedText = value; },
      },
    });
    const originalCreateObjectURL = URL.createObjectURL.bind(URL);
    URL.createObjectURL = function(blob) {
      blob.arrayBuffer().then(buffer => {
        window.__chimeraSavedBytes = [...new Uint8Array(buffer)];
      });
      return originalCreateObjectURL(blob);
    };
    HTMLAnchorElement.prototype.click = function() {
      window.__chimeraSavedName = this.download;
      window.__chimeraSaveCount++;
    };
    const originalInputClick = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function() {
      if (this.type === 'file') return;
      return originalInputClick.call(this);
    };
    performance.clearResourceTimings();
  ''',
    <Object?>[utf8.decode(pem)],
  );
  if (source == 'pem') {
    await _clickButton(driver, 'Paste certificate');
    await _waitUntil(
      () async =>
          await driver.execute(
            '''
            const input = [...document.querySelectorAll('textarea[aria-label]')]
              .find(element => element.getAttribute('aria-label') === arguments[0]);
            if (!input || input.disabled) return false;
            input.focus();
            return input.value === arguments[1];
          ''',
            <Object?>['Certificate (PEM or Base64)', utf8.decode(pem)],
          ) ==
          true,
      'Certificate conversion PEM source was not loaded exactly',
    );
  } else {
    await _clickButton(driver, 'Load certificate file');
    await _waitUntil(
      () async =>
          await driver.execute(
            '''
        const input = document.querySelector('input[type="file"]');
        if (!input) return false;
        const bytes = Uint8Array.from(atob(arguments[0]), c => c.charCodeAt(0));
        const transfer = new DataTransfer();
        transfer.items.add(new File([bytes], 'certificate.der',
          {type: 'application/octet-stream'}));
        input.files = transfer.files;
        input.dispatchEvent(new Event('change', {bubbles: true}));
        return input.files.length === 1 && input.files[0].size === 534;
      ''',
            <Object?>[base64.encode(der)],
          ) ==
          true,
      'Certificate conversion DER file could not be dispatched',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Input bytes: 534'),
      'Certificate conversion DER fixture was not loaded',
    );
  }
  await _clickCheckbox(
    driver,
    'Source representation: ${source.toUpperCase()}',
  );
  await _clickCheckbox(
    driver,
    'Target representation: ${target.toUpperCase()}',
  );
  await _clickButton(driver, 'Convert');
  final summary =
      'Converted certificate Certificate conversion succeeded. '
      'Source representation: ${source.toUpperCase()} '
      'Target representation: ${target.toUpperCase()} '
      'Input bytes: ${source == 'pem' ? 778 : 534} DER bytes: 534 '
      'Output bytes: ${target == 'pem' ? 778 : 534}';
  await _waitUntil(
    () async =>
        await driver.execute(
          r'''
      const normalize = value => value.replace(/\s+/g, ' ').trim();
      return [...document.querySelectorAll('[role="region"]')]
        .some(element => normalize(element.getAttribute('aria-label') || '') === arguments[0]);
    ''',
          <Object?>[summary],
        ) ==
        true,
    'Certificate conversion safe localized success semantics were incorrect',
  );
  if (target == 'pem') {
    await _clickButton(driver, 'Copy converted certificate');
    await _waitUntil(
      () async =>
          await driver.execute(
            'return window.__chimeraCopiedText === arguments[0];',
            <Object?>[utf8.decode(pem)],
          ) ==
          true,
      'Certificate conversion displayed/copied PEM was not fixture-exact',
    );
  } else {
    final hasCopy = await driver.execute('''
      return [...document.querySelectorAll('[role="button"]')]
        .some(element => element.textContent.trim() === 'Copy converted certificate');
    ''', const <Object?>[]);
    if (hasCopy != false) throw StateError('DER conversion exposed text copy');
  }
  await _clickButton(driver, 'Save converted certificate');
  await _waitUntil(
    () async =>
        await driver.execute(
          '''
      const bytes = window.__chimeraSavedBytes;
      return window.__chimeraSavedName === arguments[0] &&
        window.__chimeraSaveCount === 1 && Array.isArray(bytes) &&
        bytes.length === arguments[1].length &&
        bytes.every((value, index) => value === arguments[1][index]);
    ''',
          <Object?>['chimera-certificate.$target', target == 'der' ? der : pem],
        ) ==
        true,
    'Certificate conversion save was not fixture-exact',
  );
  await _assertNoNetworkRequests(
    driver,
    flow: 'certificate $source-to-$target conversion/save',
  );
}

Future<void> _assertNoResourceRequests(
  WebDriver driver, {
  required String flow,
}) async {
  final resourceUrls = await driver.execute(
    "return performance.getEntriesByType('resource').map(entry => entry.name);",
    const <Object?>[],
  );
  final urls = resourceUrls is List
      ? resourceUrls.map((entry) => entry.toString()).toList()
      : <String>[];
  if (urls.isNotEmpty) {
    throw StateError('Safari $flow made resource requests: $urls');
  }
}

Future<void> _assertNoNetworkRequests(
  WebDriver driver, {
  required String flow,
}) async {
  final resourceUrls = await driver.execute(
    "return performance.getEntriesByType('resource').map(entry => entry.name);",
    const <Object?>[],
  );
  final urls = resourceUrls is List
      ? resourceUrls.map((entry) => entry.toString()).where((url) {
          final scheme = Uri.parse(url).scheme;
          return scheme == 'http' || scheme == 'https';
        }).toList()
      : <String>[];
  if (urls.isNotEmpty) {
    throw StateError('Safari $flow made network requests: $urls');
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

Future<void> _activateGzipCopyButton(WebDriver driver) async {
  await _waitUntil(() async {
    final result = await driver.execute(
      '''
        const expected = arguments[0];
        const button = [...document.querySelectorAll('[role="button"]')]
          .find(element => element.textContent.trim() === expected &&
            element.getAttribute('aria-disabled') !== 'true');
        if (!button) return false;
        button.focus();
        return document.activeElement === button;
      ''',
      const <Object?>['Copy decompressed text'],
    );
    return result == true;
  }, 'GZIP copy button did not become keyboard-active');
  await driver.keyboard.sendKeys(Keyboard.enter);
}

Future<List<int>?> _copiedTextCodeUnits(WebDriver driver) async {
  final result = await driver.execute('''
      const value = window.__chimeraCopiedText;
      if (typeof value !== 'string') return null;
      return Array.from(value, character => character.charCodeAt(0));
    ''', const <Object?>[]);
  if (result is! List) return null;
  return result.cast<num>().map((value) => value.toInt()).toList();
}

Future<void> _clickCheckbox(WebDriver driver, String text) async {
  await _waitUntil(() async {
    final result = await driver.execute(
      '''
          const expected = arguments[0];
          const checkbox = [...document.querySelectorAll('[role="checkbox"]')]
            .find(element => element.getAttribute('aria-label') === expected);
          return checkbox !== undefined;
        ''',
      <Object?>[text],
    );
    return result == true;
  }, 'Checkbox did not become available: $text');

  final clicked = await driver.execute(
    '''
      const expected = arguments[0];
      const checkbox = [...document.querySelectorAll('[role="checkbox"]')]
        .find(element => element.getAttribute('aria-label') === expected);
      if (!checkbox) return false;
      if (checkbox.getAttribute('aria-checked') !== 'true') checkbox.click();
      return true;
    ''',
    <Object?>[text],
  );
  if (clicked != true) {
    throw StateError('Checkbox disappeared before selection: $text');
  }

  await _waitUntil(() async {
    final result = await driver.execute(
      '''
        const expected = arguments[0];
        const checkbox = [...document.querySelectorAll('[role="checkbox"]')]
          .find(element => element.getAttribute('aria-label') === expected);
        return checkbox?.getAttribute('aria-checked') === 'true';
      ''',
      <Object?>[text],
    );
    return result == true;
  }, 'Checkbox did not become selected: $text');
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
  String expected, {
  bool focus = false,
}) async {
  final result = await driver.execute(
    '''
      const label = arguments[0];
      const expected = arguments[1];
      const input = [...document.querySelectorAll('input[aria-label], textarea[aria-label]')]
        .find(element => element.getAttribute('aria-label') === label);
      if (!input || input.disabled) return false;
      if (arguments[2] === true) input.focus();
      return input.value === expected;
    ''',
    <Object?>[label, expected, focus],
  );
  return result == true;
}

Future<bool> _pageContains(WebDriver driver, String expected) async {
  final result = await driver.execute(
    r'''
      const normalize = value => value.replace(/\s+/g, ' ').trim();
      const expected = normalize(arguments[0]);
      if (normalize(document.body.innerText).includes(expected)) return true;
      return [...document.querySelectorAll('[aria-label]')]
        .some(element => normalize(element.getAttribute('aria-label')).includes(expected));
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
