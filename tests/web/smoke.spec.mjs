import { expect, test } from '@playwright/test';
import { createHmac, generateKeyPairSync, sign, verify } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { networkPolicyCases, networkRequestPolicyScript, unexpectedHttpRequests } from './network_policy.mjs';

for (const value of networkPolicyCases) {
  test(`GivenNetworkPolicy${value.name}_WhenRequestsAreChecked_ThenOnlyUnexpectedRequestsRemain`, async ({ page }) => {
    const actual = await page.evaluate(({ script, value }) =>
      new Function(script)(value.urls, value.applicationUrl, value.allow),
    { script: networkRequestPolicyScript, value });
    expect(actual).toEqual(value.expected);
  });
}

// The native Safari harness executes this exact source, resolved from its script.
const gzipSaveObserver = readFileSync(new URL('./gzip_save_observer.js', import.meta.url), 'utf8');

// Run the native Safari helper's actual observation body against Flutter.
const safariHarness = readFileSync(new URL('./safari_smoke.dart', import.meta.url), 'utf8');
const safariCronDiagnostics = readFileSync(new URL('./safari_cron_diagnostics.js', import.meta.url), 'utf8');
const safariTextBoxElementScript = safariHarness.match(/const _textBoxElementScript = r'''([\s\S]*?)''';/)[1];
const safariInputObservation = safariHarness
  .split('Future<bool> _inputHasValue(')[1]
  .match(/driver\.execute\(\s*'''([\s\S]*?)'''/)[1];
const safariGzipScripts = [...safariHarness.split('Future<void> _compressGzip(')[1]
  .split('Future<void> _convertCertificate(')[0].matchAll(/r?'''([\s\S]*?)'''/g)].map(match => match[1]);
const safariLevelOpening = safariGzipScripts.find(source => source.includes('Compression level 6'));
const safariLevelSelection = safariGzipScripts.find(source => source.includes('[role="menuitem"]'));
const safariGzipCopyActivation = safariHarness
  .split('Future<void> _activateGzipCopyButton(')[1]
  ?.match(/driver\.execute\(\s*'''([\s\S]*?)'''/)?.[1] ?? '';
const safariCopiedTextObservation = safariHarness
  .split('Future<List<int>?> _copiedTextCodeUnits(')[1]
  ?.match(/driver\.execute\(\s*'''([\s\S]*?)'''/)?.[1] ?? '';

const safariUrlScripts = Object.fromEntries([...safariHarness.matchAll(
  /const _url(\w+)Script = r'''([\s\S]*?)''';/g,
)].map(([, name, source]) => [name, source]));
async function urlScript(page, name, ...args) {
  expect(safariUrlScripts[name], `Safari URL ${name} helper`).toBeTruthy();
  return page.evaluate(({ source, args }) => new Function(source)(...args), {
    source: safariUrlScripts[name], args,
  });
}

for (const scenario of [
  { mode: 'component', source: 'typed', expected: "%26%3C%3E%22'%2F%20%26amp%3B%20Ol%C3%A1%20%F0%9F%8C%8D" },
  { mode: 'Full value', source: 'file', expected: "&%3C%3E%22'/%20&amp;%20Ol%C3%A1%20%F0%9F%8C%8D" },
  { mode: 'component', source: 'clipboard', expected: "%26%3C%3E%22'%2F%20%26amp%3B%20Ol%C3%A1%20%F0%9F%8C%8D" },
  { mode: 'Full value', source: 'typed', expected: "&%3C%3E%22'/%20&amp;%20Ol%C3%A1%20%F0%9F%8C%8D" },
  { mode: 'component', source: 'empty', expected: '' },
]) {
  test(`GivenUrl${scenario.mode}${scenario.source}_WhenEncodedCopiedAndSaved_ThenExactEntitiesTransferOffline`, async ({ page }) => {
    const externalRequests = [];
    const interactionRequests = [];
    const downloads = [];
    page.on('download', download => downloads.push(download));
    page.on('request', request => {
      if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
        externalRequests.push(request.url());
      }
    });
    // The existing observer is generic: pin the clicked Blob rather than an
    // unrelated allocation, and retain every existing GZIP boundary assertion.
    await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Encode URL', exact: true }).click();
    const editor = page.getByRole('textbox', { name: 'Text to encode', exact: true });
    await expect(editor).toBeVisible();
    page.on('request', request => recordHttpRequest(request, interactionRequests));
    await urlScript(page, 'Setup');
    const input = '&<>"\'/ &amp; Olá 🌍';
    if (scenario.source === 'typed') {
      await fillFlutterTextBox(editor, input);
    } else if (scenario.source === 'clipboard') {
      await page.getByRole('button', { name: 'Paste text', exact: true }).evaluate(button => button.click());
      await expect.poll(() => page.evaluate(source => new Function(source)('Text to encode', '&<>"\'/ &amp; Olá 🌍', true), safariInputObservation)).toBe(true);
      expect(await page.evaluate(() => window.__chimeraUrlReads)).toBe(1);
    } else if (scenario.source === 'file') {
      const previousEditor = await editor.elementHandle();
      const pendingChooser = page.waitForEvent('filechooser');
      await page.getByRole('button', { name: 'Load UTF-8 file', exact: true }).click();
      await (await pendingChooser).setFiles({ name: 'source.txt', mimeType: 'text/plain', buffer: Buffer.from(input, 'utf8') });
      // FileReader completes after setFiles dispatches change. The page then
      // recreates its editor to discard undo history before enabling mode.
      await expect.poll(() => previousEditor.evaluate(input => input.isConnected)).toBe(false);
      await expect(editor).toBeEnabled();
    }
    if (scenario.mode !== 'component') {
      await expect.poll(() => urlScript(page, 'ModeOpen')).toBe(true);
      await expect.poll(() => urlScript(page, 'ModeSelect', scenario.mode)).toBe(true);
      await expect(page.getByRole('button', { name: `URL mode ${scenario.mode}`, exact: true })).toBeVisible();
    } else {
      await expect(page.getByRole('button', { name: 'URL mode URL component', exact: true })).toBeVisible();
    }
    await page.getByRole('button', { name: 'Encode', exact: true }).click();
    const result = page.getByRole('region', { name: 'URL encoded result URL encoding succeeded.', exact: true });
    await expect(result).toBeVisible();
    await expect(result).toHaveAttribute('tabindex', '0');
    await expect.poll(() => urlScript(page, 'Result')).toBe(true);
    await expect.poll(() => page.evaluate(source => new Function(source)('Text to encode', '', true), safariInputObservation)).toBe(true);
    await expect.poll(() => urlScript(page, 'Copy')).toBe(true);
    await page.keyboard.press('Enter');
    await expect.poll(async () => ({
      matches: await urlScript(page, 'Copied', scenario.expected, 1),
      ...await page.evaluate(() => ({ copies: window.__chimeraUrlCopies, text: window.__chimeraUrlCopiedText })),
    })).toEqual({ matches: true, copies: 1, text: scenario.expected });
    const pendingDownload = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Save encoded text', exact: true }).press('Enter');
    const download = await pendingDownload;
    expect(download.suggestedFilename()).toBe('chimera-url-encoded.txt');
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    const expectedBytes = Buffer.from(scenario.expected, 'utf8');
    expect(Buffer.concat(chunks)).toEqual(expectedBytes);
    await expect.poll(() => urlScript(page, 'Save', [...expectedBytes], 1)).toBe(true);
    expect(downloads).toHaveLength(1);
    await expect(result).toBeVisible();

    // Dispatch Safari's real malformed-file helper after success. This also
    // proves previous output/actions and source cannot survive validation.
    await page.evaluate(() => {
      const click = HTMLInputElement.prototype.click;
      HTMLInputElement.prototype.click = function() {
        if (this.type === 'file') return;
        return click.call(this);
      };
    });
    await page.getByRole('button', { name: 'Load UTF-8 file', exact: true }).click();
    await expect.poll(() => urlScript(page, 'File', [0xc3, 0x28])).toBe(true);
    await expect.poll(() => urlScript(page, 'NoResult')).toBe(true);
    await expect(page.getByRole('button', { name: 'Encode', exact: true })).toBeEnabled();
    await page.getByRole('button', { name: 'Encode', exact: true }).click();
    await expect(page.locator('span', { hasText: /^The URL encoding request is invalid\.$/ })).toBeVisible();
    await expect.poll(() => urlScript(page, 'NoResult')).toBe(true);
    await expect(result).toHaveCount(0);
    await expect.poll(() => page.evaluate(source => new Function(source)('Text to encode', '', true), safariInputObservation)).toBe(true);
    expect(await page.evaluate(() => window.__chimeraUrlCopies)).toBe(1);
    expect(await page.evaluate(() => window.__chimeraSaveCount)).toBe(1);
    expect(downloads).toHaveLength(1);
    expect(interactionRequests).toEqual([]);
    expect(externalRequests).toEqual([]);
  });
}

for (const boundary of ['copy', 'save']) {
  test(`GivenUrlResult_When${boundary}AccessFails_ThenSourceAndOutputAreDiscardedOffline`, async ({ page }) => {
    const requests = [];
    const downloads = [];
    page.on('download', download => downloads.push(download));
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Encode URL', exact: true }).click();
    const editor = page.getByRole('textbox', { name: 'Text to encode', exact: true });
    await expect(editor).toBeVisible();
    page.on('request', request => recordHttpRequest(request, requests));
    await fillFlutterTextBox(editor, 'private /ação');
    await page.getByRole('button', { name: 'Encode', exact: true }).click();
    await expect.poll(() => urlScript(page, 'Result')).toBe(true);
    await page.evaluate(boundary => {
      if (boundary === 'copy') {
        Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
          writeText: async () => { throw new Error('private output denial'); },
        } });
      } else {
        URL.createObjectURL = () => { throw new Error('private output denial'); };
      }
    }, boundary);
    await page.getByRole('button', { name: boundary === 'copy' ? 'Copy encoded text' : 'Save encoded text', exact: true }).click();
    await expect(page.locator('span', { hasText: boundary === 'copy'
      ? /^The clipboard text could not be written\.$/
      : /^The URL encoded text could not be saved\.$/ })).toBeVisible();
    await expect.poll(() => urlScript(page, 'NoResult')).toBe(true);
    await expect.poll(() => page.evaluate(source => new Function(source)('Text to encode', '', true), safariInputObservation)).toBe(true);
    expect(downloads).toEqual([]);
    expect(requests).toEqual([]);
  });
}

const safariHtmlScripts = Object.fromEntries([...safariHarness.matchAll(
  /const _html(\w+)Script = r'''([\s\S]*?)''';/g,
)].map(([, name, source]) => [name, source]));
async function htmlScript(page, name, ...args) {
  expect(safariHtmlScripts[name], `Safari HTML ${name} helper`).toBeTruthy();
  return page.evaluate(({ source, args }) => new Function(source)(...args), {
    source: safariHtmlScripts[name], args,
  });
}

for (const scenario of [
  { context: 'all', source: 'typed', expected: '&amp;&lt;&gt;&quot;&#39;&#47; &amp;amp; Olá 🌍' },
  { context: 'Element text', source: 'file', expected: '&amp;&lt;&gt;"\'/ &amp;amp; Olá 🌍' },
  { context: 'Double-quoted attribute', source: 'clipboard', expected: '&amp;&lt;&gt;&quot;\'/ &amp;amp; Olá 🌍' },
  { context: 'Single-quoted attribute', source: 'typed', expected: '&amp;&lt;&gt;"&#39;/ &amp;amp; Olá 🌍' },
  { context: 'all', source: 'empty', expected: '' },
]) {
  test(`GivenHtml${scenario.context}${scenario.source}_WhenEncodedCopiedAndSaved_ThenExactEntitiesTransferOffline`, async ({ page }) => {
    const externalRequests = [];
    const interactionRequests = [];
    const downloads = [];
    page.on('download', download => downloads.push(download));
    page.on('request', request => {
      if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
        externalRequests.push(request.url());
      }
    });
    // The existing observer is generic: pin the clicked Blob rather than an
    // unrelated allocation, and retain every existing GZIP boundary assertion.
    await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Encode HTML', exact: true }).click();
    const editor = page.getByRole('textbox', { name: 'Text to encode', exact: true });
    await expect(editor).toBeVisible();
    page.on('request', request => recordHttpRequest(request, interactionRequests));
    await htmlScript(page, 'Setup');
    const input = '&<>"\'/ &amp; Olá 🌍';
    if (scenario.source === 'typed') {
      await fillFlutterTextBox(editor, input);
    } else if (scenario.source === 'clipboard') {
      await page.getByRole('button', { name: 'Paste text', exact: true }).evaluate(button => button.click());
      await expect.poll(() => page.evaluate(source => new Function(source)('Text to encode', '&<>"\'/ &amp; Olá 🌍', true), safariInputObservation)).toBe(true);
      expect(await page.evaluate(() => window.__chimeraHtmlReads)).toBe(1);
    } else if (scenario.source === 'file') {
      const previousEditor = await editor.elementHandle();
      const pendingChooser = page.waitForEvent('filechooser');
      await page.getByRole('button', { name: 'Load UTF-8 file', exact: true }).click();
      await (await pendingChooser).setFiles({ name: 'source.txt', mimeType: 'text/plain', buffer: Buffer.from(input, 'utf8') });
      // FileReader completes after setFiles dispatches change. The page then
      // recreates its editor to discard undo history before enabling context.
      await expect.poll(() => previousEditor.evaluate(input => input.isConnected)).toBe(false);
      await expect(editor).toBeEnabled();
    }
    if (scenario.context !== 'all') {
      await expect.poll(() => htmlScript(page, 'ContextOpen')).toBe(true);
      await expect.poll(() => htmlScript(page, 'ContextSelect', scenario.context)).toBe(true);
      await expect(page.getByRole('button', { name: `HTML context ${scenario.context}`, exact: true })).toBeVisible();
    } else {
      await expect(page.getByRole('button', { name: 'HTML context All characters', exact: true })).toBeVisible();
    }
    await page.getByRole('button', { name: 'Encode', exact: true }).click();
    const result = page.getByRole('region', { name: 'HTML encoded result HTML encoding succeeded.', exact: true });
    await expect(result).toBeVisible();
    await expect(result).toHaveAttribute('tabindex', '0');
    await expect.poll(() => htmlScript(page, 'Result')).toBe(true);
    await expect.poll(() => page.evaluate(source => new Function(source)('Text to encode', '', true), safariInputObservation)).toBe(true);
    await expect.poll(() => htmlScript(page, 'Copy')).toBe(true);
    await page.keyboard.press('Enter');
    await expect.poll(async () => ({
      matches: await htmlScript(page, 'Copied', scenario.expected, 1),
      ...await page.evaluate(() => ({ copies: window.__chimeraHtmlCopies, text: window.__chimeraHtmlCopiedText })),
    })).toEqual({ matches: true, copies: 1, text: scenario.expected });
    const pendingDownload = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Save encoded text', exact: true }).press('Enter');
    const download = await pendingDownload;
    expect(download.suggestedFilename()).toBe('chimera-html-encoded.txt');
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    const expectedBytes = Buffer.from(scenario.expected, 'utf8');
    expect(Buffer.concat(chunks)).toEqual(expectedBytes);
    await expect.poll(() => htmlScript(page, 'Save', [...expectedBytes], 1)).toBe(true);
    expect(downloads).toHaveLength(1);
    await expect(result).toBeVisible();

    // Dispatch Safari's real malformed-file helper after success. This also
    // proves previous output/actions and source cannot survive validation.
    await page.evaluate(() => {
      const click = HTMLInputElement.prototype.click;
      HTMLInputElement.prototype.click = function() {
        if (this.type === 'file') return;
        return click.call(this);
      };
    });
    await page.getByRole('button', { name: 'Load UTF-8 file', exact: true }).click();
    await expect.poll(() => htmlScript(page, 'File', [0xc3, 0x28])).toBe(true);
    await expect.poll(() => htmlScript(page, 'NoResult')).toBe(true);
    await expect(page.getByRole('button', { name: 'Encode', exact: true })).toBeEnabled();
    await page.getByRole('button', { name: 'Encode', exact: true }).click();
    await expect(page.locator('span', { hasText: /^The HTML encoding request is invalid\.$/ })).toBeVisible();
    await expect.poll(() => htmlScript(page, 'NoResult')).toBe(true);
    await expect(result).toHaveCount(0);
    await expect.poll(() => page.evaluate(source => new Function(source)('Text to encode', '', true), safariInputObservation)).toBe(true);
    expect(await page.evaluate(() => window.__chimeraHtmlCopies)).toBe(1);
    expect(await page.evaluate(() => window.__chimeraSaveCount)).toBe(1);
    expect(downloads).toHaveLength(1);
    expect(interactionRequests).toEqual([]);
    expect(externalRequests).toEqual([]);
  });
}

for (const scenario of [
  { source: 'typed', input: '%3C%26%41%F0%9F%99%82%253C+', expected: '<&A🙂%3C+' },
  { source: 'file', input: '%3C%26%41%F0%9F%99%82', expected: '<&A🙂' },
  { source: 'clipboard', input: '%22offline%22', expected: '"offline"' },
  { source: 'empty', input: '', expected: '' },
]) {
  test(`GivenUrlDecode${scenario.source}_WhenCopiedAndSaved_ThenExactTextTransfersOffline`, async ({ page }) => {
    const externalRequests = [];
    const interactionRequests = [];
    const downloads = [];
    page.on('download', download => downloads.push(download));
    page.on('request', request => {
      if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
        externalRequests.push(request.url());
      }
    });
    await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
    await page.addInitScript(input => {
      window.__chimeraUrlDecodeReads = 0;
      window.__chimeraUrlDecodeWrites = 0;
      window.__chimeraUrlDecodeCopied = null;
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: {
          readText: async () => {
            window.__chimeraUrlDecodeReads++;
            return input;
          },
          writeText: async value => {
            window.__chimeraUrlDecodeWrites++;
            window.__chimeraUrlDecodeCopied = value;
          },
        },
      });
    }, scenario.input);
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Decode URL', exact: true }).click();
    const editor = page.getByRole('textbox', { name: 'Percent-encoded text to decode', exact: true });
    await expect(editor).toBeVisible();
    page.on('request', request => recordHttpRequest(request, interactionRequests));
    if (scenario.source === 'typed') {
      await fillFlutterTextBox(editor, scenario.input);
    } else if (scenario.source === 'clipboard') {
      await page.getByRole('button', { name: 'Paste text', exact: true }).click();
      await expect.poll(() => page.evaluate(() => window.__chimeraUrlDecodeReads)).toBe(1);
      await expect.poll(() => page.evaluate(
        ({ source, input }) => new Function(source)(
          'Percent-encoded text to decode', input, true,
        ),
        { source: safariInputObservation, input: scenario.input },
      )).toBe(true);
    } else if (scenario.source === 'file') {
      const previousEditor = await editor.elementHandle();
      const pendingChooser = page.waitForEvent('filechooser');
      await page.getByRole('button', { name: 'Load UTF-8 file', exact: true }).click();
      await (await pendingChooser).setFiles({
        name: 'entities.txt', mimeType: 'text/plain',
        buffer: Buffer.from(scenario.input, 'utf8'),
      });
      await expect.poll(() => previousEditor.evaluate(input => input.isConnected)).toBe(false);
      await expect(page.getByRole('button', { name: 'Decode', exact: true })).toBeEnabled();
    }
    await expect.poll(() => urlScript(page, 'DecodeSubmit')).toBe(true);
    await page.getByRole('button', { name: 'Decode', exact: true }).click();
    const result = page.getByRole('region', {
      name: 'URL decoded result URL decoding succeeded.', exact: true,
    });
    await expect.poll(() => urlScript(page, 'DecodeResult')).toBe(true);
    await expect(result).toBeVisible();
    await expect(result).toHaveAttribute('tabindex', '0');
    await expect(editor).toHaveValue('');
    await expect.poll(() => urlScript(page, 'DecodeCopy')).toBe(true);
    await page.getByRole('button', { name: 'Copy decoded text', exact: true }).press('Enter');
    await expect.poll(() => page.evaluate(() => ({
      count: window.__chimeraUrlDecodeWrites,
      text: window.__chimeraUrlDecodeCopied,
    }))).toEqual({ count: 1, text: scenario.expected });
    const pendingDownload = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Save decoded text', exact: true }).press('Enter');
    const download = await pendingDownload;
    expect(download.suggestedFilename()).toBe('chimera-url-decoded.txt');
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    const expectedBytes = Buffer.from(scenario.expected, 'utf8');
    expect(Buffer.concat(chunks)).toEqual(expectedBytes);
    await expect.poll(() => page.evaluate(() => ({
      count: window.__chimeraSaveCount,
      name: window.__chimeraSavedName,
      mime: window.__chimeraSavedMime,
      bytes: window.__chimeraSavedBytes,
      liveUrls: window.__chimeraLiveDownloadUrlCount,
      errors: window.__chimeraGzipSaveErrors,
    }))).toEqual({
      count: 1,
      name: 'chimera-url-decoded.txt',
      mime: 'text/plain; charset=utf-8',
      bytes: [...expectedBytes],
      liveUrls: 0,
      errors: [],
    });
    await expect.poll(() => urlScript(page, 'DecodeSave', [...expectedBytes], 1)).toBe(true);
    expect(downloads).toHaveLength(1);
    expect(interactionRequests).toEqual([]);
    expect(externalRequests).toEqual([]);
  });
}

test('GivenUrlDecodeEditorFocus_WhenTabbingToDecodeAndPressingEnter_ThenOneResultAppears', async ({ page }) => {
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decode URL', exact: true }).click();
  const editor = page.getByRole('textbox', { name: 'Percent-encoded text to decode', exact: true });
  await fillFlutterTextBox(editor, '%3C%26');
  await expect(page.getByRole('button', { name: 'Load UTF-8 file', exact: true })).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(page.getByRole('button', { name: 'Paste text', exact: true })).toBeFocused();
  await page.keyboard.press('Tab');
  const decode = page.getByRole('button', { name: 'Decode', exact: true });
  await expect(decode).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('region', {
    name: 'URL decoded result URL decoding succeeded.', exact: true,
  })).toBeVisible();
});

test('GivenMalformedUrlDecodeFile_WhenSubmitted_ThenNoResultOrExternalRequestRemains', async ({ page }) => {
  const requests = [];
  page.on('request', request => {
    if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
      requests.push(request.url());
    }
  });
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decode URL', exact: true }).click();
  const previousEditor = await page.getByRole('textbox', { name: 'Percent-encoded text to decode', exact: true }).elementHandle();
  const chooser = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Load UTF-8 file', exact: true }).click();
  await (await chooser).setFiles({
    name: 'invalid.txt', mimeType: 'text/plain', buffer: Buffer.from([0xc3, 0x28]),
  });
  await expect.poll(() => previousEditor.evaluate(input => input.isConnected)).toBe(false);
  await page.getByRole('button', { name: 'Decode', exact: true }).click();
  await expect(page.locator('span', {
    hasText: /^The URL decoding request is invalid\.$/,
  })).toBeVisible();
  await expect(page.getByRole('region', {
    name: 'URL decoded result URL decoding succeeded.', exact: true,
  })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Copy decoded text', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Save decoded text', exact: true })).toHaveCount(0);
  expect(requests).toEqual([]);
});

for (const scenario of [
  { source: 'typed', input: '&lt;&amp;&#65;&#x1F642;&amp;lt;', expected: '<&A🙂&lt;' },
  { source: 'file', input: '&#60;&#38;&#x41;&#x1F642;', expected: '<&A🙂' },
  { source: 'clipboard', input: '&quot;offline&quot;', expected: '"offline"' },
  { source: 'empty', input: '', expected: '' },
]) {
  test(`GivenHtmlDecode${scenario.source}_WhenCopiedAndSaved_ThenExactTextTransfersOffline`, async ({ page }) => {
    const externalRequests = [];
    const interactionRequests = [];
    const downloads = [];
    page.on('download', download => downloads.push(download));
    page.on('request', request => {
      if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
        externalRequests.push(request.url());
      }
    });
    await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
    await page.addInitScript(input => {
      window.__chimeraHtmlDecodeReads = 0;
      window.__chimeraHtmlDecodeWrites = 0;
      window.__chimeraHtmlDecodeCopied = null;
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: {
          readText: async () => {
            window.__chimeraHtmlDecodeReads++;
            return input;
          },
          writeText: async value => {
            window.__chimeraHtmlDecodeWrites++;
            window.__chimeraHtmlDecodeCopied = value;
          },
        },
      });
    }, scenario.input);
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Decode HTML', exact: true }).click();
    const editor = page.getByRole('textbox', { name: 'HTML entities to decode', exact: true });
    await expect(editor).toBeVisible();
    page.on('request', request => recordHttpRequest(request, interactionRequests));
    if (scenario.source === 'typed') {
      await fillFlutterTextBox(editor, scenario.input);
    } else if (scenario.source === 'clipboard') {
      await page.getByRole('button', { name: 'Paste text', exact: true }).click();
      await expect.poll(() => page.evaluate(() => window.__chimeraHtmlDecodeReads)).toBe(1);
      await expect.poll(() => page.evaluate(
        ({ source, input }) => new Function(source)(
          'HTML entities to decode', input, true,
        ),
        { source: safariInputObservation, input: scenario.input },
      )).toBe(true);
    } else if (scenario.source === 'file') {
      const pendingChooser = page.waitForEvent('filechooser');
      await page.getByRole('button', { name: 'Load UTF-8 file', exact: true }).click();
      await (await pendingChooser).setFiles({
        name: 'entities.txt', mimeType: 'text/plain',
        buffer: Buffer.from(scenario.input, 'utf8'),
      });
      await expect(page.getByRole('button', { name: 'Decode', exact: true })).toBeEnabled();
    }
    await page.getByRole('button', { name: 'Decode', exact: true }).click();
    const result = page.getByRole('region', {
      name: 'HTML decoded result HTML decoding succeeded.', exact: true,
    });
    await expect(result).toBeVisible();
    await expect(result).toHaveAttribute('tabindex', '0');
    await expect(editor).toHaveValue('');
    await page.getByRole('button', { name: 'Copy decoded text', exact: true }).press('Enter');
    await expect.poll(() => page.evaluate(() => ({
      count: window.__chimeraHtmlDecodeWrites,
      text: window.__chimeraHtmlDecodeCopied,
    }))).toEqual({ count: 1, text: scenario.expected });
    const pendingDownload = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Save decoded text', exact: true }).press('Enter');
    const download = await pendingDownload;
    expect(download.suggestedFilename()).toBe('chimera-html-decoded.txt');
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    const expectedBytes = Buffer.from(scenario.expected, 'utf8');
    expect(Buffer.concat(chunks)).toEqual(expectedBytes);
    await expect.poll(() => page.evaluate(() => ({
      count: window.__chimeraSaveCount,
      name: window.__chimeraSavedName,
      mime: window.__chimeraSavedMime,
      bytes: window.__chimeraSavedBytes,
      liveUrls: window.__chimeraLiveDownloadUrlCount,
      errors: window.__chimeraGzipSaveErrors,
    }))).toEqual({
      count: 1,
      name: 'chimera-html-decoded.txt',
      mime: 'text/plain; charset=utf-8',
      bytes: [...expectedBytes],
      liveUrls: 0,
      errors: [],
    });
    expect(downloads).toHaveLength(1);
    expect(interactionRequests).toEqual([]);
    expect(externalRequests).toEqual([]);
  });
}

test('GivenHtmlDecodeEditorFocus_WhenTabbingToDecodeAndPressingEnter_ThenOneResultAppears', async ({ page }) => {
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decode HTML', exact: true }).click();
  const editor = page.getByRole('textbox', { name: 'HTML entities to decode', exact: true });
  await fillFlutterTextBox(editor, '&lt;&amp;');
  await expect(page.getByRole('button', { name: 'Load UTF-8 file', exact: true })).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(page.getByRole('button', { name: 'Paste text', exact: true })).toBeFocused();
  await page.keyboard.press('Tab');
  const decode = page.getByRole('button', { name: 'Decode', exact: true });
  await expect(decode).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page.getByRole('region', {
    name: 'HTML decoded result HTML decoding succeeded.', exact: true,
  })).toBeVisible();
});

test('GivenMalformedHtmlDecodeFile_WhenSubmitted_ThenNoResultOrExternalRequestRemains', async ({ page }) => {
  const requests = [];
  page.on('request', request => {
    if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
      requests.push(request.url());
    }
  });
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decode HTML', exact: true }).click();
  const chooser = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Load UTF-8 file', exact: true }).click();
  await (await chooser).setFiles({
    name: 'invalid.txt', mimeType: 'text/plain', buffer: Buffer.from([0xc3, 0x28]),
  });
  await page.getByRole('button', { name: 'Decode', exact: true }).click();
  await expect(page.locator('span', {
    hasText: /^The HTML decoding request is invalid\.$/,
  })).toBeVisible();
  await expect(page.getByRole('region', {
    name: 'HTML decoded result HTML decoding succeeded.', exact: true,
  })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Copy decoded text', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Save decoded text', exact: true })).toHaveCount(0);
  expect(requests).toEqual([]);
});

test('GivenHtmlEditorFocus_WhenTabbingToEncodeAndPressingEnter_ThenOneResultAppears', async ({ page }) => {
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Encode HTML', exact: true }).click();

  const editor = page.getByRole('textbox', { name: 'Text to encode', exact: true });
  await fillFlutterTextBox(editor, '&<');

  const fileButton = page.getByRole('button', { name: 'Load UTF-8 file', exact: true });
  const pasteButton = page.getByRole('button', { name: 'Paste text', exact: true });
  const contextButton = page.getByRole('button', { name: 'HTML context All characters', exact: true });
  const encodeButton = page.getByRole('button', { name: 'Encode', exact: true });
  await expect(fileButton).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(pasteButton).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(contextButton).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(encodeButton).toBeFocused();
  await page.keyboard.press('Enter');

  const result = page.getByRole('region', {
    name: 'HTML encoded result HTML encoding succeeded.', exact: true,
  });
  await expect(result).toBeVisible();
  await expect(result).toHaveCount(1);
});

test('GivenGzipClipboardSource_WhenPastedWithRecreatedEditor_ThenSafariObservationAndExactDownloadSucceed', async ({ page }) => {
  const requests = [];
  const downloads = [];
  page.on('request', request => {
    if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') requests.push(request.url());
  });
  page.on('download', download => downloads.push(download));
  await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
  await page.addInitScript(() => {
    window.__chimeraGzipClipboardReads = 0;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {readText: async () => {
        window.__chimeraGzipClipboardReads++;
        return 'Olá 🌍';
      }},
    });
  });
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Compress to GZIP', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'Text to compress', exact: true })).toBeVisible();
  page.on('request', request => {
    if (/^https?:/.test(request.url())) requests.push(request.url());
  });
  // Match Safari's existing semantics activation instead of filling the editor.
  await page.getByRole('button', { name: 'Paste text', exact: true }).evaluate(button => button.click());
  await expect.poll(() => page.evaluate(() => window.__chimeraGzipClipboardReads)).toBe(1);
  await expect.poll(() => page.evaluate(source =>
    new Function(source)('Text to compress', 'Olá 🌍', true),
  safariInputObservation)).toBe(true);
  await expect.poll(() => page.evaluate(source => new Function(source)(), safariLevelOpening)).toBe(true);
  await expect.poll(() => page.evaluate(source => new Function(source)('0'), safariLevelSelection)).toBe(true);
  await page.getByRole('button', { name: 'Compress', exact: true }).click();
  await expect(page.getByRole('region', {
    name: 'Compressed binary result Compression succeeded. Compression level: 0 Input bytes: 9 Output bytes: 32', exact: true,
  })).toBeVisible();
  const pendingDownload = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save GZIP file', exact: true }).click();
  const download = await pendingDownload;
  expect(download.suggestedFilename()).toBe('chimera-compressed.gz');
  const chunks = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk);
  const actual = Buffer.concat(chunks);
  assertGzipMember(actual, '1f8b08000000000000ff010900f6ff4f6cc3a120f09f8c8d65c404fa09000000', Buffer.from('Olá 🌍'));
  await expect.poll(() => page.evaluate(() => ({
    count: window.__chimeraSaveCount, mime: window.__chimeraSavedMime,
    bytes: window.__chimeraSavedBytes, errors: window.__chimeraGzipSaveErrors,
  }))).toEqual({ count: 1, mime: 'application/gzip', bytes: [...actual], errors: [] });
  expect(downloads).toHaveLength(1);
  expect(requests).toEqual([]);
});

test('GivenObservedDownloadObjectUrl_WhenRevokedAfterActivation_ThenNoLiveDownloadUrlRemains', async ({ page }) => {
  await page.evaluate(`${gzipSaveObserver}\nobserveGzipSaves({suppressDownloads: true});`);
  await page.evaluate(() => {
    const anchor = document.createElement('a');
    anchor.download = 'chimera-decompressed.bin';
    const url = URL.createObjectURL(new Blob([new Uint8Array([0, 255, 128, 1])], {
      type: 'application/octet-stream',
    }));
    anchor.href = url;
    anchor.click();
    URL.revokeObjectURL(url);
  });
  await expect.poll(() => page.evaluate(() => window.__chimeraSavedBytes)).toEqual([0, 255, 128, 1]);
  expect(await page.evaluate(() => window.__chimeraLiveDownloadUrlCount)).toBe(0);
});

test('GivenLoopbackHttpRequest_WhenInteractionWindowIsObserved_ThenRequestIsRecorded', async ({ page }) => {
  await page.goto('/');
  const interactionRequests = [];
  page.on('request', request => recordHttpRequest(request, interactionRequests));
  await page.evaluate(() => fetch('/manifest.json?late-startup-request=1'));
  await page.evaluate(() => fetch('/manifest.json?gzip-interaction-probe=1'));
  expect(interactionRequests.filter(
    url => url === 'http://127.0.0.1:41731/manifest.json?gzip-interaction-probe=1',
  )).toEqual(['http://127.0.0.1:41731/manifest.json?gzip-interaction-probe=1']);
});

for (const scenario of ['unknown-href', 'revoked-href', 'wrong-mime', 'duplicate-click', 'revoke-after-click']) {
  test(`GivenGzipSaveBoundary_When${scenario}_ThenOnlyOneMatchingLiveBlobIsAccepted`, async ({ page }) => {
    await page.evaluate(`${gzipSaveObserver}\nobserveGzipSaves({suppressDownloads: true});`);
    await page.evaluate(scenario => {
      const anchor = document.createElement('a');
      anchor.download = 'chimera-compressed.gz';
      const payload = new Blob([new Uint8Array([31, 139, 8])], {
        type: scenario === 'wrong-mime' ? 'text/plain' : 'application/gzip',
      });
      const url = URL.createObjectURL(payload);
      anchor.href = scenario === 'unknown-href' ? 'blob:wrong-or-missing-payload' : url;
      if (scenario === 'revoked-href') URL.revokeObjectURL(url);
      anchor.click();
      if (scenario === 'duplicate-click') anchor.click();
      if (scenario === 'revoke-after-click') URL.revokeObjectURL(url);
    }, scenario);
    // Wait for this observer's read or invalid-URL outcome, not a second read.
    await expect.poll(() => page.evaluate(() =>
      Array.isArray(window.__chimeraSavedBytes) ||
      window.__chimeraGzipSaveErrors.length > 0,
    )).toBe(true);
    const accepted = await page.evaluate(() =>
      window.__chimeraSavedName === 'chimera-compressed.gz' &&
        window.__chimeraSaveCount === 1 &&
        window.__chimeraSavedMime === 'application/gzip' &&
        window.__chimeraGzipSaveErrors.length === 0 &&
        JSON.stringify(window.__chimeraSavedBytes) === '[31,139,8]',
    );
    expect(accepted).toBe(scenario === 'revoke-after-click');
  });
}

for (const scenario of ['wrong-mime', 'duplicate-click']) {
  test(`GivenGzipDownloadBoundary_When${scenario}_ThenActualMimeAndDownloadCountExposeInvalidSave`, async ({ page }) => {
    const downloads = [];
    page.on('download', download => downloads.push(download));
    await page.evaluate(`${gzipSaveObserver}\nobserveGzipSaves();`);
    await page.evaluate(scenario => {
      const anchor = document.createElement('a');
      anchor.download = 'chimera-compressed.gz';
      anchor.href = URL.createObjectURL(new Blob([new Uint8Array([31, 139, 8])], {
        type: scenario === 'wrong-mime' ? 'text/plain' : 'application/gzip',
      }));
      document.body.append(anchor);
      anchor.click();
      if (scenario === 'duplicate-click') anchor.click();
    }, scenario);
    const count = scenario === 'duplicate-click' ? 2 : 1;
    await expect.poll(() => downloads.length).toBe(count);
    await expect.poll(() => page.evaluate(() => ({
      count: window.__chimeraSaveCount,
      mime: window.__chimeraSavedMime,
      bytes: window.__chimeraSavedBytes,
      errors: window.__chimeraGzipSaveErrors,
    }))).toEqual({ count, mime: scenario === 'wrong-mime' ? 'text/plain' : 'application/gzip', bytes: [31, 139, 8], errors: [] });
    for (const download of downloads) {
      expect(download.suggestedFilename()).toBe('chimera-compressed.gz');
      const chunks = [];
      for await (const chunk of await download.createReadStream()) chunks.push(chunk);
      expect([...Buffer.concat(chunks)]).toEqual([31, 139, 8]);
    }
    // These real downloads would fail the operation's MIME/one-save contract.
    expect(await page.evaluate(() => window.__chimeraSaveCount === 1 &&
      window.__chimeraSavedMime === 'application/gzip')).toBe(false);
  });
}

for (const source of ['text', 'binary']) {
  test(`GivenGzip${source}_WhenLevelSelectedCompressedAndDownloaded_ThenExactMemberRoundTripsOffline`, async ({ page }) => {
    const input = source === 'text' ? Buffer.from('Olá 🌍', 'utf8') : Buffer.from([0, 255, 128, 1]);
    const level = source === 'text' ? 0 : 9;
    const expectedHex = source === 'text'
      ? '1f8b08000000000000ff010900f6ff4f6cc3a120f09f8c8d65c404fa09000000'
      : '1f8b08000000000000ff63f8dfc008002c4358d304000000';
    const outputCount = source === 'text' ? 32 : 24;
    const externalRequests = [];
    const interactionRequests = [];
    const downloads = [];
    page.on('download', download => downloads.push(download));
    await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
    page.on('request', request => {
      if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') externalRequests.push(request.url());
    });
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Compress to GZIP', exact: true }).click();
    const text = page.getByRole('textbox', { name: 'Text to compress', exact: true });
    await expect(text).toBeVisible();
    page.on('request', request => {
      if (/^https?:/.test(request.url())) interactionRequests.push(request.url());
    });
    if (source === 'text') {
      await fillFlutterTextBox(text, input.toString('utf8'));
    } else {
      const chooser = page.waitForEvent('filechooser');
      await page.getByRole('button', { name: 'Load file bytes', exact: true }).click();
      await (await chooser).setFiles({ name: 'source.bin', mimeType: 'application/octet-stream', buffer: input });
      await expect(page.getByRole('group').getByText('Input bytes: 4', { exact: true })).toBeVisible();
      await expect(text).toHaveValue('');
    }
    await page.getByRole('button', { name: 'Compression level 6', exact: true }).click();
    await page.getByRole('menuitem', { name: `${level}`, exact: true }).click();
    await page.getByRole('button', { name: 'Compress', exact: true }).click();
    const result = page.getByRole('region', {
      name: `Compressed binary result Compression succeeded. Compression level: ${level} Input bytes: ${input.length} Output bytes: ${outputCount}`,
      exact: true,
    });
    await expect(result).toBeVisible();
    await expect(result).toHaveAttribute('tabindex', '0');
    const downloadPromise = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Save GZIP file', exact: true }).click();
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toBe('chimera-compressed.gz');
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    const downloaded = Buffer.concat(chunks);
    assertGzipMember(downloaded, expectedHex, input);
    await expect.poll(() => page.evaluate(() => ({
      name: window.__chimeraSavedName,
      count: window.__chimeraSaveCount,
      mime: window.__chimeraSavedMime,
      bytes: window.__chimeraSavedBytes,
      errors: window.__chimeraGzipSaveErrors,
    }))).toEqual({ name: 'chimera-compressed.gz', count: 1, mime: 'application/gzip', bytes: [...downloaded], errors: [] });
    expect(downloads).toHaveLength(1);
    await expect(result).toBeVisible();
    expect(interactionRequests).toEqual([]);
    expect(externalRequests).toEqual([]);
  });
}

function assertGzipMember(actual, expectedHex, source) {
  // Literal RFC 1952 members also pin MTIME, optional flags, CRC32 and ISIZE.
  expect(actual.toString('hex')).toBe(expectedHex);
  // Node's platform zlib decoder is independent of the Dart archive encoder.
  expect(gunzipSync(actual)).toEqual(source);
}

function recordHttpRequest(request, requests) {
  if (/^https?:/.test(request.url())) requests.push(request.url());
}

test('GivenBomGzipFile_WhenTextDecompressedCopiedAndDownloaded_ThenExactBytesTransferOffline', async ({ page }) => {
  const archive = Buffer.from('1f8b08000000000002ff7bbf7b7f222f97020084beddc007000000', 'hex');
  const expected = Buffer.from('efbbbf610d0a20', 'hex');
  const externalRequests = [];
  const interactionRequests = [];
  const downloads = [];
  page.on('download', download => downloads.push(download));
  page.on('request', request => {
    const url = new URL(request.url());
    if ((url.protocol === 'http:' || url.protocol === 'https:') && url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });
  await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
  await page.addInitScript(() => {
    window.__chimeraCopiedText = null;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {writeText: async value => { window.__chimeraCopiedText = value; }},
    });
  });

  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decompress GZIP', exact: true }).click();
  await expect(page.getByText('Decompress GZIP').first()).toBeVisible();
  page.on('request', request => recordHttpRequest(request, interactionRequests));
  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Load GZIP file', exact: true }).click();
  await (await chooserPromise).setFiles({
    name: 'extension-independent.data',
    mimeType: 'application/octet-stream',
    buffer: archive,
  });
  await expect(page.getByText(`Input bytes: ${archive.length}`, { exact: true }).last()).toBeVisible();
  await page.getByRole('button', { name: 'Decompress', exact: true }).click();
  const result = page.getByRole('region', {
    name: `Decompressed result Decompression succeeded. Input bytes: ${archive.length} Output bytes: ${expected.length}`,
    exact: true,
  });
  await expect(result).toBeVisible();
  await expect(result).toHaveAttribute('tabindex', '0');
  await expect.poll(() => page.evaluate(
    source => new Function(source)('Copy decompressed text'),
    safariGzipCopyActivation,
  )).toBe(true);
  await page.keyboard.press('Enter');
  await expect.poll(() => page.evaluate(
    source => new Function(source)(),
    safariCopiedTextObservation,
  )).toEqual([0xfeff, 0x61, 0x0d, 0x0a, 0x20]);

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save decompressed bytes', exact: true }).press('Enter');
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe('chimera-decompressed.txt');
  const chunks = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk);
  expect(Buffer.concat(chunks)).toEqual(expected);
  await expect.poll(() => page.evaluate(() => ({
    name: window.__chimeraSavedName,
    count: window.__chimeraSaveCount,
    mime: window.__chimeraSavedMime,
    bytes: window.__chimeraSavedBytes,
    liveUrls: window.__chimeraLiveDownloadUrlCount,
    errors: window.__chimeraGzipSaveErrors,
  }))).toEqual({
    name: 'chimera-decompressed.txt', count: 1, mime: 'text/plain; charset=utf-8',
    bytes: [...expected], liveUrls: 0, errors: [],
  });
  await expect(page.locator('span', {
    hasText: /^Decompressed bytes saved\.$/,
  })).toBeVisible();
  expect(downloads).toHaveLength(1);
  await expect(result).toBeVisible();
  expect(interactionRequests).toEqual([]);
  expect(externalRequests).toEqual([]);
});

for (const emptyOutput of [
  { mode: 'text', fileName: 'chimera-decompressed.txt', mime: 'text/plain; charset=utf-8' },
  { mode: 'binary', fileName: 'chimera-decompressed.bin', mime: 'application/octet-stream' },
]) {
  test(`GivenEmptyGzipFile_When${emptyOutput.mode}DecompressedAndSaved_ThenExactEmptyFileTransfersOffline`, async ({ page }) => {
    const archive = Buffer.from('1f8b08000000000002ff03000000000000000000', 'hex');
    const expected = Buffer.alloc(0);
    const externalRequests = [];
    const interactionRequests = [];
    const downloads = [];
    page.on('download', download => downloads.push(download));
    page.on('request', request => {
      const url = new URL(request.url());
      if ((url.protocol === 'http:' || url.protocol === 'https:') && url.hostname !== '127.0.0.1') {
        externalRequests.push(request.url());
      }
    });
    await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);

    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Decompress GZIP', exact: true }).click();
    page.on('request', request => recordHttpRequest(request, interactionRequests));
    const chooserPromise = page.waitForEvent('filechooser');
    await page.getByRole('button', { name: 'Load GZIP file', exact: true }).click();
    await (await chooserPromise).setFiles({
      name: 'empty.gzip',
      mimeType: 'application/gzip',
      buffer: archive,
    });
    if (emptyOutput.mode === 'binary') {
      await page.getByText('Binary', { exact: true }).click();
    }
    await page.getByRole('button', { name: 'Decompress', exact: true }).click();
    const result = page.getByRole('region', {
      name: `Decompressed result Decompression succeeded. Input bytes: ${archive.length} Output bytes: 0`,
      exact: true,
    });
    await expect(result).toBeVisible();

    await page.getByRole('button', { name: 'Save decompressed bytes', exact: true }).press('Enter');
    await expect.poll(() => downloads.length).toBe(1);
    const [download] = downloads;
    expect(download.suggestedFilename()).toBe(emptyOutput.fileName);
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    expect(Buffer.concat(chunks)).toEqual(expected);
    await expect.poll(() => page.evaluate(() => ({
      name: window.__chimeraSavedName,
      count: window.__chimeraSaveCount,
      mime: window.__chimeraSavedMime,
      bytes: window.__chimeraSavedBytes,
      liveUrls: window.__chimeraLiveDownloadUrlCount,
      errors: window.__chimeraGzipSaveErrors,
    }))).toEqual({
      name: emptyOutput.fileName, count: 1, mime: emptyOutput.mime,
      bytes: [], liveUrls: 0, errors: [],
    });
    await expect(page.locator('span', {
      hasText: /^Decompressed bytes saved\.$/,
    })).toBeVisible();
    expect(downloads).toHaveLength(1);
    await expect(result).toBeVisible();
    expect(interactionRequests).toEqual([]);
    expect(externalRequests).toEqual([]);
  });
}

test('GivenArbitraryBinaryGzipFile_WhenBinaryDecompressedAndDownloaded_ThenExactBytesTransferOffline', async ({ page }) => {
  const archive = Buffer.from('1f8b08000000000002ff63f8dfc0f88f81970b00f65e06e708000000', 'hex');
  const expected = Buffer.from('00ff8001fe000d0a', 'hex');
  const externalRequests = [];
  const interactionRequests = [];
  const downloads = [];
  page.on('download', download => downloads.push(download));
  page.on('request', request => {
    const url = new URL(request.url());
    if ((url.protocol === 'http:' || url.protocol === 'https:') && url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });
  await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);

  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decompress GZIP', exact: true }).click();
  page.on('request', request => recordHttpRequest(request, interactionRequests));
  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Load GZIP file', exact: true }).click();
  await (await chooserPromise).setFiles({
    name: 'archive.not-gz',
    mimeType: 'application/octet-stream',
    buffer: archive,
  });
  await page.getByText('Binary', { exact: true }).click();
  await page.getByRole('button', { name: 'Decompress', exact: true }).click();
  const result = page.getByRole('region', {
    name: `Decompressed result Decompression succeeded. Input bytes: ${archive.length} Output bytes: ${expected.length}`,
    exact: true,
  });
  await expect(result).toBeVisible();
  await expect(page.getByRole('button', { name: 'Copy decompressed text', exact: true })).toHaveCount(0);

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save decompressed bytes', exact: true }).press('Enter');
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe('chimera-decompressed.bin');
  const chunks = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk);
  expect(Buffer.concat(chunks)).toEqual(expected);
  await expect.poll(() => page.evaluate(() => ({
    name: window.__chimeraSavedName,
    count: window.__chimeraSaveCount,
    mime: window.__chimeraSavedMime,
    bytes: window.__chimeraSavedBytes,
    liveUrls: window.__chimeraLiveDownloadUrlCount,
    errors: window.__chimeraGzipSaveErrors,
  }))).toEqual({
    name: 'chimera-decompressed.bin', count: 1, mime: 'application/octet-stream',
    bytes: [...expected], liveUrls: 0, errors: [],
  });
  expect(downloads).toHaveLength(1);
  expect(interactionRequests).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('GivenCorruptGzipFile_WhenDecompressionIsAttempted_ThenRedactedFailurePublishesNoOutputOffline', async ({ page }) => {
  const externalRequests = [];
  const interactionRequests = [];
  page.on('request', request => {
    const url = new URL(request.url());
    if ((url.protocol === 'http:' || url.protocol === 'https:') && url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decompress GZIP', exact: true }).click();
  page.on('request', request => recordHttpRequest(request, interactionRequests));
  const chooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Load GZIP file', exact: true }).click();
  await (await chooserPromise).setFiles({
    name: 'corrupt.bin',
    mimeType: 'application/octet-stream',
    buffer: Buffer.from([31, 139, 8, 0, 1]),
  });
  await page.getByRole('button', { name: 'Decompress', exact: true }).click();
  await expect(page.getByText('The GZIP data could not be decompressed.', { exact: true }).last()).toBeVisible();
  await expect(page.getByRole('region', { name: /Decompressed result/ })).toHaveCount(0);
  await expect(page.getByText('Input bytes: 5', { exact: true })).toHaveCount(0);
  expect(interactionRequests).toEqual([]);
  expect(externalRequests).toEqual([]);
});

// Literal public metadata, independent of the parser and serializer under test.
const certificateJsonFields =
  '"version":3,"serialNumberHex":"01AB",' +
  '"subject":[{"oid":"2.5.4.3","name":"commonName","value":"example.test"},' +
  '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"},' +
  '{"oid":"1.2.3.4","name":null,"value":"Unknown attribute"}],' +
  '"issuer":[{"oid":"2.5.4.3","name":"commonName","value":"Example CA"},' +
  '{"oid":"2.5.4.10","name":"organizationName","value":"Chimera fixtures"}],' +
  '"notBefore":"2024-01-01T00:00:00.000Z",' +
  '"notAfter":"2034-01-01T00:00:00.000Z",' +
  '"signatureAlgorithm":{"oid":"1.2.840.113549.1.1.11",' +
  '"name":"sha256WithRSAEncryption"},' +
  '"publicKeyAlgorithm":{"oid":"1.2.840.113549.1.1.1","name":"rsaEncryption"},' +
  '"extensions":[{"oid":"2.5.29.19","name":"basicConstraints","critical":true},' +
  '{"oid":"1.2.3.5","name":null,"critical":false}],';

for (const [source, target] of [['pem', 'der'], ['der', 'pem']]) {
  test(`GivenCertificate${source}_WhenConvertedAndDownloaded_ThenExact${target}FixtureAndSafeSemanticsTransferOffline`, async ({ page }) => {
    const pem = readFileSync(new URL('../fixtures/certificates/certificate.pem', import.meta.url));
    const der = readFileSync(new URL('../fixtures/certificates/certificate.der', import.meta.url));
    const externalRequests = [];
    const interactionRequests = [];
    page.on('request', request => {
      if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
        externalRequests.push(request.url());
      }
    });
    await page.addInitScript(() => {
      window.__chimeraCopiedText = null;
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: { writeText: async value => { window.__chimeraCopiedText = value; } },
      });
    });
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Convert a certificate', exact: true }).click();
    const textBox = page.getByRole('textbox', { name: 'Certificate (PEM or Base64)', exact: true });
    await expect(textBox).toBeVisible();
    page.on('request', request => {
      if (/^https?:/.test(request.url())) interactionRequests.push(request.url());
    });
    if (source === 'pem') {
      await fillFlutterTextBox(textBox, pem.toString('utf8'));
    } else {
      const chooserPromise = page.waitForEvent('filechooser');
      await page.getByRole('button', { name: 'Load certificate file', exact: true }).click();
      await (await chooserPromise).setFiles({ name: 'certificate.der', mimeType: 'application/octet-stream', buffer: der });
      await expect(page.getByText('Input bytes: 534', { exact: true }).last()).toBeVisible();
    }
    await page.getByRole('checkbox', { name: `Source representation: ${source.toUpperCase()}`, exact: true }).click();
    await page.getByRole('checkbox', { name: `Target representation: ${target.toUpperCase()}`, exact: true }).click();
    await page.getByRole('button', { name: 'Convert', exact: true }).click();
    const result = page.getByRole('region', {
      name: 'Converted certificate Certificate conversion succeeded. ' +
        `Source representation: ${source.toUpperCase()} Target representation: ${target.toUpperCase()} ` +
        `Input bytes: ${source === 'pem' ? 778 : 534} DER bytes: 534 Output bytes: ${target === 'pem' ? 778 : 534}`,
      exact: true,
    });
    await expect(result).toBeVisible();
    const copy = page.getByRole('button', { name: 'Copy converted certificate', exact: true });
    if (target === 'pem') {
      // Selectable output is canvas-rendered and excluded from its safe region
      // announcement. Clipboard output establishes the exact displayed value.
      // Keyboard activation avoids WebKit scrolling only the semantics DOM
      // when these controls sit below the painted Flutter viewport.
      await expect(copy).toBeEnabled();
      await copy.press('Enter');
      await expect.poll(() => page.evaluate(() => window.__chimeraCopiedText)).toBe(pem.toString('utf8'));
    } else {
      await expect(copy).toHaveCount(0);
    }
    const downloadPromise = page.waitForEvent('download');
    const save = page.getByRole('button', { name: 'Save converted certificate', exact: true });
    await expect(save).toBeEnabled();
    await save.press('Enter');
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toBe(`chimera-certificate.${target}`);
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    expect(Buffer.concat(chunks)).toEqual(target === 'der' ? der : pem);
    // Browser download mode returns no destination URI. Its conversion success
    // announcement remains valid; byte-exact download is the save evidence.
    await expect(result).toBeVisible();
    expect(interactionRequests).toEqual([]);
    expect(externalRequests).toEqual([]);
  });
}

for (const [id, oid] of [['ed25519', '1.3.101.112'], ['unknown-key', '2.999.5']]) {
  test(`certificate ${id} public-key algorithm and 1950 UTC metadata survive compiled inspection`, async ({ page }) => {
    const input = readFileSync(new URL(`../fixtures/certificates/${id}.pem`, import.meta.url), 'utf8');
    await page.addInitScript(() => {
      window.__chimeraCopiedText = null;
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: { writeText: async (value) => { window.__chimeraCopiedText = value; } },
      });
    });
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Inspect a certificate', exact: true }).click();
    const interactionRequests = [];
    page.on('request', (request) => {
      if (/^https?:/.test(request.url())) interactionRequests.push(request.url());
    });
    await fillFlutterTextBox(page.getByRole('textbox', { name: 'Certificate (PEM or Base64)', exact: true }), input);
    await page.getByRole('button', { name: 'Inspect', exact: true }).click();
    await expect(page.getByRole('region', {
      name: 'Certificate metadata Certificate inspection succeeded. Representation: PEM Subject attributes: 3 Issuer attributes: 2 Extensions: 2', exact: true,
    })).toBeVisible();
    await page.getByRole('button', { name: 'Copy certificate JSON', exact: true }).click();
    const expected = `{"representation":"pem",${certificateJsonFields}"inputByteCount":509,"derByteCount":335}`
      .replace('2024-01-01T00:00:00.000Z', '1950-01-01T00:00:00.000Z')
      .replace('2034-01-01T00:00:00.000Z', '2049-12-31T23:59:59.000Z')
      .replace('{"oid":"1.2.840.113549.1.1.11","name":"sha256WithRSAEncryption"}', '{"oid":"1.3.101.112","name":null}')
      .replace('{"oid":"1.2.840.113549.1.1.1","name":"rsaEncryption"}', `{"oid":"${oid}","name":null}`);
    await expect.poll(() => page.evaluate(() => window.__chimeraCopiedText)).toBe(expected);
    expect(interactionRequests).toEqual([]);
  });
}

for (const { source, representation, byteCount, label } of [
  { source: 'text', representation: 'pem', byteCount: 778, label: 'PEM' },
  { source: 'file', representation: 'der', byteCount: 534, label: 'DER' },
  { source: 'clipboard', representation: 'base64', byteCount: 713, label: 'Base64' },
]) {
  test(`certificate ${representation} ${source} inspects and copies exact metadata without HTTP requests`, async ({
    page,
  }, testInfo) => {
    const interactionRequests = [];
    const input = readFileSync(
      new URL(`../fixtures/certificates/certificate.${representation}`, import.meta.url),
    );
    await page.addInitScript((clipboardText) => {
      window.__chimeraCopiedText = null;
      window.__chimeraClipboardReads = 0;
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: {
          readText: async () => {
            window.__chimeraClipboardReads++;
            return clipboardText;
          },
          writeText: async (value) => { window.__chimeraCopiedText = value; },
        },
      });
    }, input.toString('utf8'));
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Inspect a certificate', exact: true }).click();
    await expect(page.getByRole('textbox', { name: 'Certificate (PEM or Base64)', exact: true })).toBeVisible();
    page.on('request', (request) => {
      if (/^https?:/.test(request.url())) interactionRequests.push(request.url());
    });

    if (source === 'text') {
      await fillFlutterTextBox(
        page.getByRole('textbox', { name: 'Certificate (PEM or Base64)', exact: true }),
        input.toString('utf8'),
      );
    } else if (source === 'file') {
      const chooserPromise = page.waitForEvent('filechooser');
      await page.getByRole('button', { name: 'Load certificate file' }).click();
      const chooser = await chooserPromise;
      await chooser.setFiles({ name: 'certificate.der', mimeType: 'application/octet-stream', buffer: input });
      await expect(page.getByText('Input bytes: 534', { exact: true }).last()).toBeVisible();
      await page.getByRole('checkbox', { name: 'DER', exact: true }).click();
    } else {
      await page.getByRole('button', { name: 'Paste certificate', exact: true }).click();
      await expect.poll(() => page.evaluate(() => window.__chimeraClipboardReads)).toBe(1);
      await expect(page.getByRole('button', { name: 'Paste certificate', exact: true })).toBeEnabled();
      await page.getByRole('textbox', { name: 'Certificate (PEM or Base64)', exact: true }).click();
      await expect(page.getByRole('textbox', { name: 'Certificate (PEM or Base64)', exact: true })).toHaveValue(input.toString('utf8'));
      await page.getByRole('checkbox', { name: 'Base64', exact: true }).click();
    }
    await page.getByRole('button', { name: 'Inspect', exact: true }).click();
    const metadata = page.getByRole('region', {
      name: `Certificate metadata Certificate inspection succeeded. Representation: ${label} Subject attributes: 3 Issuer attributes: 2 Extensions: 2`,
      exact: true,
    });
    await expect(metadata).toBeVisible();
    // Full values are intentionally excluded from the region announcement.
    // Preserve rendered canvas evidence as well as asserting the public summary.
    const screenshotPath = testInfo.outputPath(`certificate-${representation}-metadata.png`);
    await metadata.screenshot({ path: screenshotPath });
    await testInfo.attach(`certificate-${representation}-metadata`, {
      path: screenshotPath,
      contentType: 'image/png',
    });
    await page.getByRole('button', { name: 'Copy certificate JSON', exact: true }).click();
    await expect.poll(() => page.evaluate(() => window.__chimeraCopiedText))
      .toBe(`{"representation":"${representation}",${certificateJsonFields}"inputByteCount":${byteCount},"derByteCount":534}`);
    await expect(page.getByText('Certificate JSON copied.', { exact: true }).last()).toBeVisible();
    expect(interactionRequests).toEqual([]);
  });
}

async function enableFlutterSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached' });
  await placeholder.evaluate((element) => element.click());
  await placeholder.waitFor({ state: 'detached' });
}

async function fillFlutterTextBox(textBox, value) {
  await textBox.click();
  await textBox.press('Control+A');
  await textBox.press('Backspace');
  await textBox.fill(value);
  await expect(textBox).toHaveValue(value);
  await textBox.press('Tab');
}

test('compiled Chimera shell loads without page errors', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));

  const response = await page.goto('/');

  expect(response?.ok()).toBe(true);
  await expect(page).toHaveTitle('Chimera');
  await expect(page.locator('meta[name="description"]')).toHaveAttribute(
    'content',
    'Developer toolbox',
  );
  await expect(
    page.locator('meta[name="apple-mobile-web-app-title"]'),
  ).toHaveAttribute('content', 'Chimera');
  const manifest = await page.evaluate(async () =>
    (await fetch('/manifest.json')).json(),
  );
  expect(manifest).toMatchObject({
    name: 'Chimera',
    short_name: 'Chimera',
    description: 'Developer toolbox',
  });
  expect(pageErrors).toEqual([]);
});

test('cron flow calculates locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Parse a cron expression' }).click();
  await expect(page.getByText('Parse cron expression')).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Cron expression' }),
    '0 9 * * MON-FRI',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Time zone' }),
    'UTC',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Occurrence count' }),
    '1',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: /Reference instant/ }),
    '2026-01-05T12:00:00Z',
  );
  await page.getByRole('button', { name: 'Calculate occurrences' }).click();

  await expect(page.getByText('Cron schedule: 0 9 * * 1-5').last()).toBeVisible();
  await expect(
    page.getByText(/Next: 2026-01-06T09:00:00.000\+00:00/).last(),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('GivenUnfocusedCronInputs_WhenSafariUsesNativeEditing_ThenControllerValuesDetermineExactOccurrences', async ({ page }) => {
  const requests = [];
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.evaluate(`${safariCronDiagnostics}\ninstallCronDiagnostics();`);
  // Match Safari's semantics navigation without a preceding pointer gesture.
  await page.getByRole('button', { name: 'Parse a cron expression', exact: true })
    .evaluate(node => node.click());
  await expect(page.getByRole('textbox', { name: 'Reference instant', exact: true })).toBeVisible();
  await page.context().setOffline(true);
  page.on('request', request => recordHttpRequest(request, requests));
  for (const [label, value] of [
    ['Cron expression', '0 9 * * MON-FRI'],
    ['Time zone', 'UTC'],
    ['Occurrence count', '1'],
    ['Reference instant', '2026-01-05T12:00:00Z'],
  ]) {
    // Resolve the exact element returned to SafariDriver, then use real native
    // input actions. ControlOrMeta maps Select All to the browser's platform.
    const handle = await page.evaluateHandle(({ script, label }) =>
      new Function(script)(label), { script: safariTextBoxElementScript, label });
    const editor = handle.asElement();
    expect(editor).not.toBeNull();
    await editor.click();
    await page.keyboard.press('ControlOrMeta+A');
    let entered = '';
    for (const character of value) {
      await page.keyboard.type(character);
      entered += character;
      await expect.poll(() => page.evaluate(({ script, label, value }) =>
        new Function(script)(label, value, false),
      { script: safariInputObservation, label, value: entered }), { timeout: 3000 }).toBe(true);
    }
    await page.keyboard.press('Tab');
    await expect(page.getByRole('textbox', { name: label, exact: true })).toHaveValue(value);
    await handle.dispose();
  }
  await page.getByRole('button', { name: 'Calculate occurrences', exact: true })
    .evaluate(node => node.click());
  const result = page.locator('span', { hasText: /^Cron schedule:/ }).last();
  await expect(result).toContainText('Cron schedule: 0 9 * * 1-5');
  await expect(result).toContainText('Previous: 2026-01-05T09:00:00.000+00:00');
  await expect(result).toContainText('Next: 2026-01-06T09:00:00.000+00:00');
  const text = await result.textContent();
  expect(text.match(/Previous: /g)).toHaveLength(1);
  expect(text.match(/Next: /g)).toHaveLength(1);
  expect(unexpectedHttpRequests(requests, page.url())).toEqual([]);
  const timeline = await page.evaluate(() => window.__chimeraCronDiagnostics.snapshot());
  await test.info().attach('cron-interaction', {
    body: JSON.stringify(timeline, null, 2), contentType: 'application/json',
  });
  // Prove the diagnostic observes real Flutter editing connections and submit
  // delivery while the exact controller-based result above remains unchanged.
  for (const label of ['Cron expression', 'Time zone', 'Occurrence count', 'Reference instant']) {
    expect(timeline.records.some(record => record.kind === 'listener-added' &&
      record.type === 'input' && record.target.label === label)).toBe(true);
    expect(timeline.records.some(record => record.kind === 'event' &&
      record.type === 'input' && record.target.label === label &&
      record.target.inputHandlers > 0)).toBe(true);
  }
  expect(timeline.records.some(record => record.kind === 'event' &&
    record.type === 'click' && record.target.text === 'Calculate occurrences' &&
    record.trusted === false)).toBe(true);
  expect(timeline.dropped).toBe(0);
  await page.evaluate(() => window.__chimeraCronDiagnostics.stop());
  expect(await page.evaluate(() => '__chimeraCronDiagnostics' in window)).toBe(false);
});

test('date flow converts locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Convert a date' }).click();
  await expect(page.getByText('Convert date').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Date value' }),
    '2026-01-15T12:30:45Z',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Target time zone' }),
    'America/Sao_Paulo',
  );
  await page.getByRole('button', { name: 'Convert date' }).click();

  await expect(
    page.getByText('Converted value: 2026-01-15T09:30:45.000-03:00').last(),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('number base flow converts arbitrary precision locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Convert a number base' }).click();
  await expect(page.getByText('Convert number base').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Number value' }),
    '184467440737095516160',
  );
  await page.getByRole('button', { name: 'Convert number' }).click();

  await expect(
    page.getByRole('group', {
      name: 'Converted value a0000000000000000',
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('text escape flow escapes Unicode locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page
    .getByRole('button', { name: /^Escape text$/ })
    .click();
  await expect(page.getByText('Escape text').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Input text' }),
    'A"\\\né',
  );
  await page.getByRole('button', { name: /^Escape text$/ }).click();

  await expect(
    page.getByRole('group', {
      name: /Escaped text A.*é/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('text unescape flow decodes Unicode locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page
    .getByRole('button', { name: /^Unescape text$/ })
    .click();
  await expect(page.getByText('Unescape text').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Escaped input text' }),
    String.raw`A\"\\\né\u0021`,
  );
  await page.getByRole('button', { name: /^Unescape text$/ }).click();

  await expect(
    page.getByRole('group', {
      name: /Unescaped text A.*é!/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('list comparison flow compares locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Compare lists' }).click();
  await expect(page.getByText('Compare lists').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Left list' }),
    'alpha\nleft\n',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Right list' }),
    'alpha\nright',
  );
  await page.getByRole('button', { name: 'Compare lists' }).click();

  await expect(
    page.getByRole('region', { name: /Left only Items: 2 left/ }),
  ).toBeVisible();
  await expect(
    page.getByRole('region', { name: /Right only Items: 1 right/ }),
  ).toBeVisible();
  await expect(
    page.getByRole('region', { name: /Intersection Items: 1 alpha/ }),
  ).toBeVisible();
  await expect(page.getByText('Equal: no').last()).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('text analysis flow counts locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Analyze text' }).click();
  await expect(page.getByText('Analyze text').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Text to analyze' }),
    'A\nB',
  );
  await page.getByRole('button', { name: 'Analyze text' }).click();

  await expect(
    page.getByRole('region', {
      name: /Analyze text Characters: 3 Words: 2 Lines: 2 UTF-8 bytes: 3/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('text transformation flow runs locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Transform text' }).click();
  await expect(page.getByText('Transform text').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Input text' }),
    'ÉCOLE',
  );
  await page.getByRole('button', { name: 'Transform text' }).click();

  await expect(
    page.getByRole('group', { name: /Transformed text école/ }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('text comparison flow runs locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Compare text' }).click();
  await expect(page.getByText('Compare text').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Left text' }),
    'alpha beta',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Right text' }),
    'alpha brave beta',
  );
  await page.getByRole('button', { name: 'Compare text' }).click();

  await expect(
    page.getByRole('region', {
      name: /Text comparison result.*Removed: alpha beta.*Added: alpha brave beta.*Added: 1.*Removed: 1.*Unchanged: 0/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('JSON array flow renders locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page
    .getByRole('button', { name: 'Convert a JSON array to a table' })
    .click();
  await expect(page.getByText('Convert JSON array to table').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JSON array' }),
    '[{"name":"Ada","meta":{"x":1}}]',
  );
  await page.getByRole('button', { name: 'Create table' }).click();

  await expect(page.getByText('Ada').last()).toBeVisible();
  await expect(page.getByText('{"x":1}').last()).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('JSON CSV flow serializes locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page
    .getByRole('button', { name: 'Convert a JSON array to CSV' })
    .click();
  await expect(page.getByText('Convert JSON array to CSV').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JSON array' }),
    '[{"name":"Ada","meta":{"x":1}}]',
  );
  await page.getByRole('button', { name: 'Create CSV' }).click();

  await expect(
    page.getByRole('group', {
      name: 'CSV result name,meta Ada,"{""x"":1}"',
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('JSON YAML flow serializes locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Convert JSON to YAML' }).click();
  await expect(page.getByText('Convert JSON to YAML').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JSON value' }),
    '{"name":"Ada","meta":{"x":1}}',
  );
  await page.getByRole('button', { name: 'Create YAML' }).click();

  await expect(
    page.getByRole('group', {
      name: 'YAML result name: Ada meta: x: 1',
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('JSON format flow formats locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Format JSON' }).click();
  await expect(page.getByText('Format JSON').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JSON value' }),
    '{"name":"Ada","meta":{"x":1},"large":9007199254740993,"underflow":1e-400}',
  );
  await page.getByRole('button', { name: 'Format JSON' }).click();

  await expect(
    page.getByRole('group', {
      name: /Formatted JSON result.*"name": "Ada".*"x": 1.*"large": 9007199254740993.*"underflow": 1e-400/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('SQL format flow formats locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Format SQL' }).click();
  await expect(page.getByText('Format SQL').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'SQL statement' }),
    'select id,name from users where active=true',
  );
  await page.getByRole('button', { name: 'Format SQL' }).click();

  await expect(
    page.getByRole('group', {
      name: /Formatted SQL result.*SELECT.*id.*name.*FROM users.*WHERE active = TRUE/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('XML format flow formats locally without external requests', async ({ page }) => {
  const externalRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await expect(page).toHaveTitle('Chimera');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Format XML' }).click();
  await expect(page.getByText('Format XML').first()).toBeVisible();

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'XML document' }),
    '<root><developer name="Ada"/></root>',
  );
  await page.getByRole('button', { name: 'Format XML' }).click();

  await expect(
    page.getByRole('group', {
      name: /Formatted XML result.*root.*developer name="Ada"/,
    }),
  ).toBeVisible();
  expect(externalRequests).toEqual([]);
});

test('Base64 binary file flow transfers exact output locally without external requests', async ({
  page,
}) => {
  test.setTimeout(60_000);
  const externalRequests = [];
  const interactionRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });
  await page.addInitScript(() => {
    window.__chimeraCopiedText = null;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        writeText: async (value) => {
          window.__chimeraCopiedText = value;
        },
      },
    });
  });

  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Encode Base64' }).click();
  await expect(page.getByText('Base64 encode').first()).toBeVisible();
  page.on('request', (request) => interactionRequests.push(request.url()));

  const fileChooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Load bytes from file' }).click();
  const fileChooser = await fileChooserPromise;
  await fileChooser.setFiles({
    name: 'bytes.bin',
    mimeType: 'application/octet-stream',
    buffer: Buffer.from([0x00, 0xff]),
  });
  await expect(page.getByText('Input bytes: 2').last()).toBeVisible();

  await page.getByRole('button', { name: 'Encode', exact: true }).click();
  await expect(
    page.getByRole('region', {
      name: /Base64 encoding succeeded\. Input bytes: 2 Output characters: 4/,
    }),
  ).toBeVisible();

  await page.getByRole('button', { name: 'Copy Base64' }).click();
  await expect
    .poll(() => page.evaluate(() => window.__chimeraCopiedText))
    .toBe('AP8=');

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save Base64' }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe('chimera-base64.txt');
  const stream = await download.createReadStream();
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  expect(Buffer.concat(chunks).toString('utf8')).toBe('AP8=');
  expect(interactionRequests).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('Base64 PNG decode previews and downloads exact bytes without requests', async ({
  page,
}) => {
  test.setTimeout(60_000);
  const pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  const expectedPng = Buffer.from(pngBase64, 'base64');
  const externalRequests = [];
  const interactionRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (
      (url.protocol === 'http:' || url.protocol === 'https:') &&
      url.hostname !== '127.0.0.1'
    ) {
      externalRequests.push(request.url());
    }
  });

  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decode Base64' }).click();
  await expect(page.getByText('Base64 decode').first()).toBeVisible();
  page.on('request', (request) => interactionRequests.push(request.url()));

  await page.getByRole('checkbox', { name: 'Binary' }).click();
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Base64 to decode' }),
    pngBase64,
  );
  await page.getByRole('button', { name: 'Decode', exact: true }).click();

  await expect(
    page.getByRole('region', {
      name: /Base64 decoding succeeded\..*Output mode: Binary.*Output bytes: 68.*Image preview available\./,
    }),
  ).toBeVisible();
  expect(
    interactionRequests.filter((url) => /^https?:/.test(url)),
  ).toEqual([]);

  const downloadPromise = page.waitForEvent('download');
  const save = page.getByRole('button', { name: 'Save decoded bytes', exact: true });
  await expect(save).toBeEnabled();
  // Auto-scrolling the semantics DOM can leave Flutter's canvas unscrolled.
  await save.press('Enter');
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe('chimera-decoded.png');
  const stream = await download.createReadStream();
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  expect(Buffer.concat(chunks)).toEqual(expectedPng);
  expect(
    interactionRequests.filter((url) => /^https?:/.test(url)),
  ).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('JWT HMAC creation signs exact compact token locally without requests', async ({ page }) => {
  const expectedToken =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
    'eyJicm93c2VyIjp0cnVlfQ.' +
    '0dUDVWt8or9ruXzLa8i7tl0xCUaIVBGl_V-bWrFtgpA';
  const externalRequests = [];
  const interactionRequests = [];
  page.on('request', request => {
    if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
  });
  await page.addInitScript(() => {
    window.__chimeraCopiedText = null;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        writeText: async value => {
          window.__chimeraCopiedText = value;
        },
      },
    });
  });
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Create JWT', exact: true }).click();
  page.on('request', request => recordHttpRequest(request, interactionRequests));
  await fillFlutterTextBox(page.getByRole('textbox', { name: 'Claims JSON' }), '{"browser":true}');
  await fillFlutterTextBox(page.getByRole('textbox', { name: 'Private signing key' }), '0123456789abcdef0123456789abcdef');
  await page.getByRole('button', { name: 'Create and sign', exact: true }).click();
  const result = page.getByRole('region', { name: 'Signed JWT JWT creation succeeded.', exact: true });
  await expect(result).toBeVisible();
  await page.getByRole('button', { name: 'Copy JWT', exact: true }).click();
  await expect
    .poll(() => page.evaluate(() => window.__chimeraCopiedText))
    .toBe(expectedToken);
  await expect(page.getByRole('textbox', { name: 'Claims JSON' })).toHaveValue('');
  await expect(page.getByRole('textbox', { name: 'Private signing key' })).toHaveValue('');
  expect(interactionRequests).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('JWT asymmetric creation signs RSA and ECDSA tokens locally', async ({ page }) => {
  const externalRequests = [];
  const interactionRequests = [];
  let recordInteractions = false;
  page.on('request', request => {
    if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') {
      externalRequests.push(request.url());
    }
    if (recordInteractions) recordHttpRequest(request, interactionRequests);
  });
  await page.addInitScript(() => {
    window.__chimeraCopiedText = null;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        writeText: async value => {
          window.__chimeraCopiedText = value;
        },
      },
    });
  });
  const rsa = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const ec = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  for (const scenario of [
    {
      algorithm: 'RS256',
      key: rsa.privateKey,
      verifyOptions: rsa.publicKey,
    },
    {
      algorithm: 'ES256',
      key: ec.privateKey,
      verifyOptions: { key: ec.publicKey, dsaEncoding: 'ieee-p1363' },
    },
  ]) {
    recordInteractions = false;
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Create JWT', exact: true }).click();
    recordInteractions = true;
    await page.getByRole('button', { name: 'Signing algorithm HS256', exact: true }).click();
    await page.getByRole('menuitem', { name: scenario.algorithm, exact: true }).click();
    await fillFlutterTextBox(
      page.getByRole('textbox', { name: 'Claims JSON' }),
      JSON.stringify({ browser: true, family: scenario.algorithm }),
    );
    await fillFlutterTextBox(
      page.getByRole('textbox', { name: 'Private signing key' }),
      JSON.stringify(scenario.key.export({ format: 'jwk' })),
    );
    await page.getByRole('button', { name: 'Create and sign', exact: true }).click();
    await expect(page.getByRole('region', {
      name: 'Signed JWT JWT creation succeeded.',
      exact: true,
    })).toBeVisible();
    await page.getByRole('button', { name: 'Copy JWT', exact: true }).click();
    await expect.poll(() => page.evaluate(() => window.__chimeraCopiedText)).not.toBeNull();
    const token = await page.evaluate(() => window.__chimeraCopiedText);
    const segments = token.split('.');
    expect(segments).toHaveLength(3);
    expect(JSON.parse(Buffer.from(segments[0], 'base64url').toString('utf8'))).toMatchObject({
      alg: scenario.algorithm,
      typ: 'JWT',
    });
    expect(JSON.parse(Buffer.from(segments[1], 'base64url').toString('utf8'))).toEqual({
      browser: true,
      family: scenario.algorithm,
    });
    expect(verify(
      'sha256',
      Buffer.from(`${segments[0]}.${segments[1]}`),
      scenario.verifyOptions,
      Buffer.from(segments[2], 'base64url'),
    )).toBe(true);
    await expect(page.getByRole('textbox', { name: 'Claims JSON' })).toHaveValue('');
    await expect(page.getByRole('textbox', { name: 'Private signing key' })).toHaveValue('');
    recordInteractions = false;
  }
  expect(interactionRequests).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('JWT inspection decodes and verifies HMAC RSA ECDSA and failed signatures locally', async ({ page }) => {
  const externalRequests = [];
  const interactionRequests = [];
  let recordInteractions = false;
  page.on('request', request => {
    if (
      recordInteractions &&
      /^https?:/.test(request.url()) &&
      new URL(request.url()).hostname !== '127.0.0.1'
    ) {
      externalRequests.push(request.url());
    }
    if (recordInteractions) recordHttpRequest(request, interactionRequests);
  });
  await page.addInitScript(() => {
    window.__chimeraCopiedText = null;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: {
        writeText: async value => {
          window.__chimeraCopiedText = value;
        },
      },
    });
  });

  const hmacKey = '0123456789abcdef0123456789abcdef';
  const rsa = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const ec = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const compact = (algorithm, name, signer) => {
    const header = Buffer.from(JSON.stringify({ alg: algorithm, typ: 'JWT' })).toString('base64url');
    const claims = Buffer.from(JSON.stringify({ browserInspect: name })).toString('base64url');
    return `${header}.${claims}.${signer(`${header}.${claims}`).toString('base64url')}`;
  };
  const hmacToken = name => compact(
    'HS256',
    name,
    input => createHmac('sha256', hmacKey).update(input).digest(),
  );
  const scenarios = [
    { name: 'decode-only', token: hmacToken('decode-only'), key: null, status: 'not-requested' },
    { name: 'hmac', token: hmacToken('hmac'), key: hmacKey, status: 'verified' },
    {
      name: 'rsa',
      token: compact('RS256', 'rsa', input => sign('sha256', Buffer.from(input), rsa.privateKey)),
      key: JSON.stringify(rsa.publicKey.export({ format: 'jwk' })),
      status: 'verified',
    },
    {
      name: 'ecdsa',
      token: compact(
        'ES256',
        'ecdsa',
        input => sign('sha256', Buffer.from(input), {
          key: ec.privateKey,
          dsaEncoding: 'ieee-p1363',
        }),
      ),
      key: JSON.stringify(ec.publicKey.export({ format: 'jwk' })),
      status: 'verified',
    },
    {
      name: 'failed',
      token: hmacToken('failed'),
      key: 'fedcba9876543210fedcba9876543210',
      status: 'failed',
    },
  ];

  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Inspect JWT', exact: true }).click();
  recordInteractions = true;

  for (const scenario of scenarios) {
    await fillFlutterTextBox(
      page.getByRole('textbox', { name: 'JWT', exact: true }),
      scenario.token,
    );
    if (scenario.key !== null) {
      await fillFlutterTextBox(
        page.getByRole('textbox', { name: 'Optional verification key', exact: true }),
        scenario.key,
      );
    }
    await page.getByRole('button', { name: 'Inspect and verify', exact: true }).click();
    const status = {
      'not-requested': 'Not requested',
      verified: 'Verified',
      failed: 'Failed — decoded data is untrusted',
    }[scenario.status];
    const result = page.getByRole('region', {
      name: new RegExp(`JWT inspection result.*${status}`),
    });
    await expect(result).toBeVisible();
    if (scenario.status === 'failed') {
      await expect(result.getByText(
        'Signature verification failed. Decoded data is untrusted.',
        { exact: true },
      )).toBeVisible();
    }
    await page.evaluate(() => {
      window.__chimeraCopiedText = null;
    });
    await page.getByRole('button', { name: 'Copy inspection result', exact: true }).click();
    await expect.poll(() => page.evaluate(() => window.__chimeraCopiedText)).not.toBeNull();
    const copied = JSON.parse(await page.evaluate(() => window.__chimeraCopiedText));
    expect(copied).toEqual({
      header: { alg: scenario.name === 'rsa' ? 'RS256' : scenario.name === 'ecdsa' ? 'ES256' : 'HS256', typ: 'JWT' },
      claims: { browserInspect: scenario.name },
      verification: scenario.status,
    });
    await expect(page.getByRole('textbox', { name: 'JWT', exact: true })).toHaveValue('');
    await expect(
      page.getByRole('textbox', { name: 'Optional verification key', exact: true }),
    ).toHaveValue('');
  }
  const nonFiniteToken = compact(
    'HS256',
    'unused',
    input => createHmac('sha256', hmacKey).update(input).digest(),
  ).replace(
    Buffer.from(JSON.stringify({ browserInspect: 'unused' })).toString('base64url'),
    Buffer.from('{"value":1e400}').toString('base64url'),
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'JWT', exact: true }),
    nonFiniteToken,
  );
  await page.getByRole('button', { name: 'Inspect and verify', exact: true }).click();
  await expect(page.locator('span', {
    hasText: /^The JWT inspection request is invalid\.$/,
  })).toBeVisible();
  await expect(page.getByRole('region', { name: /JWT inspection result/ })).toHaveCount(0);
  expect(interactionRequests.filter(
    url => !new URL(url).pathname.startsWith('/font-fallback/'),
  )).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('QR encoding generates and downloads an exact local PNG then clears invalid state', async ({ page }) => {
  const externalRequests = [];
  const interactionRequests = [];
  let recordInteractions = false;
  page.on('request', request => {
    if (
      recordInteractions &&
      /^https?:/.test(request.url()) &&
      new URL(request.url()).hostname !== '127.0.0.1'
    ) {
      externalRequests.push(request.url());
    }
    if (recordInteractions) recordHttpRequest(request, interactionRequests);
  });

  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Encode QR code', exact: true }).click();
  recordInteractions = true;
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Text to encode', exact: true }),
    'browser Olá 🌍',
  );
  await page.getByRole('button', { name: 'Error correction Medium', exact: true }).click();
  await page.getByRole('menuitem', { name: 'High', exact: true }).click();
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Image size (pixels)', exact: true }),
    '256',
  );
  await page.getByRole('button', { name: 'Generate QR', exact: true }).click();

  await expect(page.getByRole('region', {
    name: /QR encoding result QR encoding succeeded\. 256 x 256, QR version \d+, High\./,
  })).toBeVisible();
  await expect(page.getByRole('img', {
    name: 'Generated QR code preview',
    exact: true,
  })).toBeVisible();
  await expect(
    page.getByRole('textbox', { name: 'Text to encode', exact: true }),
  ).toHaveValue('');

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save PNG', exact: true }).press('Enter');
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe('chimera-qr.png');
  const stream = await download.createReadStream();
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  const png = Buffer.concat(chunks);
  expect(png.subarray(0, 8)).toEqual(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  expect(png.readUInt32BE(16)).toBe(256);
  expect(png.readUInt32BE(20)).toBe(256);

  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Text to encode', exact: true }),
    'discard this source',
  );
  await fillFlutterTextBox(
    page.getByRole('textbox', { name: 'Image size (pixels)', exact: true }),
    '10',
  );
  await page.getByRole('button', { name: 'Generate QR', exact: true }).click();
  await expect(page.locator('span', {
    hasText: /^The QR encoding request is invalid\.$/,
  })).toBeVisible();
  await expect(page.getByRole('region', { name: /QR encoding result/ })).toHaveCount(0);
  await expect(
    page.getByRole('textbox', { name: 'Text to encode', exact: true }),
  ).toHaveValue('');
  expect(interactionRequests.filter(
    url => !new URL(url).pathname.startsWith('/font-fallback/'),
  )).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('QR decoding reads a local image, copies and saves exact Unicode, and rejects corrupt input offline', async ({ page }) => {
  const requests = [];
  let record = false;
  page.on('request', request => { if (record) recordHttpRequest(request, requests); });
  await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decode QR code', exact: true }).click();
  record = true;
  await page.evaluate(() => {
    window.__chimeraQrDecodedText = null;
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText: async text => { window.__chimeraQrDecodedText = text; } },
    });
  });
  const choose = page.getByRole('button', { name: 'Choose PNG, JPEG or BMP image', exact: true });
  const pendingFile = page.waitForEvent('filechooser');
  await choose.click();
  await (await pendingFile).setFiles({
    name: 'unicode.png', mimeType: 'image/png',
    buffer: readFileSync(new URL('../fixtures/encoded/qr/unicode.png', import.meta.url)),
  });
  await expect(page.locator('span', { hasText: /^Image ready to decode\.$/ })).toBeVisible();
  await page.getByRole('button', { name: 'Decode QR', exact: true }).press('Enter');
  await expect(page.getByRole('region', { name: /Decoded QR result QR code decoded\./ })).toBeVisible();
  await expect(page.locator('span', { hasText: /^Image ready to decode\.$/ })).toHaveCount(0);
  await page.getByRole('button', { name: 'Copy text', exact: true }).click();
  await expect.poll(() => page.evaluate(() => window.__chimeraQrDecodedText)).toBe('QR Olá 世界 🌍');
  const pendingSave = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save UTF-8 text', exact: true }).press('Enter');
  const saved = await pendingSave;
  expect(saved.suggestedFilename()).toBe('chimera-qr-decoded.txt');
  const chunks = [];
  for await (const chunk of await saved.createReadStream()) chunks.push(chunk);
  expect(Buffer.concat(chunks)).toEqual(Buffer.from('QR Olá 世界 🌍', 'utf8'));
  await expect.poll(() => page.evaluate(() => window.__chimeraLiveDownloadUrlCount)).toBe(0);
  const pendingCorrupt = page.waitForEvent('filechooser');
  await choose.click();
  await (await pendingCorrupt).setFiles({ name: 'corrupt.png', mimeType: 'image/png', buffer: Buffer.from('corrupt') });
  await expect(page.locator('span', { hasText: /^Image ready to decode\.$/ })).toBeVisible();
  await page.getByRole('button', { name: 'Decode QR', exact: true }).click();
  await expect(page.locator('span', { hasText: /^The image could not be decoded as a QR code\.$/ })).toBeVisible();
  await expect(page.getByRole('region', { name: /Decoded QR result/ })).toHaveCount(0);
  expect(unexpectedHttpRequests(requests, page.url(), true)).toEqual([]);
});

for (const invalid of ['%', '%GG', '%C3%28', '%ED%A0%80']) {
  test(`GivenUrlDecodeMalformed${invalid}_WhenSubmitted_ThenNoResultRemains`, async ({ page }) => {
    await page.goto('/');
    await enableFlutterSemantics(page);
    await page.getByRole('button', { name: 'Decode URL', exact: true }).click();
    const editor = page.getByRole('textbox', { name: 'Percent-encoded text to decode', exact: true });
    await fillFlutterTextBox(editor, invalid);
    await page.getByRole('button', { name: 'Decode', exact: true }).click();
    await expect(page.locator('span', { hasText: /^The URL decoding request is invalid\.$/ })).toBeVisible();
    await expect.poll(() => urlScript(page, 'DecodeNoResult')).toBe(true);
    await expect.poll(() => page.evaluate(
      source => new Function(source)('Percent-encoded text to decode', '', true),
      safariInputObservation,
    )).toBe(true);
  });
}

test('GivenUrlDecodeCopyDenied_WhenOutputAccessFails_ThenResultIsDiscarded', async ({ page }) => {
  await page.addInitScript(() => Object.defineProperty(navigator, 'clipboard', {
    configurable: true, value: { writeText: async () => { throw new Error('private'); } },
  }));
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decode URL', exact: true }).click();
  await fillFlutterTextBox(page.getByRole('textbox', { name: 'Percent-encoded text to decode', exact: true }), '%3Cprivate%3E');
  await page.getByRole('button', { name: 'Decode', exact: true }).click();
  await page.getByRole('button', { name: 'Copy decoded text', exact: true }).click();
  await expect(page.locator('span', { hasText: /^The clipboard text could not be written\.$/ })).toBeVisible();
  await expect.poll(() => urlScript(page, 'DecodeNoResult')).toBe(true);
});

test('GivenUrlDecodeSafariHelpers_WhenClipboardDecodedCopiedAndSaved_ThenExactOutputTransfers', async ({ page }) => {
  await page.addInitScript(`${gzipSaveObserver}\nobserveGzipSaves();`);
  await page.goto('/');
  await enableFlutterSemantics(page);
  await page.getByRole('button', { name: 'Decode URL', exact: true }).click();
  await urlScript(page, 'DecodeSetup');
  await page.getByRole('button', { name: 'Paste text', exact: true }).click();
  await expect.poll(() => page.evaluate(
    source => new Function(source)(
      'Percent-encoded text to decode', '%3C%26%41%F0%9F%99%82%253C+', true,
    ),
    safariInputObservation,
  )).toBe(true);
  await expect.poll(() => urlScript(page, 'DecodeSubmit')).toBe(true);
  await page.keyboard.press('Enter');
  await expect.poll(() => urlScript(page, 'DecodeResult')).toBe(true);
  await expect.poll(() => urlScript(page, 'DecodeCopy')).toBe(true);
  await page.keyboard.press('Enter');
  await expect.poll(() => urlScript(page, 'DecodeCopied', '<&A🙂%3C+', 1)).toBe(true);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save decoded text', exact: true }).click();
  await download;
  await expect.poll(() => urlScript(page, 'DecodeSave', [...Buffer.from('<&A🙂%3C+', 'utf8')], 1)).toBe(true);
});

test('Safari diagnostics capture live values and offscreen semantics without mutating the page', async ({ page }) => {
  const source = readFileSync(new URL('./safari_page_diagnostics.js', import.meta.url), 'utf8');
  await page.setContent('<input aria-label="Reference instant" value="initial"><div style="height: 2000px"></div><div role="status" aria-label="Offscreen result">Next: fixture</div>');
  const input = page.getByRole('textbox', { name: 'Reference instant' });
  await input.fill('2026-01-05T12:00:00Z');
  const before = await page.evaluate(() => ({ active: document.activeElement.outerHTML, scroll: scrollY, html: document.documentElement.outerHTML }));
  const snapshot = await page.evaluate(source => new Function(`${source}\nreturn captureSafariPageDiagnostics();`)(), source);
  expect(snapshot.inputs[0].value).toBe('2026-01-05T12:00:00Z');
  expect(snapshot.activeElement.label).toBe('Reference instant');
  expect(snapshot.textContent).toContain('Next: fixture');
  expect(snapshot.semantics.find(element => element.label === 'Offscreen result').rect.top).toBeGreaterThan(snapshot.viewport.height);
  expect(snapshot.html).toContain('value="initial"');
  expect(await page.evaluate(() => ({ active: document.activeElement.outerHTML, scroll: scrollY, html: document.documentElement.outerHTML }))).toEqual(before);
});
