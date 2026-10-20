import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { unexpectedHttpRequests } from './network_policy.mjs';

const source = readFileSync(new URL('./card_browser.js', import.meta.url), 'utf8');
const saveSource = readFileSync(new URL('./gzip_save_observer.js', import.meta.url), 'utf8');
const syntheticLabel = 'Synthetic test data - not for real transactions';

async function probe(page, action, value) {
  return page.evaluate(
    ({ source, action, value }) => new Function(`${source}\nreturn cardProbe(arguments[0], arguments[1]);`)(action, value),
    { source, action, value },
  );
}

function visibleText(page, text) {
  const escaped = text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return page.locator('span', { hasText: new RegExp(`^${escaped}$`) });
}

async function fillCount(count, value) {
  await count.click();
  await expect(count).toBeFocused();
  await count.fill(value);
  await count.press('Tab');
  await expect(count).toHaveValue(value);
}

async function openCard(page) {
  await page.goto('/');
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached' });
  await placeholder.evaluate(node => node.click());
  await page.getByRole('button', { name: 'Generate Synthetic Cards', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'Positive integer count', exact: true })).toBeVisible();
  await page.context().setOffline(true);
  await probe(page, 'setup');
}

test('GivenDefaults_WhenGeneratedCopiedSavedOffline_ThenLabeledSafeTransfer', async ({ page }) => {
  const requests = [];
  await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);
  await openCard(page);
  page.on('request', request => { if (/^https?:/.test(request.url())) requests.push(request.url()); });
  await page.getByRole('button', { name: 'Generate synthetic cards', exact: true }).click();
  await expect(page.getByRole('region', {
    name: new RegExp(`^Generated synthetic cards Synthetic cards generated\\. ${syntheticLabel}`),
  })).toBeVisible();
  await expect.poll(() => probe(page, 'values')).not.toBeNull();
  const values = await probe(page, 'values');
  expect(['4005520201264821', '4242424242424242', '4000056655665556']).toContain(values);
  const transferred = `${syntheticLabel}\n${values}`;
  await expect.poll(() => probe(page, 'copy')).toBe(true);
  await expect.poll(() => probe(page, 'copied', transferred)).toBe(true);
  const downloaded = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save labeled card data', exact: true }).press('Enter');
  const download = await downloaded;
  expect(download.suggestedFilename()).toBe('chimera-synthetic-cards.txt');
  const chunks = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk);
  expect(Buffer.concat(chunks)).toEqual(Buffer.from(transferred));
  await expect.poll(() => probe(page, 'saved', [...Buffer.from(transferred)])).toBe(true);
  await fillCount(page.getByRole('textbox', { name: 'Positive integer count', exact: true }), '2');
  await expect.poll(() => probe(page, 'noResult')).toBe(true);
  expect(unexpectedHttpRequests(requests, page.url())).toEqual([]);
});

for (const [network, catalogue] of Object.entries({
  Visa: ['4005520201264821', '4242424242424242', '4000056655665556'],
  Mastercard: ['5500005555555559', '5555555555554444', '2223003122003222'],
  'American Express': ['340353278080900', '378282246310005', '371449635398431'],
  Discover: ['6011003179988686', '6011111111111117', '6011000990139424'],
})) {
  test(`Given${network}_WhenGeneratedOffline_ThenPublishedValueReturns`, async ({ page }) => {
    await openCard(page);
    await expect.poll(() => probe(page, 'openNetwork')).toBe(true);
    await expect.poll(() => probe(page, 'option', network)).toBe(true);
    await page.getByRole('button', { name: 'Generate synthetic cards', exact: true }).click();
    await expect.poll(() => probe(page, 'values')).not.toBeNull();
    expect(catalogue).toContain(await probe(page, 'values'));
  });
}

for (const failure of ['validation', 'processing', 'copy', 'save']) {
  test(`Given${failure}Failure_WhenActionRunsOffline_ThenVisibleErrorWithoutPartialPan`, async ({ page }) => {
    const requests = [];
    await openCard(page);
    page.on('request', request => { if (/^https?:/.test(request.url())) requests.push(request.url()); });
    if (failure === 'validation') await fillCount(page.getByRole('textbox', { name: 'Positive integer count', exact: true }), '0');
    if (failure === 'processing') await probe(page, 'entropyFailure');
    await page.getByRole('button', { name: 'Generate synthetic cards', exact: true }).click();
    if (failure === 'copy' || failure === 'save') {
      await expect.poll(() => probe(page, 'values')).not.toBeNull();
      await probe(page, `${failure}Failure`);
      await page.getByRole('button', { name: failure === 'copy' ? 'Copy labeled card data' : 'Save labeled card data', exact: true }).evaluate(node => node.click());
    }
    const message = {
      validation: 'Choose Visa, Mastercard, American Express, or Discover and a positive integer count.',
      processing: 'Synthetic card generation failed. No card numbers were produced.',
      copy: 'The synthetic card result could not be copied.',
      save: 'The synthetic card result could not be written.',
    }[failure];
    await expect(visibleText(page, message)).toBeVisible();
    await expect.poll(() => probe(page, 'noResult')).toBe(true);
    expect(unexpectedHttpRequests(requests, page.url())).toEqual([]);
  });
}
