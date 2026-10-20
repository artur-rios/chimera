import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:webdriver/async_io.dart';

import '../fixtures/jwt_signing_keys.dart';
import 'safari_protocol.dart';

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

const _urlDecodeSetupScript = r'''
  window.__chimeraUrlDecodeCopiedText = null;
  window.__chimeraUrlDecodeCopies = 0;
  window.__chimeraUrlDecodeReads = 0;
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: {
      readText: async () => {
        window.__chimeraUrlDecodeReads++;
        return '%3C%26%41%F0%9F%99%82%253C+';
      },
      writeText: async value => {
        window.__chimeraUrlDecodeCopies++;
        window.__chimeraUrlDecodeCopiedText = value;
      },
    },
  });
  performance.clearResourceTimings();
''';
const _urlDecodeSubmitScript = r'''
  const button = [...document.querySelectorAll('[role="button"]')]
    .find(element => element.textContent.trim() === 'Decode' &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!button) return false;
  button.focus();
  return document.activeElement === button;
''';
const _urlDecodeResultScript = r'''
  return [...document.querySelectorAll('[role="region"][tabindex="0"]')]
    .some(element => element.getAttribute('aria-label') ===
      'URL decoded result URL decoding succeeded.');
''';
const _urlDecodeCopyScript = r'''
  const button = [...document.querySelectorAll('[role="button"]')]
    .find(element => element.textContent.trim() === 'Copy decoded text' &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!button) return false;
  button.focus();
  return document.activeElement === button;
''';
const _urlDecodeCopiedScript = r'''
  return window.__chimeraUrlDecodeCopies === arguments[1] &&
    window.__chimeraUrlDecodeCopiedText === arguments[0];
''';
const _urlDecodeSaveScript = r'''
  return window.__chimeraSavedName === 'chimera-url-decoded.txt' &&
    window.__chimeraSaveCount === arguments[1] &&
    window.__chimeraSavedMime === 'text/plain; charset=utf-8' &&
    window.__chimeraLiveDownloadUrlCount === 0 &&
    window.__chimeraGzipSaveErrors.length === 0 &&
    JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(arguments[0]);
''';
const _urlDecodeNoResultScript = r'''
  const labels = [...document.querySelectorAll('[aria-label]')]
    .map(element => element.getAttribute('aria-label'));
  const buttons = [...document.querySelectorAll('[role="button"]')]
    .map(element => element.textContent.trim());
  return !labels.some(label => label.startsWith('URL decoded result')) &&
    !buttons.includes('Copy decoded text') && !buttons.includes('Save decoded text');
''';

const _htmlDecodeSetupScript = r'''
  window.__chimeraHtmlDecodeCopiedText = null;
  window.__chimeraHtmlDecodeCopies = 0;
  window.__chimeraHtmlDecodeReads = 0;
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: {
      readText: async () => {
        window.__chimeraHtmlDecodeReads++;
        return '&lt;&amp;&#65;&#x1F642;&amp;lt;';
      },
      writeText: async value => {
        window.__chimeraHtmlDecodeCopies++;
        window.__chimeraHtmlDecodeCopiedText = value;
      },
    },
  });
  performance.clearResourceTimings();
''';
const _htmlDecodeSubmitScript = r'''
  const button = [...document.querySelectorAll('[role="button"]')]
    .find(element => element.textContent.trim() === 'Decode' &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!button) return false;
  button.focus();
  return document.activeElement === button;
''';
const _htmlDecodeResultScript = r'''
  return [...document.querySelectorAll('[role="region"][tabindex="0"]')]
    .some(element => element.getAttribute('aria-label') ===
      'HTML decoded result HTML decoding succeeded.');
''';
const _htmlDecodeCopyScript = r'''
  const button = [...document.querySelectorAll('[role="button"]')]
    .find(element => element.textContent.trim() === 'Copy decoded text' &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!button) return false;
  button.focus();
  return document.activeElement === button;
''';
const _htmlDecodeCopiedScript = r'''
  return window.__chimeraHtmlDecodeCopies === arguments[1] &&
    window.__chimeraHtmlDecodeCopiedText === arguments[0];
''';
const _htmlDecodeSaveScript = r'''
  return window.__chimeraSavedName === 'chimera-html-decoded.txt' &&
    window.__chimeraSaveCount === arguments[1] &&
    window.__chimeraSavedMime === 'text/plain; charset=utf-8' &&
    window.__chimeraLiveDownloadUrlCount === 0 &&
    window.__chimeraGzipSaveErrors.length === 0 &&
    JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(arguments[0]);
''';
const _htmlDecodeNoResultScript = r'''
  const labels = [...document.querySelectorAll('[aria-label]')]
    .map(element => element.getAttribute('aria-label'));
  const buttons = [...document.querySelectorAll('[role="button"]')]
    .map(element => element.textContent.trim());
  return !labels.some(label => label.startsWith('HTML decoded result')) &&
    !buttons.includes('Copy decoded text') && !buttons.includes('Save decoded text');
''';

Future<void> main(List<String> arguments) async {
  // Exercise the same source loader without needing a SafariDriver session.
  if (arguments case ['--verify-gzip-save-observer']) {
    final observer = await _loadGzipSaveObserver();
    if (observer.isEmpty) throw StateError('GZIP save observer is empty');
    stdout.writeln('GZIP save observer source loaded successfully.');
    return;
  }
  if (arguments case ['--verify-url-helpers']) {
    final helpers = [
      _urlDecodeSetupScript,
      _urlDecodeSubmitScript,
      _urlDecodeResultScript,
      _urlDecodeCopyScript,
      _urlDecodeCopiedScript,
      _urlDecodeSaveScript,
      _urlDecodeNoResultScript,
    ];
    if (helpers.any((source) => source.isEmpty)) {
      throw StateError('URL helpers missing');
    }
    stdout.writeln('URL helpers (7) loaded successfully.');
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
      _htmlDecodeSetupScript,
      _htmlDecodeSubmitScript,
      _htmlDecodeResultScript,
      _htmlDecodeCopyScript,
      _htmlDecodeCopiedScript,
      _htmlDecodeSaveScript,
      _htmlDecodeNoResultScript,
    ];
    if (!observer.contains('function observeGzipSaves') ||
        helpers.any((source) => source.isEmpty)) {
      throw StateError('HTML helper or save observer source is missing');
    }
    stdout.writeln(
      'HTML helpers (16) and save observer source loaded successfully.',
    );
    return;
  }
  final directory = Directory('safari-diagnostics')
    ..createSync(recursive: true);
  final protocolLog = File('${directory.path}/protocol.jsonl')
      .openSync(mode: FileMode.write);
  final protocol = SafariProtocol(
    record: (event) {
      final stamped = {
        'time': DateTime.now().toUtc().toIso8601String(),
        ...event,
      };
      protocolLog.writeStringSync('${jsonEncode(stamped)}\n');
      if ((event['kind'] as String).startsWith('stage-') &&
          !(event['stage'] as String).contains(' / probe ')) {
        stdout.writeln('Safari ${event['kind']}: ${event['stage']}');
      }
    },
  );
  WebDriver? createdDriver;
  Object? primaryFailure;
  try {
    final driver = createdDriver = await protocol.connect(
      Uri.parse('http://127.0.0.1:4444/'),
    );
    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(() async {
      final flutterRoot = await driver.execute(
        "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
        const <Object?>[],
      );
      return await driver.title == 'Chimera' && flutterRoot == true;
    }, 'Chimera did not finish loading');

    await _enableFlutterSemantics(driver);
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') === null;",
            const <Object?>[],
          ) ==
          true,
      'Flutter semantics did not become available',
    );

    await _startCronDiagnostics(driver);
    await _clickButton(driver, 'Parse a cron expression');
    await _waitUntil(
      () => _pageContains(driver, 'Parse cron expression'),
      'Cron page did not open',
    );

    try {
      await _fillTextBox(driver, 'Cron expression', '0 9 * * MON-FRI');
      await _fillTextBox(driver, 'Time zone', 'UTC');
      await _fillTextBox(driver, 'Occurrence count', '1');
      await _fillTextBox(driver, 'Reference instant', '2026-01-05T12:00:00Z');
      await _capturePageDiagnostics(driver, 'cron-input');
      await _clickButton(driver, 'Calculate occurrences');

      await _waitUntil(
        () => _pageContains(driver, 'Cron schedule: 0 9 * * 1-5'),
        'Cron result did not render',
      );
      await _waitUntil(
        () => _pageContains(driver, 'Next: 2026-01-06T09:00:00.000+00:00'),
        'Cron next occurrence was incorrect',
      );
    } on Object {
      await _capturePageDiagnostics(driver, 'cron-failure');
      rethrow;
    } finally {
      try {
        await driver.execute(
          'window.__chimeraCronDiagnostics?.stop();',
          const <Object?>[],
        );
      } on Object catch (error) {
        stderr.writeln('Safari Cron diagnostics cleanup unavailable: $error');
      }
    }
    await _assertNoExternalRequests(driver, flow: 'cron');

    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(() async {
      final flutterRoot = await driver.execute(
        "return document.querySelector('flutter-view, flt-glass-pane') !== null;",
        const <Object?>[],
      );
      return flutterRoot == true;
    }, 'Chimera did not reload for date flow');
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
    await _enableFlutterSemantics(driver);
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
      await _enableFlutterSemantics(driver);
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
    try {
      await protocol.stage('Hash flows', () => _generateHash(driver, protocol));
    } on Object {
      await protocol.stage(
        'Hash failure diagnostics',
        () => _capturePageDiagnostics(driver, 'hash-failure'),
      );
      rethrow;
    }
    await protocol.stage('HTML encode', () => _encodeHtml(driver));
    await protocol.stage('HTML decode', () => _decodeHtml(driver));
    await protocol.stage('URL encode', () => _encodeUrl(driver));
    await protocol.stage('Cipher encode', () => _encodeCipher(driver));
    await protocol.stage('URL decode', () => _decodeUrl(driver));
    await protocol.stage('JWT create', () => _createJwt(driver));
    await protocol.stage('QR encode', () => _encodeQr(driver));
    await protocol.stage('QR decode', () => _decodeQr(driver));
    await protocol.stage('Lorem', () => _generateLorem(driver));
    await protocol.stage('Password', () => _generatePassword(driver));
    await protocol.stage('UUID', () => _generateUuid(driver));
    await protocol.stage('Synthetic cards', () => _generateCard(driver));
    await protocol.stage(
      'Synthetic identity documents',
      () => _generateIdentityDocument(driver),
    );
    await protocol.stage('Synthetic people', () => _generatePerson(driver));
    try {
      await protocol.stage('Checksum flows', () => _generateChecksum(driver));
    } on Object {
      await protocol.stage(
        'Checksum failure diagnostics',
        () => _capturePageDiagnostics(driver, 'checksum-failure'),
      );
      rethrow;
    }

    stdout.writeln(
      'Safari cron, date, number base, text escape, text unescape, list comparison, text analysis, text transformation, text comparison, Base64 encoding, Base64 decoding, certificate PEM/DER/Base64 inspection, certificate PEM-to-DER and DER-to-PEM conversion/save, GZIP text/binary compression/save and BOM text decompression/copy/save, HTML context encoding, URL encoding, classical cipher encoding, and strict decoding/copy/save/validation, local JWT signing and inspection, QR encoding and decoding/copy/save/validation, Lorem generation, password generation, UUID/GUID generation, synthetic card generation, synthetic identity document generation, synthetic person generation, JSON table, JSON CSV, JSON YAML, JSON format, SQL format, and XML format smoke: OK',
    );
  } on Object catch (error) {
    primaryFailure = error;
    stderr.writeln('Safari primary failure: $error');
    rethrow;
  } finally {
    try {
      if (createdDriver != null && !protocol.failed) {
        try {
          await protocol.stage('session quit', () => createdDriver!.quit());
        } on Object catch (error) {
          if (primaryFailure == null) rethrow;
          stderr.writeln(
            'Safari cleanup failure after primary failure: $error',
          );
        }
      }
    } finally {
      protocol.close();
      protocolLog.closeSync();
    }
  }
}

Future<void> _createJwt(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'JWT semantics placeholder did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Create JWT');
  await _waitUntil(
    () => _pageContains(driver, 'Claims JSON'),
    'JWT page did not open',
  );
  await _fillTextBox(driver, 'Claims JSON', '{"safari":true}');
  await _fillTextBox(
    driver,
    'Private signing key',
    '0123456789abcdef0123456789abcdef',
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
  ''', const <Object?>[]);
  await _clickButton(driver, 'Create and sign');
  const expectedToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJzYWZhcmkiOnRydWV9.'
      'MEYOeS9ebNwKFUoNzAC__7ZTq6-xRIwmnqdgsvx4oBg';
  await _clickButton(driver, 'Copy JWT');
  await _waitUntil(
    () async =>
        await driver.execute(
          'return window.__chimeraCopiedText === arguments[0];',
          const <Object?>[expectedToken],
        ) ==
        true,
    'JWT compact result copy was incorrect',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Claims JSON', ''),
    'JWT claims were not discarded',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Private signing key', ''),
    'JWT key was not discarded',
  );
  await _assertNoExternalRequests(driver, flow: 'JWT creation');
  final rsaToken = await _createAsymmetricJwt(driver, 'RS256', rsaPrivateJwk);
  final ecToken = await _createAsymmetricJwt(driver, 'ES256', ecPrivateJwk);
  await _openJwtInspectPage(driver);
  await _inspectJwt(
    driver,
    token: expectedToken,
    algorithm: 'HS256',
    claimsJson: '{"safari":true}',
    status: 'not-requested',
  );
  await _inspectJwt(
    driver,
    token: expectedToken,
    key: '0123456789abcdef0123456789abcdef',
    algorithm: 'HS256',
    claimsJson: '{"safari":true}',
    status: 'verified',
  );
  await _inspectJwt(
    driver,
    token: expectedToken,
    key: 'fedcba9876543210fedcba9876543210',
    algorithm: 'HS256',
    claimsJson: '{"safari":true}',
    status: 'failed',
  );
  await _inspectJwt(
    driver,
    token: rsaToken,
    key: rsaPrivateJwk,
    algorithm: 'RS256',
    claimsJson: '{"safari":true,"family":"RS256"}',
    status: 'verified',
  );
  await _inspectJwt(
    driver,
    token: ecToken,
    key: ecPrivateJwk,
    algorithm: 'ES256',
    claimsJson: '{"safari":true,"family":"ES256"}',
    status: 'verified',
  );
}

Future<void> _decodeQr(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'QR decode semantics did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Decode QR code');
  await _waitUntil(
    () => _pageContains(driver, 'Choose PNG, JPEG or BMP image'),
    'QR decode page did not open',
  );
  final saveObserver = await _loadGzipSaveObserver();
  await driver.execute(
    '$saveObserver\nobserveGzipSaves({suppressDownloads: true});',
    const <Object?>[],
  );
  await driver.execute(_qrDecodeSetupScript, const <Object?>[]);
  final png = await File.fromUri(
    Platform.script.resolve('../fixtures/encoded/qr/unicode.png'),
  ).readAsBytes();
  for (final valid in <bool>[true, false]) {
    await _clickButton(driver, 'Choose PNG, JPEG or BMP image');
    await _waitUntil(
      () async =>
          await driver.execute(_qrDecodeLoadScript, <Object?>[
            base64Encode(valid ? png : <int>[1, 2, 3]),
          ]) ==
          true,
      'QR image source was not supplied',
    );
    await _waitUntil(
      () => _pageContains(driver, 'Image ready to decode.'),
      'QR image was not ready',
    );
    await _clickButton(driver, 'Decode QR');
    if (!valid) {
      await _waitUntil(
        () => _pageContains(
          driver,
          'The image could not be decoded as a QR code.',
        ),
        'Corrupt QR image did not fail safely',
      );
      final stale = await driver.execute(r'''
        return [...document.querySelectorAll('[role="region"]')]
          .some(e => (e.getAttribute('aria-label') || '').startsWith('Decoded QR result'));
      ''', const <Object?>[]);
      if (stale == true) {
        throw StateError('Corrupt QR image retained stale output');
      }
      continue;
    }
    await _waitUntil(
      () => _pageContains(driver, 'QR code decoded.'),
      'QR decoding did not succeed',
    );
    await _clickButton(driver, 'Copy text');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return window.__chimeraQrDecodedText === 'QR Olá 世界 🌍';",
            const <Object?>[],
          ) ==
          true,
      'QR decoded Unicode copy was not exact',
    );
    await _clickButton(driver, 'Save UTF-8 text');
    await _waitUntil(
      () async =>
          await driver.execute(r'''
        return window.__chimeraSavedName === 'chimera-qr-decoded.txt' &&
          new TextDecoder().decode(new Uint8Array(window.__chimeraSavedBytes || [])) === 'QR Olá 世界 🌍' &&
          window.__chimeraSaveCount === 1 && window.__chimeraLiveDownloadUrlCount === 0 &&
          window.__chimeraGzipSaveErrors.length === 0;
      ''', const <Object?>[]) ==
          true,
      'QR decoded UTF-8 save was not exact',
    );
  }
  await _assertNoNetworkRequests(
    driver,
    flow: 'QR decoding/copy/save/validation',
    allowFontFallback: true,
  );
}

const _qrDecodeSetupScript = r'''
  window.__chimeraQrDecodedText = null;
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: {writeText: async value => { window.__chimeraQrDecodedText = value; }},
  });
  const original = HTMLInputElement.prototype.click;
  HTMLInputElement.prototype.click = function() {
    if (this.type === 'file') { window.__chimeraQrImageInput = this; return; }
    return original.call(this);
  };
  performance.clearResourceTimings();
''';

const _qrDecodeLoadScript = r'''
  const input = window.__chimeraQrImageInput;
  if (!input) return false;
  const bytes = Uint8Array.from(atob(arguments[0]), char => char.charCodeAt(0));
  const transfer = new DataTransfer();
  transfer.items.add(new File([bytes], 'source.png', {type: 'image/png'}));
  input.files = transfer.files;
  input.dispatchEvent(new Event('change', {bubbles: true}));
  window.__chimeraQrImageInput = null;
  return true;
''';

Future<void> _encodeQr(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'QR semantics placeholder did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Encode QR code');
  await _waitUntil(
    () => _pageContains(driver, 'Text to encode'),
    'QR encoding page did not open',
  );
  final saveObserver = await _loadGzipSaveObserver();
  await driver.execute(
    '$saveObserver\nobserveGzipSaves({suppressDownloads: true});\n'
    '''
    window.__chimeraQrClipboardReads = 0;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {readText: async () => {
        window.__chimeraQrClipboardReads++;
        return 'Safari Olá 🌍';
      }},
    });
    performance.clearResourceTimings();
    ''',
    const <Object?>[],
  );
  await _clickButton(driver, 'Paste text');
  await _waitUntil(
    () =>
        _inputHasValue(driver, 'Text to encode', 'Safari Olá 🌍', focus: true),
    'QR UTF-8 clipboard source was not loaded',
  );
  final clipboardReads = await driver.execute(
    'return window.__chimeraQrClipboardReads;',
    const <Object?>[],
  );
  if (clipboardReads != 1) {
    throw StateError('QR clipboard was not read exactly once');
  }
  await _fillTextBox(driver, 'Image size (pixels)', '256');
  await _clickButton(driver, 'Generate QR');
  await _waitUntil(
    () async =>
        await driver.execute(r'''
      return [...document.querySelectorAll('[role="region"][tabindex="0"]')]
        .some(element => (element.getAttribute('aria-label') || '')
          .startsWith('QR encoding result QR encoding succeeded. 256 x 256'));
    ''', const <Object?>[]) ==
        true,
    'QR success semantics were incorrect',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Text to encode', ''),
    'QR source was not discarded',
  );
  await _clickButton(driver, 'Save PNG');
  await _waitUntil(
    () async =>
        await driver.execute(r'''
      const bytes = window.__chimeraSavedBytes;
      if (!Array.isArray(bytes) || bytes.length < 24) return false;
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      const width = bytes[16] * 0x1000000 + (bytes[17] << 16) +
        (bytes[18] << 8) + bytes[19];
      const height = bytes[20] * 0x1000000 + (bytes[21] << 16) +
        (bytes[22] << 8) + bytes[23];
      return window.__chimeraSavedName === 'chimera-qr.png' &&
        window.__chimeraSaveCount === 1 &&
        window.__chimeraSavedMime === 'image/png' &&
        window.__chimeraLiveDownloadUrlCount === 0 &&
        window.__chimeraGzipSaveErrors.length === 0 &&
        signature.every((value, index) => bytes[index] === value) &&
        width === 256 && height === 256;
    ''', const <Object?>[]) ==
        true,
    'QR exact PNG save boundary did not complete',
  );

  await _fillTextBox(driver, 'Text to encode', 'discard this source');
  await _fillTextBox(driver, 'Image size (pixels)', '10');
  await _clickButton(driver, 'Generate QR');
  await _waitUntil(
    () => _pageContains(driver, 'The QR encoding request is invalid.'),
    'QR validation failure was not localized',
  );
  await _waitUntil(
    () async =>
        await driver.execute(r'''
      return ![...document.querySelectorAll('[role="region"]')]
        .some(element => (element.getAttribute('aria-label') || '')
          .startsWith('QR encoding result'));
    ''', const <Object?>[]) ==
        true,
    'QR validation retained a stale result',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Text to encode', ''),
    'QR invalid source was not discarded',
  );
  await _assertNoNetworkRequests(driver, flow: 'QR encoding/save/validation');
}

Future<String> _createAsymmetricJwt(
  WebDriver driver,
  String algorithm,
  String key,
) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    '$algorithm JWT semantics placeholder did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Create JWT');
  await _waitUntil(
    () => _pageContains(driver, 'Claims JSON'),
    '$algorithm JWT page did not open',
  );
  await _waitUntil(
    () async =>
        await driver.execute(r'''
    const normalize = value => value.replace(/\s+/g, ' ').trim();
    const selector = [...document.querySelectorAll('[role="button"]')]
      .find(element => normalize(element.getAttribute('aria-label') || element.textContent) === 'Signing algorithm HS256');
    if (!selector) return false;
    selector.click();
    return true;
  ''', const <Object?>[]) ==
        true,
    '$algorithm JWT algorithm selector was unavailable',
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
          <Object?>[algorithm],
        ) ==
        true,
    '$algorithm JWT algorithm could not be selected',
  );
  await _fillTextBox(
    driver,
    'Claims JSON',
    '{"safari":true,"family":"$algorithm"}',
  );
  await _fillTextBox(driver, 'Private signing key', key);
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
  ''', const <Object?>[]);
  await _clickButton(driver, 'Create and sign');
  await _clickButton(driver, 'Copy JWT');
  await _waitUntil(
    () async =>
        await driver.execute(
          r'''
    const token = window.__chimeraCopiedText;
    if (typeof token !== 'string') return false;
    const segments = token.split('.');
    if (segments.length !== 3 || segments.some(segment => segment.length === 0)) return false;
    const decode = segment => {
      const padded = segment.replace(/-/g, '+').replace(/_/g, '/')
        .padEnd(Math.ceil(segment.length / 4) * 4, '=');
      return JSON.parse(new TextDecoder().decode(
        Uint8Array.from(atob(padded), character => character.charCodeAt(0)),
      ));
    };
    const header = decode(segments[0]);
    const claims = decode(segments[1]);
    return header.alg === arguments[0] && header.typ === 'JWT' &&
      claims.safari === true && claims.family === arguments[0];
  ''',
          <Object?>[algorithm],
        ) ==
        true,
    '$algorithm JWT compact result was invalid',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Claims JSON', ''),
    '$algorithm JWT claims were not discarded',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Private signing key', ''),
    '$algorithm JWT key was not discarded',
  );
  await _assertNoExternalRequests(driver, flow: '$algorithm JWT creation');
  final token = await driver.execute(
    'return window.__chimeraCopiedText;',
    const <Object?>[],
  );
  if (token is! String) {
    throw StateError('$algorithm JWT token was not available for inspection');
  }
  return token;
}

Future<void> _openJwtInspectPage(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'JWT inspection semantics placeholder did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Inspect JWT');
  await _waitUntil(
    () => _pageContains(driver, 'Optional verification key'),
    'JWT inspection page did not open',
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
  ''', const <Object?>[]);
}

Future<void> _inspectJwt(
  WebDriver driver, {
  required String token,
  required String algorithm,
  required String claimsJson,
  required String status,
  String? key,
}) async {
  await _fillTextBox(driver, 'JWT', token);
  if (key != null) {
    await _fillTextBox(driver, 'Optional verification key', key);
  }
  await _clickButton(driver, 'Inspect and verify');
  final statusLabel = switch (status) {
    'not-requested' => 'Not requested',
    'verified' => 'Verified',
    'failed' => 'Failed — decoded data is untrusted',
    _ => throw StateError('Unknown JWT inspection status: $status'),
  };
  await _waitUntil(
    () => _pageContains(driver, statusLabel),
    '$algorithm JWT inspection status was not $status',
  );
  if (status == 'failed') {
    await _waitUntil(
      () => _pageContains(
        driver,
        'Signature verification failed. Decoded data is untrusted.',
      ),
      'JWT inspection did not expose the untrusted-data warning',
    );
  }
  await _clickButton(driver, 'Copy inspection result');
  final expected =
      '{"header":{"alg":"$algorithm","typ":"JWT"},'
      '"claims":$claimsJson,"verification":"$status"}';
  await _waitUntil(
    () async =>
        await driver.execute(
          'return window.__chimeraCopiedText === arguments[0];',
          <Object?>[expected],
        ) ==
        true,
    '$algorithm JWT inspection JSON was not exact',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'JWT', ''),
    '$algorithm JWT inspection token was not discarded',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Optional verification key', ''),
    '$algorithm JWT inspection key was not discarded',
  );
  await _assertNoExternalRequests(driver, flow: '$algorithm JWT inspection');
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
  await _enableFlutterSemantics(driver);
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

Future<void> _decodeUrl(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'URL Decode semantics placeholder did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Decode URL');
  await _waitUntil(
    () => _pageContains(driver, 'Percent-encoded text to decode'),
    'URL Decode page did not open',
  );
  await _assertNoExternalRequests(driver, flow: 'URL Decode startup');
  final observer = await _loadGzipSaveObserver();
  await driver.execute(
    '$observer\nobserveGzipSaves({suppressDownloads: true});',
    const <Object?>[],
  );
  await driver.execute(_urlDecodeSetupScript, const <Object?>[]);
  await driver.execute('''
    const click = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function() {
      if (this.type === 'file') return;
      return click.call(this);
    };
  ''', const <Object?>[]);
  const expected = '<&A🙂%3C+';
  await _clickButton(driver, 'Paste text');
  await _waitUntil(
    () => _inputHasValue(
      driver,
      'Percent-encoded text to decode',
      '%3C%26%41%F0%9F%99%82%253C+',
      focus: true,
    ),
    'URL Decode clipboard source was not loaded',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeSubmitScript, const <Object?>[]) == true,
    'URL Decode submit was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeResultScript, const <Object?>[]) == true,
    'URL Decode result semantics were incorrect',
  );
  await _waitUntil(
    () => _inputHasValue(
      driver,
      'Percent-encoded text to decode',
      '',
      focus: true,
    ),
    'URL Decode source was retained',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeCopyScript, const <Object?>[]) == true,
    'URL Decode copy was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeCopiedScript, const <Object?>[
          expected,
          1,
        ]) ==
        true,
    'URL Decode clipboard output was not exact',
  );
  await _clickButton(driver, 'Save decoded text');
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeSaveScript, <Object?>[
          utf8.encode(expected),
          1,
        ]) ==
        true,
    'URL Decode non-empty save/URL cleanup was not exact',
  );
  await _waitUntil(
    () => _pageContains(driver, 'URL decoded text saved.'),
    'URL Decode non-empty save did not finish',
  );
  await _clickButton(driver, 'Decode');
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeResultScript, const <Object?>[]) == true,
    'URL Decode empty result did not appear',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeCopyScript, const <Object?>[]) == true,
    'URL Decode empty copy was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeCopiedScript, const <Object?>['', 2]) ==
        true,
    'URL Decode empty copy was not exact',
  );
  await _clickButton(driver, 'Save decoded text');
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeSaveScript, const <Object?>[
          <int>[],
          2,
        ]) ==
        true,
    'URL Decode empty save/URL cleanup was not exact',
  );
  await _clickButton(driver, 'Load UTF-8 file');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlFileScript, const <Object?>[
          <int>[0xc3, 0x28],
        ]) ==
        true,
    'URL Decode malformed UTF-8 fixture could not be dispatched',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeNoResultScript, const <Object?>[]) ==
        true,
    'URL Decode file load did not discard the previous result',
  );
  await _clickButton(driver, 'Decode');
  await _waitUntil(
    () => _pageContains(driver, 'The URL decoding request is invalid.'),
    'URL Decode UTF-8 validation did not appear',
  );
  if (await driver.execute(_urlDecodeNoResultScript, const <Object?>[]) !=
      true) {
    throw StateError('URL Decode validation retained an output action');
  }
  final reads = await driver.execute(
    'return window.__chimeraUrlDecodeReads;',
    const <Object?>[],
  );
  if (reads != 1) {
    throw StateError('URL Decode clipboard source was not read once');
  }
  await driver.execute(r'''
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        readText: async () => '%3Cprivate%3E',
        writeText: async () => { throw new Error('private'); },
      },
    });
  ''', const <Object?>[]);
  await _clickButton(driver, 'Paste text');
  await _waitUntil(
    () => _inputHasValue(
      driver,
      'Percent-encoded text to decode',
      '%3Cprivate%3E',
      focus: true,
    ),
    'URL Decode output-denial fixture was not loaded',
  );
  await _clickButton(driver, 'Decode');
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeResultScript, const <Object?>[]) == true,
    'URL Decode output-denial result did not appear',
  );
  await _clickButton(driver, 'Copy decoded text');
  await _waitUntil(
    () => _pageContains(driver, 'The clipboard text could not be written.'),
    'URL Decode output access failure did not appear',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_urlDecodeNoResultScript, const <Object?>[]) ==
        true,
    'URL Decode output access retained a result',
  );
  await _assertNoNetworkRequests(
    driver,
    flow: 'URL Decode copy/save/validation',
  );
}

Future<void> _decodeHtml(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'HTML Decode semantics placeholder did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Decode HTML');
  await _waitUntil(
    () => _pageContains(driver, 'HTML entities to decode'),
    'HTML Decode page did not open',
  );
  await _assertNoExternalRequests(driver, flow: 'HTML Decode startup');
  final observer = await _loadGzipSaveObserver();
  await driver.execute(
    '$observer\nobserveGzipSaves({suppressDownloads: true});',
    const <Object?>[],
  );
  await driver.execute(_htmlDecodeSetupScript, const <Object?>[]);
  await driver.execute('''
    const click = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function() {
      if (this.type === 'file') return;
      return click.call(this);
    };
  ''', const <Object?>[]);
  const expected = '<&A🙂&lt;';
  await _clickButton(driver, 'Paste text');
  await _waitUntil(
    () => _inputHasValue(
      driver,
      'HTML entities to decode',
      '&lt;&amp;&#65;&#x1F642;&amp;lt;',
      focus: true,
    ),
    'HTML Decode clipboard source was not loaded',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeSubmitScript, const <Object?>[]) ==
        true,
    'HTML Decode submit was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeResultScript, const <Object?>[]) ==
        true,
    'HTML Decode result semantics were incorrect',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'HTML entities to decode', '', focus: true),
    'HTML Decode source was retained',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeCopyScript, const <Object?>[]) == true,
    'HTML Decode copy was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeCopiedScript, const <Object?>[
          expected,
          1,
        ]) ==
        true,
    'HTML Decode clipboard output was not exact',
  );
  await _clickButton(driver, 'Save decoded text');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeSaveScript, <Object?>[
          utf8.encode(expected),
          1,
        ]) ==
        true,
    'HTML Decode non-empty save/URL cleanup was not exact',
  );
  await _waitUntil(
    () => _pageContains(driver, 'HTML decoded text saved.'),
    'HTML Decode non-empty save did not finish',
  );
  await _clickButton(driver, 'Decode');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeResultScript, const <Object?>[]) ==
        true,
    'HTML Decode empty result did not appear',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeCopyScript, const <Object?>[]) == true,
    'HTML Decode empty copy was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeCopiedScript, const <Object?>['', 2]) ==
        true,
    'HTML Decode empty copy was not exact',
  );
  await _clickButton(driver, 'Save decoded text');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeSaveScript, const <Object?>[
          <int>[],
          2,
        ]) ==
        true,
    'HTML Decode empty save/URL cleanup was not exact',
  );
  await _clickButton(driver, 'Load UTF-8 file');
  await _waitUntil(
    () async =>
        await driver.execute(_htmlFileScript, const <Object?>[
          <int>[0xc3, 0x28],
        ]) ==
        true,
    'HTML Decode malformed UTF-8 fixture could not be dispatched',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_htmlDecodeNoResultScript, const <Object?>[]) ==
        true,
    'HTML Decode file load did not discard the previous result',
  );
  await _clickButton(driver, 'Decode');
  await _waitUntil(
    () => _pageContains(driver, 'The HTML decoding request is invalid.'),
    'HTML Decode UTF-8 validation did not appear',
  );
  if (await driver.execute(_htmlDecodeNoResultScript, const <Object?>[]) !=
      true) {
    throw StateError('HTML Decode validation retained an output action');
  }
  final reads = await driver.execute(
    'return window.__chimeraHtmlDecodeReads;',
    const <Object?>[],
  );
  if (reads != 1) {
    throw StateError('HTML Decode clipboard source was not read once');
  }
  await _assertNoNetworkRequests(
    driver,
    flow: 'HTML Decode copy/save/validation',
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
  await _enableFlutterSemantics(driver);
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
  await _enableFlutterSemantics(driver);
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
  await _enableFlutterSemantics(driver);
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

// Shared with Playwright; other flows keep rejecting every HTTP request.
const _networkRequestPolicyScript = r'''
  const urls = arguments[0] ?? performance.getEntriesByType('resource').map(entry => entry.name);
  const applicationOrigin = new URL(arguments[1] ?? location.href).origin;
  const allowFontFallback = arguments[2] === true;
  return urls.filter(value => {
    let url;
    try { url = new URL(value); } catch { return true; }
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return false;
    const fontPath = /^\/font-fallback\/[a-z0-9]+\/v[0-9]+\/[A-Za-z0-9_.-]+\.woff2$/;
    const allowedFont = allowFontFallback && url.origin === applicationOrigin &&
      !url.username && !url.password && !url.search && !url.hash &&
      !value.includes('%') && fontPath.test(url.pathname);
    return !allowedFont;
  });
''';

Future<void> _assertNoNetworkRequests(
  WebDriver driver, {
  required String flow,
  bool allowFontFallback = false,
}) async {
  final resourceUrls = await driver.execute(
    _networkRequestPolicyScript,
    <Object?>[null, null, allowFontFallback],
  );
  final urls = resourceUrls is List
      ? resourceUrls.map((entry) => entry.toString()).toList()
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

Future<String> _loadSafariTextInput() =>
    File.fromUri(Platform.script.resolve('safari_text_input.js'))
        .readAsString();

Future<void> _enableFlutterSemantics(WebDriver driver) async {
  final source = await _loadSafariTextInput();
  await driver.execute(
    '$source\ninstallSafariTextInputReadiness();\n'
    "document.querySelector('flt-semantics-placeholder')?.click();",
    const <Object?>[],
  );
}

Future<void> _fillTextBox(WebDriver driver, String label, String value) async {
  final source = await _loadSafariTextInput();
  for (var attempt = 0; attempt < 3; attempt++) {
    // SafariDriver pointer events can use a different clock from DOM click().
    // Keep activation on the semantics path and await the real input listener.
    await _waitUntil(
      () async =>
          await driver.execute(
            '$source\nreturn prepareSafariTextInput(arguments[0]);',
            <Object?>[label],
          ) ==
          true,
      'Text box did not connect for editing: $label',
    );
    // Native Safari runs on macOS. sendChord releases both A and Command.
    await driver.keyboard.sendChord(<String>[Keyboard.command, 'a']);

    var entered = '';
    var attemptSucceeded = true;
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
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

// Observe the public Cron fixture without changing input actions or waits.
Future<void> _startCronDiagnostics(WebDriver driver) async {
  try {
    final source = await File.fromUri(
      Platform.script.resolve('safari_cron_diagnostics.js'),
    ).readAsString();
    await driver.execute(
      '$source\ninstallCronDiagnostics();',
      const <Object?>[],
    );
  } on Object catch (error) {
    stderr.writeln('Safari Cron diagnostics unavailable: $error');
  }
}

// Only public smoke fixtures call this; preserve the original
// failure even if Safari cannot provide one of the diagnostic artifacts.
Future<void> _capturePageDiagnostics(WebDriver driver, String name) async {
  try {
    final source = await File.fromUri(
      Platform.script.resolve('safari_page_diagnostics.js'),
    ).readAsString();
    final page = await driver.execute(
      '$source\nreturn captureSafariPageDiagnostics();',
      const <Object?>[],
    );
    final directory = await Directory('safari-diagnostics')
        .create(recursive: true);
    await File('${directory.path}/$name.json').writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert({'capabilities': driver.capabilities, 'page': page}),
    );
    await File('${directory.path}/$name.png')
        .writeAsBytes(await driver.captureScreenshotAsList());
    stdout.writeln('Safari diagnostics saved: ${directory.path}/$name');
  } on Object catch (error) {
    stderr.writeln('Safari diagnostics unavailable for $name: $error');
  }
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
    if (await SafariProtocol.withinDeadline(deadline, predicate)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('$failureMessage within ${timeout.inSeconds} seconds.');
}

const _urlSetupScript = r'''
  window.__chimeraUrlCopiedText = null;
  window.__chimeraUrlCopies = 0;
  window.__chimeraUrlReads = 0;
  window.__chimeraUrlClipboardSource = '&<>"\'/ &amp; Olá 🌍';
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: {
      readText: async () => {
        window.__chimeraUrlReads++;
        return window.__chimeraUrlClipboardSource;
      },
      writeText: async value => {
        window.__chimeraUrlCopies++;
        window.__chimeraUrlCopiedText = value;
      },
    },
  });
  performance.clearResourceTimings();
''';
const _urlModeOpenScript = r'''
  const normalize = value => value.replace(/\s+/g, ' ').trim();
  const button = [...document.querySelectorAll('[role="button"]')]
    .find(element => normalize(element.getAttribute('aria-label') || element.textContent) === 'URL mode URL component' &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!button) return false;
  button.click();
  return true;
''';
const _urlModeSelectScript = r'''
  const option = [...document.querySelectorAll('[role="menuitem"]')]
    .find(element => (element.getAttribute('aria-label') || element.textContent).trim() === arguments[0] &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!option) return false;
  option.click();
  return true;
''';
const _urlResultScript = r'''
  const result = [...document.querySelectorAll('[role="region"][tabindex="0"]')]
    .find(element => element.getAttribute('aria-label') === 'URL encoded result URL encoding succeeded.');
  return result !== undefined;
''';
const _urlCopyScript = r'''
  const button = [...document.querySelectorAll('[role="button"]')]
    .find(element => element.textContent.trim() === 'Copy encoded text' &&
      element.getAttribute('aria-disabled') !== 'true');
  if (!button) return false;
  button.focus();
  return document.activeElement === button;
''';
const _urlCopiedScript = r'''
  return window.__chimeraUrlCopies === arguments[1] &&
    window.__chimeraUrlCopiedText === arguments[0];
''';
const _urlSaveScript = r'''
  return window.__chimeraSavedName === 'chimera-url-encoded.txt' &&
    window.__chimeraSaveCount === arguments[1] &&
    window.__chimeraSavedMime === 'text/plain; charset=utf-8' &&
    window.__chimeraLiveDownloadUrlCount === 0 &&
    window.__chimeraGzipSaveErrors.length === 0 &&
    JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(arguments[0]);
''';
const _urlFileScript = r'''
  const picker = document.querySelector('input[type="file"]');
  if (!picker) return false;
  const transfer = new DataTransfer();
  transfer.items.add(new File([new Uint8Array(arguments[0])],
    'source.txt', {type: 'text/plain'}));
  picker.files = transfer.files;
  picker.dispatchEvent(new Event('change', {bubbles: true}));
  return true;
''';
const _urlNoResultScript = r'''
  const labels = [...document.querySelectorAll('[aria-label]')]
    .map(element => element.getAttribute('aria-label'));
  const buttons = [...document.querySelectorAll('[role="button"]')]
    .map(element => element.textContent.trim());
  return !labels.some(label => label.startsWith('URL encoded result')) &&
    !buttons.includes('Copy encoded text') && !buttons.includes('Save encoded text');
''';

Future<void> _encodeUrl(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'URL semantics placeholder did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Encode URL');
  await _waitUntil(
    () => _pageContains(driver, 'Text to encode'),
    'URL page did not open',
  );
  await _assertNoExternalRequests(driver, flow: 'URL startup');
  final observer = await _loadGzipSaveObserver();
  await driver.execute(
    '$observer\nobserveGzipSaves({suppressDownloads: true});',
    const <Object?>[],
  );
  await driver.execute(_urlSetupScript, const <Object?>[]);
  // SafariDriver has no upload endpoint; use its existing real File dispatch.
  await driver.execute('''
    const click = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function() {
      if (this.type === 'file') return;
      return click.call(this);
    };
  ''', const <Object?>[]);
  const expected = '&%3C%3E%22\'/%20&amp;%20Ol%C3%A1%20%F0%9F%8C%8D';
  await _clickButton(driver, 'Paste text');
  await _waitUntil(
    () => _inputHasValue(
      driver,
      'Text to encode',
      '&<>"\'/ &amp; Olá 🌍',
      focus: true,
    ),
    'URL clipboard source was not loaded',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_urlModeOpenScript, const <Object?>[]) == true,
    'URL default context was unavailable',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_urlModeSelectScript, const <Object?>[
          'Full value',
        ]) ==
        true,
    'URL double-quoted context was unavailable',
  );
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () async =>
        await driver.execute(_urlResultScript, const <Object?>[]) == true,
    'URL result semantics were incorrect',
  );
  await _waitUntil(
    () => _inputHasValue(driver, 'Text to encode', '', focus: true),
    'URL source was retained',
  );
  await _waitUntil(
    () async => await driver.execute(_urlCopyScript, const <Object?>[]) == true,
    'URL copy was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_urlCopiedScript, const <Object?>[expected, 1]) ==
        true,
    'URL clipboard output was not exact',
  );
  await _clickButton(driver, 'Save encoded text');
  await _waitUntil(
    () async =>
        await driver.execute(_urlSaveScript, <Object?>[
          utf8.encode(expected),
          1,
        ]) ==
        true,
    'URL non-empty save/URL cleanup was not exact',
  );
  await _waitUntil(
    () => _pageContains(driver, 'URL encoded text saved.'),
    'URL non-empty save did not finish',
  );
  // A second encode has no retained source: it must copy/save exactly zero bytes.
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () async =>
        await driver.execute(_urlResultScript, const <Object?>[]) == true,
    'URL empty result did not appear',
  );
  await _waitUntil(
    () async => await driver.execute(_urlCopyScript, const <Object?>[]) == true,
    'URL empty copy was not keyboard-active',
  );
  await driver.keyboard.sendKeys(Keyboard.enter);
  await _waitUntil(
    () async =>
        await driver.execute(_urlCopiedScript, const <Object?>['', 2]) == true,
    'URL empty copy was not exact',
  );
  await _clickButton(driver, 'Save encoded text');
  await _waitUntil(
    () async =>
        await driver.execute(_urlSaveScript, const <Object?>[<int>[], 2]) ==
        true,
    'URL empty save/URL cleanup was not exact',
  );
  await _waitUntil(
    () => _pageContains(driver, 'URL encoded text saved.'),
    'URL empty save did not finish',
  );
  await _clickButton(driver, 'Load UTF-8 file');
  await _waitUntil(
    () async =>
        await driver.execute(_urlFileScript, const <Object?>[
          <int>[0xc3, 0x28],
        ]) ==
        true,
    'URL malformed UTF-8 fixture could not be dispatched',
  );
  await _waitUntil(
    () async =>
        await driver.execute(_urlNoResultScript, const <Object?>[]) == true,
    'URL file load did not discard the previous result',
  );
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () => _pageContains(driver, 'The URL encoding request is invalid.'),
    'URL UTF-8 validation did not appear',
  );
  if (await driver.execute(_urlNoResultScript, const <Object?>[]) != true) {
    throw StateError('URL validation retained an output action or result');
  }
  await _waitUntil(
    () => _inputHasValue(driver, 'Text to encode', '', focus: true),
    'URL validation retained source text',
  );
  final reads = await driver.execute(
    'return window.__chimeraUrlReads;',
    const <Object?>[],
  );
  if (reads != 1) throw StateError('URL clipboard source was not read once');
  for (final boundary in ['copy', 'save']) {
    await driver.execute(
      "window.__chimeraUrlClipboardSource = 'private /ação';",
      const <Object?>[],
    );
    await _clickButton(driver, 'Paste text');
    await _waitUntil(
      () => _inputHasValue(
        driver,
        'Text to encode',
        'private /ação',
        focus: true,
      ),
      'URL failure source was not loaded',
    );
    await _clickButton(driver, 'Encode');
    await _waitUntil(
      () async =>
          await driver.execute(_urlResultScript, const <Object?>[]) == true,
      'URL failure fixture did not produce a result',
    );
    await driver.execute(
      r'''
      if (arguments[0] === 'copy') {
        navigator.clipboard.writeText = async () => {
          throw new Error('private output denial');
        };
      } else {
        window.__chimeraUrlOriginalCreateObjectURL = URL.createObjectURL;
        URL.createObjectURL = () => { throw new Error('private output denial'); };
      }
    ''',
      <Object?>[boundary],
    );
    await _clickButton(
      driver,
      boundary == 'copy' ? 'Copy encoded text' : 'Save encoded text',
    );
    await _waitUntil(
      () => _pageContains(
        driver,
        boundary == 'copy'
            ? 'The clipboard text could not be written.'
            : 'The URL encoded text could not be saved.',
      ),
      'URL safe output access error did not appear',
    );
    await _waitUntil(
      () async =>
          await driver.execute(_urlNoResultScript, const <Object?>[]) == true,
      'URL output access failure retained a result',
    );
    if (boundary == 'save') {
      await driver.execute(
        'URL.createObjectURL = window.__chimeraUrlOriginalCreateObjectURL;',
        const <Object?>[],
      );
    }
  }

  await _assertNoNetworkRequests(
    driver,
    flow: 'URL context/copy/save/validation',
  );
}

Future<void> _encodeCipher(WebDriver driver) async {
  await driver.get('http://127.0.0.1:4173');
  await _waitUntil(
    () async =>
        await driver.execute(
          "return document.querySelector('flt-semantics-placeholder') !== null;",
          const <Object?>[],
        ) ==
        true,
    'Cipher semantics placeholder did not load',
  );
  await _enableFlutterSemantics(driver);
  await _clickButton(driver, 'Encode with Cipher');
  await _waitUntil(
    () => _pageContains(driver, 'Text to encode'),
    'Cipher page did not open',
  );
  await _assertNoExternalRequests(driver, flow: 'cipher startup');
  await driver.execute(r'''
      window.__chimeraCipherCopiedText = null;
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: {
          writeText: async value => {
            window.__chimeraCipherCopiedText = value;
          },
        },
      });
      performance.clearResourceTimings();
    ''', const <Object?>[]);
  await _fillTextBox(driver, 'Text to encode', 'Attack!');
  await _selectMenuValue(driver, 'Cipher Caesar', 'Atbash');
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () async =>
        await driver.execute(r'''
            return [...document.querySelectorAll('[role="region"][tabindex="0"]')]
              .some(element => element.getAttribute('aria-label') ===
                'Cipher encoded result Cipher encoding succeeded.');
          ''', const <Object?>[]) ==
        true,
    'Cipher result semantics were incorrect',
  );
  await _clickButton(driver, 'Copy encoded text');
  await _waitUntil(
    () async =>
        await driver.execute(
          'return window.__chimeraCipherCopiedText === arguments[0];',
          const <Object?>['Zggzxp!'],
        ) ==
        true,
    'Cipher clipboard output was not exact',
  );

  await _fillTextBox(driver, 'Text to encode', 'Attack');
  await _selectMenuValue(driver, 'Cipher Atbash', 'Vigenere');
  await _fillTextBox(driver, 'Key (ASCII letters)', 'K3Y');
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () => _pageContains(driver, 'The cipher encoding request is invalid.'),
    'Cipher invalid-key validation did not appear',
  );
  var retained = await driver.execute(r'''
      return [...document.querySelectorAll('[role="region"]')]
        .some(element => (element.getAttribute('aria-label') || '')
          .startsWith('Cipher encoded result'));
    ''', const <Object?>[]);
  if (retained == true) {
    throw StateError('Cipher invalid-key validation retained a prior result');
  }

  await _fillTextBox(driver, 'Text to encode', 'A?B');
  await _selectMenuValue(driver, 'Cipher Vigenere', 'Atbash');
  await _selectMenuValue(
    driver,
    'Unsupported symbols Preserve unsupported symbols',
    'Reject unsupported symbols',
  );
  await _clickButton(driver, 'Encode');
  await _waitUntil(
    () => _pageContains(driver, 'The cipher encoding request is invalid.'),
    'Cipher unsupported-symbol validation did not appear',
  );
  retained = await driver.execute(r'''
      return [...document.querySelectorAll('[role="region"]')]
        .some(element => (element.getAttribute('aria-label') || '')
          .startsWith('Cipher encoded result'));
    ''', const <Object?>[]);
  if (retained == true) {
    throw StateError('Cipher validation retained a prior result');
  }
  await _assertNoNetworkRequests(driver, flow: 'cipher encode and validation');
}

Future<void> _selectMenuValue(
  WebDriver driver,
  String buttonLabel,
  String optionLabel,
) async {
  await _waitUntil(
    () async =>
        await driver.execute(
          r'''
            const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
            const expected = normalize(arguments[0]);
            const button = [...document.querySelectorAll('[role="button"]')]
              .find(element => normalize(element.getAttribute('aria-label') || element.textContent) === expected &&
                element.getAttribute('aria-disabled') !== 'true');
            if (!button) return false;
            button.click();
            return true;
          ''',
          <Object?>[buttonLabel],
        ) ==
        true,
    'Cipher selector did not open: $buttonLabel',
  );
  await _waitUntil(
    () async =>
        await driver.execute(
          r'''
            const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
            const expected = normalize(arguments[0]);
            const option = [...document.querySelectorAll('[role="menuitem"]')]
              .find(element => normalize(element.getAttribute('aria-label') || element.textContent) === expected &&
                element.getAttribute('aria-disabled') !== 'true');
            if (!option) return false;
            option.click();
            return true;
          ''',
          <Object?>[optionLabel],
        ) ==
        true,
    'Cipher selector option did not activate: $optionLabel',
  );
}

const _hashInvalidClipboardScript = r'''
return hashProbe('setup', String.fromCharCode(0xd800));
''';

const _hashFileReadyScript = r'''
return hashProbe('fileReady');
''';

Future<void> _generateHash(WebDriver driver, SafariProtocol protocol) async {
  final source = await File.fromUri(Platform.script.resolve('hash_browser.js'))
      .readAsString();
  final observer = await _loadGzipSaveObserver();
  final vectors = jsonDecode(
    await File.fromUri(
      Platform.script.resolve('../fixtures/hashes/vectors.json'),
    ).readAsString(),
  ) as List<dynamic>;
  var scenario = 'Hash';
  Future<T> stage<T>(String name, Future<T> Function() action) =>
      protocol.stage('$scenario / $name', action);
  Future<Object?> probe(String action, [Object? value]) => stage(
    'probe $action',
    () => driver.execute(
      '$source\nreturn hashProbe(arguments[0], arguments[1]);',
      <Object?>[action, value],
    ),
  );
  Future<void> openHash() async {
    await stage('navigation', () => driver.get('http://127.0.0.1:4173'));
    await stage(
      'semantics placeholder',
      () => _waitUntil(
        () async =>
            await driver.execute(
              "return document.querySelector('flt-semantics-placeholder') !== null;",
              const <Object?>[],
            ) ==
            true,
        'Hash semantics placeholder did not load',
      ),
    );
    await stage('enable semantics', () => _enableFlutterSemantics(driver));
    await stage('open feature', () => _clickButton(driver, 'Generate hash'));
    await stage(
      'feature ready',
      () => _waitUntil(
        () => _pageContains(driver, 'Text to hash (UTF-8)'),
        'Hash page did not open',
      ),
    );
    await _assertNoExternalRequests(driver, flow: 'Hash startup');
    await stage(
      'install save observer',
      () => driver.execute(
        '$observer\nobserveGzipSaves({suppressDownloads: true});',
        const <Object?>[],
      ),
    );
    await probe('setup', 'abc');
    // SafariDriver exposes no file chooser endpoint; dispatch a real File.
    await driver.execute(r'''
      const original = HTMLInputElement.prototype.click;
      HTMLInputElement.prototype.click = function() {
        if (this.type === 'file') return;
        return original.call(this);
      };
    ''', const <Object?>[]);
  }

  for (final algorithm in ['sha256', 'sha384', 'sha512', 'md5', 'sha1']) {
    for (final inputSource in ['clipboard', 'file', 'empty']) {
      scenario = 'Hash $algorithm $inputSource';
      stdout.writeln('Safari hash scenario: $algorithm $inputSource');
      await stage('scenario', () async {
        await openHash();
        final fixture = vectors.cast<Map<String, dynamic>>().singleWhere(
          (v) =>
              v['name'] ==
              (inputSource == 'empty'
                  ? 'empty'
                  : inputSource == 'file'
                  ? 'binary'
                  : 'abc'),
        );
        final expected =
            (fixture['digests'] as Map<String, dynamic>)[algorithm] as String;
        if (inputSource == 'clipboard') {
          await _clickButton(driver, 'Paste text');
          await _waitUntil(
            () => _inputHasValue(
              driver,
              'Text to hash (UTF-8)',
              'abc',
              focus: true,
            ),
            'Hash clipboard source missing',
          );
        }
        if (inputSource == 'file') {
          await _clickButton(driver, 'Choose local file bytes');
          await _waitUntil(
            () async => await probe('file', fixture['bytes']) == true,
            'Hash file input missing',
          );
          await _waitUntil(
            () async =>
                await driver.execute(
                  '$source\n$_hashFileReadyScript',
                  const <Object?>[],
                ) ==
                true,
            'Hash file loading did not finish',
          );
        }
        if (algorithm != 'sha256') {
          await _capturePageDiagnostics(
            driver,
            'hash-$algorithm-$inputSource-before-selector',
          );
          await _waitUntil(
            () async => await probe('openAlgorithm') == true,
            'Hash algorithm selector missing',
          );
          await _capturePageDiagnostics(
            driver,
            'hash-$algorithm-$inputSource-after-selector',
          );
          await _waitUntil(
            () async =>
                await probe('algorithm', algorithm.toUpperCase()) == true,
            'Hash algorithm choice missing',
          );
        }
        await _clickButton(driver, 'Generate hash');
        await _waitUntil(
          () async => await probe('result', expected) == true,
          'Hash known digest mismatch',
        );
        if (algorithm == 'md5' || algorithm == 'sha1') {
          await _waitUntil(
            () => _pageContains(driver, 'unsuitable for security decisions'),
            'Hash legacy security warning missing',
          );
        }
        await _waitUntil(
          () async => await probe('sourceCleared') == true,
          'Hash source retained',
        );
        await _waitUntil(
          () async => await probe('copy') == true,
          'Hash copy unavailable',
        );
        await _waitUntil(
          () async => await probe('copied', expected) == true,
          'Hash clipboard result mismatch',
        );
        await _clickButton(driver, 'Save digest');
        await _waitUntil(
          () async => await probe('saved', utf8.encode('$expected\n')) == true,
          'Hash saved bytes mismatch',
        );
        await _assertNoNetworkRequests(
          driver,
          flow: 'Hash $algorithm $inputSource',
        );
      });
    }
  }
  for (final failure in ['validation', 'file', 'read', 'copy', 'save']) {
    scenario = 'Hash failure $failure';
    stdout.writeln('Safari hash failure scenario: $failure');
    await stage('scenario', () async {
      await openHash();
      if (failure == 'file') {
        await probe('fileFailure');
        await _clickButton(driver, 'Choose local file bytes');
        await _waitUntil(
          () async => await probe('file', <int>[0, 255]) == true,
          'Hash failure file input missing',
        );
        await _waitUntil(
          () => _pageContains(driver, 'The local file could not be read.'),
          'Hash file access failure missing',
        );
      } else if (failure == 'validation') {
        await driver.execute(
          '$source\n$_hashInvalidClipboardScript',
          const <Object?>[],
        );
        await _clickButton(driver, 'Paste text');
        await _waitUntil(
          () => _pageContains(
            driver,
            'The hash algorithm or input source is invalid.',
          ),
          'Hash clipboard validation missing',
        );
      } else {
        if (failure != 'read') {
          await _clickButton(driver, 'Paste text');
          await _waitUntil(
            () => _inputHasValue(
              driver,
              'Text to hash (UTF-8)',
              'abc',
              focus: true,
            ),
            'Hash failure source missing',
          );
          await _clickButton(driver, 'Generate hash');
          await _waitUntil(
            () async =>
                await probe(
                  'result',
                  'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
                ) ==
                true,
            'Hash failure setup missing',
          );
        }
        await probe('${failure}Failure');
        await stage(
          'activate $failure',
          () => _clickButton(
            driver,
            failure == 'read'
                ? 'Paste text'
                : failure == 'copy'
                ? 'Copy digest'
                : 'Save digest',
          ),
        );
        await stage(
          'expected $failure error',
          () => _waitUntil(
            () => _pageContains(
              driver,
              failure == 'read'
                  ? 'Clipboard text could not be read.'
                  : failure == 'copy'
                  ? 'The digest could not be copied.'
                  : 'The digest could not be saved or written.',
            ),
            'Hash adapter failure missing',
          ),
        );
      }
      await _waitUntil(
        () async => await probe('noResult') == true,
        'Hash failure retained partial output',
      );
      await _waitUntil(
        () async => await probe('sourceCleared') == true,
        'Hash failure retained source',
      );
      await _assertNoNetworkRequests(driver, flow: 'Hash $failure failure');
    });
  }
}

// Create invalid UTF-16 after WebDriver has decoded its well-formed request.
const _checksumInvalidClipboardScript = r'''
return checksumProbe('setup', String.fromCharCode(0xd800));
''';

const _checksumFileReadyScript = r'''
return checksumProbe('fileReady');
''';

Future<void> _generateChecksum(WebDriver driver) async {
  final source = await File.fromUri(
    Platform.script.resolve('checksum_browser.js'),
  ).readAsString();
  final observer = await _loadGzipSaveObserver();
  final vectors = jsonDecode(
    await File.fromUri(
      Platform.script.resolve('../fixtures/checksums/vectors.json'),
    ).readAsString(),
  ) as List<dynamic>;
  Future<Object?> probe(String action, [Object? value]) => driver.execute(
    '$source\nreturn checksumProbe(arguments[0], arguments[1]);',
    <Object?>[action, value],
  );
  Future<void> openChecksum() async {
    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Checksum semantics placeholder did not load',
    );
    await _enableFlutterSemantics(driver);
    await _clickButton(driver, 'Generate checksum');
    await _waitUntil(
      () => _pageContains(driver, 'Text for checksum (UTF-8)'),
      'Checksum page did not open',
    );
    await _assertNoExternalRequests(driver, flow: 'Checksum startup');
    await driver.execute(
      '$observer\nobserveGzipSaves({suppressDownloads: true});',
      const <Object?>[],
    );
    await probe('setup', 'abc');
    // SafariDriver exposes no file chooser endpoint; dispatch a real File.
    await driver.execute(r'''
      const original = HTMLInputElement.prototype.click;
      HTMLInputElement.prototype.click = function() {
        if (this.type === 'file') return;
        return original.call(this);
      };
    ''', const <Object?>[]);
  }

  for (final algorithm in ['crc32', 'adler32']) {
    for (final inputSource in ['clipboard', 'file', 'empty', 'allbytes']) {
      stdout.writeln('Safari checksum scenario: $algorithm $inputSource');
      await openChecksum();
      final fixture = vectors.cast<Map<String, dynamic>>().singleWhere(
        (v) =>
            v['name'] ==
            (inputSource == 'allbytes'
                ? 'allbytes'
                : inputSource == 'empty'
                ? 'empty'
                : inputSource == 'file'
                ? 'binary'
                : 'abc'),
      );
      final expected =
          (fixture['checksums'] as Map<String, dynamic>)[algorithm] as String;
      if (inputSource == 'clipboard') {
        await _clickButton(driver, 'Paste text');
        await _waitUntil(
          () => _inputHasValue(
            driver,
            'Text for checksum (UTF-8)',
            'abc',
            focus: true,
          ),
          'Checksum clipboard source missing',
        );
      }
      if (inputSource == 'file' || inputSource == 'allbytes') {
        await _clickButton(driver, 'Choose local file bytes');
        await _waitUntil(
          () async => await probe('file', fixture['bytes']) == true,
          'Checksum file input missing',
        );
        await _waitUntil(
          () async =>
              await driver.execute(
                '$source\n$_checksumFileReadyScript',
                const <Object?>[],
              ) ==
              true,
          'Checksum file loading did not finish',
        );
      }
      if (algorithm != 'crc32') {
        await _waitUntil(
          () async => await probe('openAlgorithm') == true,
          'Checksum algorithm selector missing',
        );
        await _waitUntil(
          () async => await probe('algorithm', algorithm.toUpperCase()) == true,
          'Checksum algorithm choice missing: $algorithm $inputSource',
        );
      }
      await _clickButton(driver, 'Generate checksum');
      await _waitUntil(
        () async => await probe('result', expected) == true,
        'Checksum known checksum mismatch',
      );
      await _waitUntil(
        () async => await probe('sourceCleared') == true,
        'Checksum source retained',
      );
      await _waitUntil(
        () async => await probe('copy') == true,
        'Checksum copy unavailable',
      );
      await _waitUntil(
        () async => await probe('copied', expected) == true,
        'Checksum clipboard result mismatch',
      );
      await _clickButton(driver, 'Save checksum');
      await _waitUntil(
        () async => await probe('saved', utf8.encode('$expected\n')) == true,
        'Checksum saved bytes mismatch',
      );
      await _assertNoNetworkRequests(
        driver,
        flow: 'Checksum $algorithm $inputSource',
      );
    }
  }
  for (final failure in ['validation', 'file', 'read', 'copy', 'save']) {
    stdout.writeln('Safari checksum failure scenario: $failure');
    await openChecksum();
    if (failure == 'file') {
      await probe('fileFailure');
      await _clickButton(driver, 'Choose local file bytes');
      await _waitUntil(
        () async => await probe('file', <int>[0, 255]) == true,
        'Checksum failure file input missing',
      );
      await _waitUntil(
        () => _pageContains(driver, 'The local file could not be read.'),
        'Checksum file access failure missing',
      );
    } else if (failure == 'validation') {
      await driver.execute(
        '$source\n$_checksumInvalidClipboardScript',
        const <Object?>[],
      );
      await _clickButton(driver, 'Paste text');
      await _waitUntil(
        () => _pageContains(
          driver,
          'The checksum algorithm or input source is invalid.',
        ),
        'Checksum clipboard validation missing',
      );
    } else {
      if (failure != 'read') {
        await _clickButton(driver, 'Paste text');
        await _waitUntil(
          () => _inputHasValue(
            driver,
            'Text for checksum (UTF-8)',
            'abc',
            focus: true,
          ),
          'Checksum failure source missing',
        );
        await _clickButton(driver, 'Generate checksum');
        await _waitUntil(
          () async => await probe('result', '352441c2') == true,
          'Checksum failure setup missing',
        );
      }
      await probe('${failure}Failure');
      await _clickButton(
        driver,
        failure == 'read'
            ? 'Paste text'
            : failure == 'copy'
            ? 'Copy checksum'
            : 'Save checksum',
      );
      await _waitUntil(
        () => _pageContains(
          driver,
          failure == 'read'
              ? 'Clipboard text could not be read.'
              : failure == 'copy'
              ? 'The checksum could not be copied.'
              : 'The checksum could not be saved or written.',
        ),
        'Checksum adapter failure missing',
      );
    }
    await _waitUntil(
      () async => await probe('noResult') == true,
      'Checksum failure retained partial output',
    );
    await _waitUntil(
      () async => await probe('sourceCleared') == true,
      'Checksum failure retained source',
    );
    await _assertNoNetworkRequests(driver, flow: 'Checksum $failure failure');
  }
}

// Keep new operations outside the JWT inspection helper interval.
Future<void> _generateLorem(WebDriver driver) async {
  final source = await File.fromUri(Platform.script.resolve('lorem_browser.js'))
      .readAsString();
  final observer = await _loadGzipSaveObserver();
  Future<Object?> probe(String action, [Object? value]) => driver.execute(
    '$source\nreturn loremProbe(arguments[0], arguments[1]);',
    <Object?>[action, value],
  );
  Future<void> openLorem() async {
    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Lorem semantics placeholder missing',
    );
    await _enableFlutterSemantics(driver);
    await _clickButton(driver, 'Generate Lorem Ipsum');
    await _waitUntil(
      () => _pageContains(driver, 'Positive integer count'),
      'Lorem configuration missing',
    );
    await _assertNoExternalRequests(driver, flow: 'Lorem startup');
    await driver.execute(
      '$observer\nobserveGzipSaves({suppressDownloads: true});',
      const <Object?>[],
    );
    await probe('setup');
  }

  const paragraph = 'Lorem ipsum dolor sit amet. Consectetur adipiscing elit.';
  for (final unit in ['words', 'sentences', 'paragraphs']) {
    await openLorem();
    if (unit != 'paragraphs') {
      await _waitUntil(
        () async => await probe('openUnit') == true,
        'Lorem unit selector missing',
      );
      await _waitUntil(
        () async =>
            await probe('unit', unit == 'words' ? 'Words' : 'Sentences') ==
            true,
        'Lorem unit choice missing',
      );
    }
    await _fillTextBox(driver, 'Positive integer count', '2');
    await _clickButton(driver, 'Generate text');
    final expected = unit == 'words'
        ? 'Lorem ipsum'
        : unit == 'sentences'
        ? paragraph
        : '$paragraph\n\n$paragraph';
    await _waitUntil(
      () async => await probe('result', expected) == true,
      'Lorem exact generated result mismatch',
    );
    await _waitUntil(
      () async => await probe('copy') == true,
      'Lorem copy unavailable',
    );
    await _waitUntil(
      () async => await probe('copied', expected) == true,
      'Lorem clipboard mismatch',
    );
    await _clickButton(driver, 'Save UTF-8 text');
    await _waitUntil(
      () async => await probe('saved', utf8.encode(expected)) == true,
      'Lorem saved UTF-8 mismatch',
    );
    await _fillTextBox(driver, 'Positive integer count', '3');
    await _waitUntil(
      () async => await probe('noResult') == true,
      'Lorem stale result retained after configuration changed',
    );
    await _assertNoNetworkRequests(driver, flow: 'Lorem $unit');
  }
  for (final failure in ['validation', 'copy', 'save']) {
    await openLorem();
    if (failure == 'validation') {
      await _fillTextBox(driver, 'Positive integer count', '0');
    }
    await _clickButton(driver, 'Generate text');
    if (failure != 'validation') {
      await _waitUntil(
        () async => await probe('result', paragraph) == true,
        'Lorem default paragraph mismatch',
      );
      await probe('${failure}Failure');
      await _clickButton(
        driver,
        failure == 'copy' ? 'Copy text' : 'Save UTF-8 text',
      );
    }
    await _waitUntil(
      () => _pageContains(
        driver,
        failure == 'validation'
            ? 'Choose words, sentences or paragraphs and a positive integer count.'
            : failure == 'copy'
            ? 'The generated text could not be copied.'
            : 'The generated text could not be saved or written.',
      ),
      'Lorem localized failure missing',
    );
    await _waitUntil(
      () async => await probe('noResult') == true,
      'Lorem partial result survived failure',
    );
    await _assertNoNetworkRequests(driver, flow: 'Lorem $failure failure');
  }
}

Future<void> _generatePassword(WebDriver driver) async {
  final source = await File.fromUri(
    Platform.script.resolve('password_browser.js'),
  ).readAsString();
  final observer = await _loadGzipSaveObserver();
  Future<Object?> probe(String action, [Object? value]) => driver.execute(
    '$source\nreturn passwordProbe(arguments[0], arguments[1]);',
    <Object?>[action, value],
  );
  Future<void> openPassword() async {
    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Password semantics placeholder missing',
    );
    await _enableFlutterSemantics(driver);
    await _clickButton(driver, 'Generate Password');
    await _waitUntil(
      () => _pageContains(driver, 'Positive integer length'),
      'Password configuration missing',
    );
    await _assertNoExternalRequests(driver, flow: 'Password startup');
    await driver.execute(
      '$observer\nobserveGzipSaves({suppressDownloads: true});',
      const <Object?>[],
    );
    await probe('setup');
  }

  await openPassword();
  await _clickButton(driver, 'Generate password');
  String? password;
  await _waitUntil(() async {
    final value = await probe('result');
    if (value is! String) return false;
    password = value;
    return true;
  }, 'Password result missing');
  if (password!.length != 16 ||
      !RegExp('[a-z]').hasMatch(password!) ||
      !RegExp('[A-Z]').hasMatch(password!) ||
      !RegExp('[0-9]').hasMatch(password!) ||
      !RegExp(r'[!@#$%^&*()\-_=+\[\]{}:,.?]').hasMatch(password!)) {
    throw StateError('Password default constraints were not satisfied');
  }
  await _waitUntil(
    () async => await probe('copy') == true,
    'Password copy unavailable',
  );
  await _waitUntil(
    () async => await probe('copied', password) == true,
    'Password clipboard mismatch',
  );
  await _clickButton(driver, 'Save password');
  await _waitUntil(
    () async => await probe('saved', utf8.encode(password!)) == true,
    'Password saved bytes mismatch',
  );
  await _fillTextBox(driver, 'Positive integer length', '20');
  await _waitUntil(
    () async => await probe('noResult') == true,
    'Password remained after configuration changed',
  );
  await _assertNoNetworkRequests(driver, flow: 'Password defaults');

  await openPassword();
  for (final name in ['Lowercase letters', 'Uppercase letters', 'Symbols']) {
    await _waitUntil(
      () async => await probe('toggle', name) == true,
      'Password $name toggle unavailable',
    );
  }
  await _fillTextBox(driver, 'Positive integer length', '8');
  await _clickButton(driver, 'Generate password');
  await _waitUntil(() async {
    final value = await probe('result');
    return value is String && RegExp(r'^\d{8}$').hasMatch(value);
  }, 'Password digit-only constraints were not satisfied');
  await _assertNoNetworkRequests(driver, flow: 'Password digits');

  for (final failure in [
    'validation',
    'processing',
    'resource',
    'copy',
    'save',
  ]) {
    await openPassword();
    if (failure == 'validation') {
      await _fillTextBox(driver, 'Positive integer length', '3');
    }
    if (failure == 'resource') {
      await _fillTextBox(driver, 'Positive integer length', '4294967296');
    }
    if (failure == 'processing') await probe('entropyFailure');
    await _clickButton(driver, 'Generate password');
    if (failure == 'copy' || failure == 'save') {
      await _waitUntil(
        () async => await probe('result') is String,
        'Password default result missing',
      );
      await probe('${failure}Failure');
      await _clickButton(
        driver,
        failure == 'copy' ? 'Copy password' : 'Save password',
      );
    }
    await _waitUntil(
      () => _pageContains(driver, switch (failure) {
        'validation' => 'Choose a positive integer length that can include every selected character class, and select at least one class.',
        'processing' =>
          'Secure random generation failed. No password was produced.',
        'resource' => 'Password generation exceeded available resources.',
        'copy' => 'The generated password could not be copied.',
        _ => 'The generated password could not be saved or written.',
      }),
      'Password localized failure missing',
    );
    await _waitUntil(
      () async => await probe('noResult') == true,
      'Password partial result survived failure',
    );
    await _assertNoNetworkRequests(driver, flow: 'Password $failure failure');
  }
}

Future<void> _generateUuid(WebDriver driver) async {
  final source = await File.fromUri(Platform.script.resolve('uuid_browser.js'))
      .readAsString();
  final observer = await _loadGzipSaveObserver();
  Future<Object?> probe(String action, [Object? value]) => driver.execute(
    '$source\nreturn uuidProbe(arguments[0], arguments[1]);',
    <Object?>[action, value],
  );
  Future<void> openUuid() async {
    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') !== null;",
            const <Object?>[],
          ) ==
          true,
      'UUID semantics placeholder missing',
    );
    await _enableFlutterSemantics(driver);
    await _clickButton(driver, 'Generate UUID or GUID');
    await _waitUntil(
      () => _pageContains(driver, 'Positive integer count'),
      'UUID configuration missing',
    );
    await _assertNoExternalRequests(driver, flow: 'UUID startup');
    await driver.execute(
      '$observer\nobserveGzipSaves({suppressDownloads: true});',
      const <Object?>[],
    );
    await probe('setup');
  }

  await openUuid();
  await _clickButton(driver, 'Generate identifiers');
  String? identifier;
  await _waitUntil(() async {
    final value = await probe('result');
    if (value is! String) return false;
    identifier = value;
    return true;
  }, 'UUID result missing');
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(identifier!)) {
    throw StateError('UUID v4 shape is invalid');
  }
  await _waitUntil(
    () async => await probe('copy') == true,
    'UUID copy unavailable',
  );
  await _waitUntil(
    () async => await probe('copied', identifier) == true,
    'UUID clipboard mismatch',
  );
  await _clickButton(driver, 'Save identifiers');
  await _waitUntil(
    () async => await probe('saved', utf8.encode(identifier!)) == true,
    'UUID saved bytes mismatch',
  );
  await _fillTextBox(driver, 'Positive integer count', '2');
  await _waitUntil(
    () async => await probe('noResult') == true,
    'UUID remained after configuration changed',
  );
  await _assertNoNetworkRequests(driver, flow: 'UUID defaults');

  await openUuid();
  await _waitUntil(
    () async => await probe('openVersion') == true,
    'UUID version selector unavailable',
  );
  await _waitUntil(
    () async => await probe('option', 'Version 7 (time ordered)') == true,
    'UUID v7 option unavailable',
  );
  await _waitUntil(
    () async => await probe('openRepresentation') == true,
    'UUID representation selector unavailable',
  );
  await _waitUntil(
    () async => await probe('option', 'GUID (uppercase braces)') == true,
    'GUID option unavailable',
  );
  await _fillTextBox(driver, 'Positive integer count', '2');
  final beforeGeneration = DateTime.now().millisecondsSinceEpoch;
  await _clickButton(driver, 'Generate identifiers');
  await _waitUntil(() async {
    final value = await probe('result');
    if (value is! String) return false;
    final identifiers = RegExp(r'\{[0-9A-F-]+\}').allMatches(value).toList();
    return identifiers.length == 2 &&
        identifiers.map((match) => match.group(0)).toSet().length == 2 &&
        identifiers.every((match) {
          final identifier = match.group(0)!;
          final shape = RegExp(
            r'^\{[0-9A-F]{8}-[0-9A-F]{4}-7[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}\}$',
          ).hasMatch(identifier);
          final timestamp = int.parse(
            identifier.substring(1, 14).replaceAll('-', ''),
            radix: 16,
          );
          return shape &&
              timestamp >= beforeGeneration &&
              timestamp <= DateTime.now().millisecondsSinceEpoch;
        });
  }, 'UUID v7 GUID batch was invalid');
  final guidBatch = RegExp(r'\{[0-9A-F-]+\}')
      .allMatches(await probe('result') as String)
      .map((match) => match.group(0)!)
      .join('\n');
  await _waitUntil(
    () async => await probe('copy') == true,
    'UUID v7 GUID copy unavailable',
  );
  await _waitUntil(
    () async => await probe('copied', guidBatch) == true,
    'UUID v7 GUID clipboard mismatch',
  );
  await _clickButton(driver, 'Save identifiers');
  await _waitUntil(
    () async => await probe('saved', utf8.encode(guidBatch)) == true,
    'UUID v7 GUID saved bytes mismatch',
  );
  await _assertNoNetworkRequests(driver, flow: 'UUID v7 GUID');

  for (final failure in ['validation', 'processing', 'copy', 'save']) {
    await openUuid();
    if (failure == 'validation') {
      await _fillTextBox(driver, 'Positive integer count', '0');
    }
    if (failure == 'processing') await probe('entropyFailure');
    await _clickButton(driver, 'Generate identifiers');
    if (failure == 'copy' || failure == 'save') {
      await _waitUntil(
        () async => await probe('result') is String,
        'UUID default result missing',
      );
      await probe('${failure}Failure');
      await _clickButton(
        driver,
        failure == 'copy' ? 'Copy identifiers' : 'Save identifiers',
      );
    }
    await _waitUntil(
      () => _pageContains(driver, switch (failure) {
        'validation' => 'Choose version 4 or 7, UUID or GUID representation, and a positive integer count.',
        'processing' =>
          'Secure identifier generation failed. No identifiers were produced.',
        'copy' => 'The generated identifiers could not be copied.',
        _ => 'The generated identifiers could not be saved or written.',
      }),
      'UUID localized failure missing',
    );
    await _waitUntil(
      () async => await probe('noResult') == true,
      'UUID partial result survived failure',
    );
    await _assertNoNetworkRequests(driver, flow: 'UUID $failure failure');
  }
}

Future<void> _generateCard(WebDriver driver) async {
  final source = await File.fromUri(Platform.script.resolve('card_browser.js'))
      .readAsString();
  final observer = await _loadGzipSaveObserver();
  Future<Object?> probe(String action, [Object? value]) => driver.execute(
    '$source\nreturn cardProbe(arguments[0], arguments[1]);',
    <Object?>[action, value],
  );
  Future<void> openCard() async {
    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Card semantics placeholder missing',
    );
    await _enableFlutterSemantics(driver);
    await _clickButton(driver, 'Generate Synthetic Cards');
    await _waitUntil(
      () => _pageContains(driver, 'Positive integer count'),
      'Card configuration missing',
    );
    await _assertNoExternalRequests(driver, flow: 'Card startup');
    await driver.execute(
      '$observer\nobserveGzipSaves({suppressDownloads: true});',
      const <Object?>[],
    );
    await probe('setup');
  }

  await openCard();
  await _fillTextBox(driver, 'Positive integer count', '2');
  await _clickButton(driver, 'Generate synthetic cards');
  await _waitUntil(
    () => _pageContains(
      driver,
      'Synthetic test data - not for real transactions',
    ),
    'Synthetic card warning missing',
  );
  String? values;
  await _waitUntil(() async {
    final value = await probe('values');
    if (value is! String) return false;
    values = value;
    final cards = value.split('\n');
    return cards.length == 2 &&
        cards.every(
          const {
            '4005520201264821',
            '4242424242424242',
            '4000056655665556',
          }.contains,
        );
  }, 'Safe Visa sandbox value missing');
  final transferred =
      'Synthetic test data - not for real transactions\n$values';
  await _waitUntil(
    () async => await probe('copy') == true,
    'Card copy unavailable',
  );
  await _waitUntil(
    () async => await probe('copied', transferred) == true,
    'Card clipboard mismatch',
  );
  await _clickButton(driver, 'Save labeled card data');
  await _waitUntil(
    () async => await probe('saved', utf8.encode(transferred)) == true,
    'Card saved bytes mismatch',
  );
  await _fillTextBox(driver, 'Positive integer count', '3');
  await _waitUntil(
    () async => await probe('noResult') == true,
    'Card result remained after configuration changed',
  );
  await _assertNoNetworkRequests(driver, flow: 'Card defaults');

  for (final network in const {
    'Visa': {'4005520201264821', '4242424242424242', '4000056655665556'},
    'Mastercard': {'5500005555555559', '5555555555554444', '2223003122003222'},
    'American Express': {
      '340353278080900',
      '378282246310005',
      '371449635398431',
    },
    'Discover': {'6011003179988686', '6011111111111117', '6011000990139424'},
  }.entries) {
    await openCard();
    await _waitUntil(
      () async => await probe('openNetwork') == true,
      'Card network selector unavailable',
    );
    await _waitUntil(
      () async => await probe('option', network.key) == true,
      '${network.key} option unavailable',
    );
    await _clickButton(driver, 'Generate synthetic cards');
    await _waitUntil(() async {
      final value = await probe('values');
      return value is String && network.value.contains(value);
    }, '${network.key} sandbox value missing');
    await _assertNoNetworkRequests(driver, flow: 'Card ${network.key}');
  }

  for (final failure in ['validation', 'processing', 'copy', 'save']) {
    await openCard();
    if (failure == 'validation') {
      await _fillTextBox(driver, 'Positive integer count', '0');
    }
    if (failure == 'processing') await probe('entropyFailure');
    await _clickButton(driver, 'Generate synthetic cards');
    if (failure == 'copy' || failure == 'save') {
      await _waitUntil(
        () async => await probe('values') is String,
        'Card default result missing',
      );
      await probe('${failure}Failure');
      await _clickButton(
        driver,
        failure == 'copy' ? 'Copy labeled card data' : 'Save labeled card data',
      );
    }
    await _waitUntil(
      () => _pageContains(driver, switch (failure) {
        'validation' => 'Choose Visa, Mastercard, American Express, or Discover and a positive integer count.',
        'processing' =>
          'Synthetic card generation failed. No card numbers were produced.',
        'copy' => 'The synthetic card result could not be copied.',
        _ => 'The synthetic card result could not be written.',
      }),
      'Card localized failure missing',
    );
    await _waitUntil(
      () async => await probe('noResult') == true,
      'Card partial result survived failure',
    );
    await _assertNoNetworkRequests(driver, flow: 'Card $failure failure');
  }
}

Future<void> _generateIdentityDocument(WebDriver driver) async {
  final source = await File.fromUri(
    Platform.script.resolve('identity_document_browser.js'),
  ).readAsString();
  final observer = await _loadGzipSaveObserver();
  Future<Object?> probe(String action, [Object? value]) => driver.execute(
    '$source\nreturn identityDocumentProbe(arguments[0], arguments[1]);',
    <Object?>[action, value],
  );
  Future<void> openDocument() async {
    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Identity document semantics placeholder missing',
    );
    await _enableFlutterSemantics(driver);
    await _clickButton(driver, 'Generate Synthetic Identity Documents');
    await _waitUntil(
      () => _pageContains(driver, 'Positive integer count'),
      'Identity document configuration missing',
    );
    await _assertNoExternalRequests(driver, flow: 'Identity document startup');
    await driver.execute(
      '$observer\nobserveGzipSaves({suppressDownloads: true});',
      const <Object?>[],
    );
    await probe('setup');
  }

  Future<void> select(String field, String option) async {
    await _waitUntil(
      () async => await probe('openSelect', field) == true,
      '$field selector unavailable',
    );
    await _waitUntil(
      () async => await probe('option', option) == true,
      '$option option unavailable',
    );
  }

  await openDocument();
  await _fillTextBox(driver, 'Positive integer count', '2');
  await _clickButton(driver, 'Generate synthetic documents');
  await _waitUntil(
    () => _pageContains(
      driver,
      'Synthetic identity test data - not proof of issuance',
    ),
    'Synthetic identity warning missing',
  );
  await _waitUntil(
    () async => await probe('values') == '219-09-9999\n219-09-9999',
    'SSA specimen batch missing',
  );
  const transferred =
      'Synthetic identity test data - not proof of issuance\n'
      '219-09-9999\n219-09-9999';
  await _waitUntil(
    () async => await probe('copy') == true,
    'Identity document copy unavailable',
  );
  await _waitUntil(
    () async => await probe('copied', transferred) == true,
    'Identity document clipboard mismatch',
  );
  await _clickButton(driver, 'Save labeled identity data');
  await _waitUntil(
    () async => await probe('saved', utf8.encode(transferred)) == true,
    'Identity document saved bytes mismatch',
  );
  await _fillTextBox(driver, 'Positive integer count', '3');
  await _waitUntil(
    () async => await probe('noResult') == true,
    'Identity document result remained after configuration changed',
  );
  await _assertNoNetworkRequests(driver, flow: 'Identity document defaults');

  for (final format in ['Numeric', 'Alphanumeric']) {
    await openDocument();
    await select('Country or locale', 'Brazil');
    await select('Document type', 'CNPJ');
    await select('CNPJ format', format);
    await _clickButton(driver, 'Generate synthetic documents');
    await _waitUntil(() async {
      final value = await probe('values');
      if (value is! String) return false;
      return format == 'Numeric'
          ? RegExp(r'^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$').hasMatch(value)
          : RegExp(r'^[0-9A-Z]{2}\.[0-9A-Z]{3}\.[0-9A-Z]{3}/[0-9A-Z]{4}-\d{2}$')
                .hasMatch(value);
    }, '$format CNPJ value missing');
    await _assertNoNetworkRequests(driver, flow: '$format CNPJ');
  }

  for (final failure in ['validation', 'processing', 'copy', 'save']) {
    await openDocument();
    if (failure == 'validation') {
      await _fillTextBox(driver, 'Positive integer count', '0');
    }
    if (failure == 'processing') {
      await select(
        'Document type',
        'Individual Taxpayer Identification Number (ITIN)',
      );
      await probe('entropyFailure');
    }
    await _clickButton(driver, 'Generate synthetic documents');
    if (failure == 'copy' || failure == 'save') {
      await _waitUntil(
        () async => await probe('values') is String,
        'Identity document default result missing',
      );
      await probe('${failure}Failure');
      await _clickButton(
        driver,
        failure == 'copy'
            ? 'Copy labeled identity data'
            : 'Save labeled identity data',
      );
    }
    await _waitUntil(
      () => _pageContains(driver, switch (failure) {
        'validation' => 'Choose a supported locale and document type, compatible options, and a positive integer count.',
        'processing' => 'Synthetic identity document generation failed. No document values were produced.',
        'copy' => 'The synthetic identity document result could not be copied.',
        _ => 'The synthetic identity document result could not be written.',
      }),
      'Identity document localized failure missing',
    );
    await _waitUntil(
      () async => await probe('noResult') == true,
      'Identity document partial result survived failure',
    );
    await _assertNoNetworkRequests(
      driver,
      flow: 'Identity document $failure failure',
    );
  }
}

Future<void> _generatePerson(WebDriver driver) async {
  final source = await File.fromUri(
    Platform.script.resolve('person_browser.js'),
  ).readAsString();
  final observer = await _loadGzipSaveObserver();
  Future<Object?> probe(String action, [Object? value]) => driver.execute(
    '$source\nreturn personProbe(arguments[0], arguments[1]);',
    <Object?>[action, value],
  );
  Future<void> openPerson() async {
    await driver.get('http://127.0.0.1:4173');
    await _waitUntil(
      () async =>
          await driver.execute(
            "return document.querySelector('flt-semantics-placeholder') !== null;",
            const <Object?>[],
          ) ==
          true,
      'Person semantics placeholder missing',
    );
    await _enableFlutterSemantics(driver);
    await _clickButton(driver, 'Generate Synthetic People');
    await _waitUntil(
      () => _pageContains(driver, 'Positive integer count'),
      'Person configuration missing',
    );
    await _assertNoExternalRequests(driver, flow: 'Person startup');
    await driver.execute(
      '$observer\nobserveGzipSaves({suppressDownloads: true});',
      const <Object?>[],
    );
    await probe('setup');
  }

  Future<void> select(String field, String option) async {
    await _waitUntil(
      () async => await probe('openSelect', field) == true,
      '$field selector unavailable',
    );
    await _waitUntil(
      () async => await probe('option', option) == true,
      '$option option unavailable',
    );
  }

  await openPerson();
  await _fillTextBox(driver, 'Positive integer count', '2');
  await _clickButton(driver, 'Generate synthetic people');
  await _waitUntil(() async {
    final value = await probe('result');
    return value is String &&
        value.contains(
          'Synthetic person test data - not a real identity or proof of issuance',
        ) &&
        value.contains('Person 1 Name:') &&
        value.contains('Person 2 Name:') &&
        value.contains('@example.com') &&
        value.contains('SSN:');
  }, 'Synthetic person batch missing');
  await _waitUntil(
    () async => await probe('copy') == true,
    'Person copy unavailable',
  );
  late String transferred;
  await _waitUntil(() async {
    final value = await probe('copied');
    if (value is! String ||
        !value.startsWith(
          'Synthetic person test data - not a real identity or proof of issuance\nPerson 1',
        )) {
      return false;
    }
    transferred = value;
    return true;
  }, 'Person clipboard mismatch');
  await _clickButton(driver, 'Save labeled person data');
  await _waitUntil(
    () async => await probe('saved', utf8.encode(transferred)) == true,
    'Person saved bytes mismatch',
  );
  await _fillTextBox(driver, 'Positive integer count', '3');
  await _waitUntil(
    () async => await probe('noResult') == true,
    'Person result remained after configuration changed',
  );
  await _assertNoNetworkRequests(driver, flow: 'Person defaults');

  await openPerson();
  await select('Country or locale', 'Brazil');
  await _fillTextBox(driver, 'Minimum age (0-130)', '21');
  await _fillTextBox(driver, 'Maximum age (0-130)', '40');
  await _clickButton(driver, 'Generate synthetic people');
  await _waitUntil(() async {
    final value = await probe('result');
    return value is String &&
        value.contains('+55 (') &&
        value.contains('CPF:') &&
        value.contains('CIN:');
  }, 'Brazil synthetic person missing');
  await _assertNoNetworkRequests(driver, flow: 'Brazil person');

  for (final failure in ['validation', 'processing', 'copy', 'save']) {
    await openPerson();
    if (failure == 'validation') {
      await _fillTextBox(driver, 'Positive integer count', '0');
    }
    if (failure == 'processing') await probe('entropyFailure');
    await _clickButton(driver, 'Generate synthetic people');
    if (failure == 'copy' || failure == 'save') {
      await _waitUntil(
        () async => await probe('result') is String,
        'Person default result missing',
      );
      await probe('${failure}Failure');
      await _clickButton(
        driver,
        failure == 'copy'
            ? 'Copy labeled person data'
            : 'Save labeled person data',
      );
    }
    await _waitUntil(
      () => _pageContains(driver, switch (failure) {
        'validation' => 'Choose a supported locale, ages from 0 through 130 in ascending order, and a positive integer count.',
        'processing' => 'Synthetic person generation failed. No partial people were produced.',
        'copy' => 'The synthetic person result could not be copied.',
        _ => 'The synthetic person result could not be written.',
      }),
      'Person localized failure missing',
    );
    await _waitUntil(
      () async => await probe('noResult') == true,
      'Person partial result survived failure',
    );
    await _assertNoNetworkRequests(driver, flow: 'Person $failure failure');
  }
}
