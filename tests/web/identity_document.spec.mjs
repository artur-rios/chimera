import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { unexpectedHttpRequests } from './network_policy.mjs';
import { fillFlutterTextInput, observeFlutterTextInput } from './flutter_text_input.mjs';

const source = readFileSync(new URL('./identity_document_browser.js', import.meta.url), 'utf8');
const saveSource = readFileSync(new URL('./gzip_save_observer.js', import.meta.url), 'utf8');
const syntheticLabel = 'Synthetic identity test data - not proof of issuance';

async function probe(page, action, value) {
  return page.evaluate(
    ({ source, action, value }) => new Function(`${source}\nreturn identityDocumentProbe(arguments[0], arguments[1]);`)(action, value),
    { source, action, value },
  );
}

function visibleText(page, text) {
  const escaped = text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return page.locator('span', { hasText: new RegExp(`^${escaped}$`) });
}

async function openDocument(page) {
  await observeFlutterTextInput(page);
  await page.goto('/');
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached' });
  await placeholder.evaluate(node => node.click());
  await page.getByRole('button', { name: 'Generate Synthetic Identity Documents', exact: true }).click();
  await expect(page.getByRole('textbox', { name: 'Positive integer count', exact: true })).toBeVisible();
  await page.context().setOffline(true);
  await probe(page, 'setup');
}

async function select(page, field, option) {
  await expect.poll(() => probe(page, 'openSelect', field)).toBe(true);
  await expect.poll(() => probe(page, 'option', option)).toBe(true);
}

test('GivenDefaults_WhenGeneratedCopiedSavedOffline_ThenLabeledSyntheticTransfer', async ({ page }) => {
  const requests = [];
  await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);
  await openDocument(page);
  page.on('request', request => { if (/^https?:/.test(request.url())) requests.push(request.url()); });
  await fillFlutterTextInput(page.getByRole('textbox', { name: 'Positive integer count', exact: true }), '2');
  await page.getByRole('button', { name: 'Generate synthetic documents', exact: true }).click();
  await expect(page.getByRole('region', {
    name: new RegExp(`^Generated synthetic identity documents Synthetic identity documents generated\\. ${syntheticLabel}`),
  })).toBeVisible();
  await expect.poll(() => probe(page, 'values')).toBe('219-09-9999\n219-09-9999');
  const transferred = `${syntheticLabel}\n219-09-9999\n219-09-9999`;
  await expect.poll(() => probe(page, 'copy')).toBe(true);
  await expect.poll(() => probe(page, 'copied', transferred)).toBe(true);
  const downloaded = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Save labeled identity data', exact: true }).press('Enter');
  const download = await downloaded;
  expect(download.suggestedFilename()).toBe('chimera-synthetic-identity-documents.txt');
  const chunks = [];
  for await (const chunk of await download.createReadStream()) chunks.push(chunk);
  expect(Buffer.concat(chunks)).toEqual(Buffer.from(transferred));
  await expect.poll(() => probe(page, 'saved', [...Buffer.from(transferred)])).toBe(true);
  await fillFlutterTextInput(page.getByRole('textbox', { name: 'Positive integer count', exact: true }), '3');
  await expect.poll(() => probe(page, 'noResult')).toBe(true);
  expect(unexpectedHttpRequests(requests, page.url(), true)).toEqual([]);
});

for (const [format, pattern] of Object.entries({
  Numeric: /^\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}$/,
  Alphanumeric: /^[0-9A-Z]{2}\.[0-9A-Z]{3}\.[0-9A-Z]{3}\/[0-9A-Z]{4}-\d{2}$/,
})) {
  test(`Given${format}Cnpj_WhenGeneratedOffline_ThenValidatedShapeReturns`, async ({ page }) => {
    await openDocument(page);
    await select(page, 'Country or locale', 'Brazil');
    await select(page, 'Document type', 'CNPJ');
    await select(page, 'CNPJ format', format);
    await expect.poll(() => probe(page, 'button', 'Generate synthetic documents')).toBe(true);
    await expect.poll(() => probe(page, 'values')).not.toBeNull();
    expect(await probe(page, 'values')).toMatch(pattern);
  });
}

for (const failure of ['validation', 'processing', 'copy', 'save']) {
  test(`Given${failure}Failure_WhenActionRunsOffline_ThenVisibleErrorWithoutPartialValue`, async ({ page }) => {
    const requests = [];
    await openDocument(page);
    page.on('request', request => { if (/^https?:/.test(request.url())) requests.push(request.url()); });
    if (failure === 'validation') await fillFlutterTextInput(page.getByRole('textbox', { name: 'Positive integer count', exact: true }), '0');
    if (failure === 'processing') {
      await select(page, 'Document type', 'Individual Taxpayer Identification Number (ITIN)');
      await probe(page, 'entropyFailure');
    }
    await page.getByRole('button', { name: 'Generate synthetic documents', exact: true }).click();
    if (failure === 'copy' || failure === 'save') {
      await expect.poll(() => probe(page, 'values')).not.toBeNull();
      await probe(page, `${failure}Failure`);
      await page.getByRole('button', { name: failure === 'copy' ? 'Copy labeled identity data' : 'Save labeled identity data', exact: true }).evaluate(node => node.click());
    }
    const message = {
      validation: 'Choose a supported locale and document type, compatible options, and a positive integer count.',
      processing: 'Synthetic identity document generation failed. No document values were produced.',
      copy: 'The synthetic identity document result could not be copied.',
      save: 'The synthetic identity document result could not be written.',
    }[failure];
    await expect(visibleText(page, message)).toBeVisible();
    await expect.poll(() => probe(page, 'noResult')).toBe(true);
    expect(unexpectedHttpRequests(requests, page.url(), true)).toEqual([]);
  });
}
