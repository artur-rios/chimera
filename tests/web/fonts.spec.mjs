import { expect, test } from '@playwright/test';

test('GivenWebBuild_WhenBootstrappedAtRootOrSubpath_ThenFallbackStaysInAppOrigin', async ({ page, baseURL }) => {
  // Execute the actual generated bootstrap, capturing its public loader boundary.
  // Removing the local fallback configuration must fail even for Latin-only UI.
  for (const appPath of ['/', '/tools/chimera/']) {
    await page.goto('/manifest.json');
    await page.evaluate(base => {
      document.head.innerHTML = `<base href="${base}">`;
      window._flutter = { loader: { load: options => { window.startupOptions = options; } } };
    }, new URL(appPath, baseURL).href);
    await page.addScriptTag({ url: new URL('/flutter_bootstrap.js', baseURL).href });
    const configuration = await page.evaluate(() => window.startupOptions?.config);
    expect(configuration?.fontFallbackBaseUrl).toBe(new URL(`${appPath}font-fallback/`, baseURL).href);
  }
});

test('GivenBundledEmoji_WhenEdited_ThenRealGlyphsRenderWithoutRequests', async ({ page }, testInfo) => {
  const externalRequests = [];
  const fontResponses = [];
  page.on('request', request => {
    if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') externalRequests.push(request.url());
  });
  page.on('response', response => {
    if (response.url().endsWith('/assets/fonts/Noto-COLRv1.ttf')) fontResponses.push(response);
  });
  await page.goto('/');
  await openGzip(page);
  expect(fontResponses).toHaveLength(1);
  expect(fontResponses[0].ok()).toBe(true);
  const fontBytes = await fontResponses[0].body();
  // Verify the packaged font parses in the same CanvasKit used by the app and
  // has actual glyph IDs, independently of DOM text/semantics preservation.
  const glyphs = await page.evaluate(base64 => {
    const ck = window.flutterCanvasKit;
    const bytes = Uint8Array.from(atob(base64), character => character.charCodeAt(0));
    const face = ck.Typeface.MakeFreeTypeFaceFromData(bytes);
    if (!face) return [];
    const font = new ck.Font(face, 24);
    const ids = Array.from(font.getGlyphIDs('🌍😀🚀'));
    font.delete();
    face.delete();
    return ids;
  }, fontBytes.toString('base64'));
  expect(glyphs).toHaveLength(3);
  expect(glyphs.every(id => id > 0)).toBe(true);
  const interactionRequests = [];
  page.on('request', request => {
    if (/^https?:/.test(request.url())) interactionRequests.push(request.url());
  });
  const field = page.getByRole('textbox', { name: 'Text to compress', exact: true });
  await field.click();
  await field.press('Control+A');
  await field.press('Backspace');
  await field.fill('Olá 🌍 😀 🚀 👩🏽‍💻 👨‍👩‍👧‍👦 🇧🇷');
  await field.press('Tab');
  await expect(field).toHaveValue('Olá 🌍 😀 🚀 👩🏽‍💻 👨‍👩‍👧‍👦 🇧🇷');
  await expect(page.getByRole('button', { name: 'Compress', exact: true })).toBeEnabled();
  const screenshotPath = testInfo.outputPath('rendered-local-emoji.png');
  await page.screenshot({ path: screenshotPath });
  await testInfo.attach('rendered-local-emoji', {
    path: screenshotPath, contentType: 'image/png',
  });
  expect(interactionRequests).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('GivenUnbundledScript_WhenFallbackRuns_ThenOnlySameOriginIsContacted', async ({ page }) => {
  const requests = [];
  page.on('request', request => {
    if (/^https?:/.test(request.url())) requests.push(request.url());
  });
  await page.goto('/');
  await openGzip(page);
  const field = page.getByRole('textbox', { name: 'Text to compress', exact: true });
  // Egyptian hieroglyphs are intentionally outside the bundled emoji repertoire.
  await field.click();
  await field.press('Control+A');
  await field.press('Backspace');
  await field.fill('𓀀');
  await field.press('Tab');
  await expect(page.getByRole('button', { name: 'Compress', exact: true })).toBeEnabled();
  await expect.poll(() => requests.some(url => new URL(url).pathname.startsWith('/font-fallback/'))).toBe(true);
  await expect(field).toHaveValue('𓀀');
  expect(requests.filter(url => new URL(url).hostname !== '127.0.0.1')).toEqual([]);
});

test('GivenUnavailablePlatformFonts_WhenLatinControlsRender_ThenRobotoMetricsArePreserved', async ({ browser, page, baseURL }) => {
  const userAgent = await page.evaluate(() => navigator.userAgent);
  const widths = [];
  // The Linux theme explicitly uses bundled Roboto. The macOS theme requests
  // an unavailable system font: its Latin fallback must have the same metrics.
  for (const platform of ['X11; Linux x86_64', 'Macintosh; Intel Mac OS X 10_15_7']) {
    const context = await browser.newContext({
      userAgent: userAgent.replace(/\([^)]*\)/, `(${platform})`),
    });
    try {
      await context.addInitScript(value => {
        Object.defineProperty(navigator, 'platform', { value });
      }, platform.startsWith('Macintosh') ? 'MacIntel' : 'Linux x86_64');
      const platformPage = await context.newPage();
      await platformPage.goto(baseURL);
      await openGzip(platformPage);
      const box = await platformPage.getByRole('button', { name: 'Load file bytes', exact: true }).boundingBox();
      widths.push(box.width);
    } finally {
      await context.close();
    }
  }
  expect(widths[1]).toBeCloseTo(widths[0], 2);
});

async function openGzip(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached' });
  await placeholder.evaluate(element => element.click());
  await placeholder.waitFor({ state: 'detached' });
  await page.getByRole('button', { name: 'Compress to GZIP', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'Text to compress', exact: true })).toBeVisible();
}
