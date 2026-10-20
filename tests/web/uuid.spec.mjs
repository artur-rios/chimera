import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { unexpectedHttpRequests } from './network_policy.mjs';

const source=readFileSync(new URL('./uuid_browser.js',import.meta.url),'utf8');
const saveSource=readFileSync(new URL('./gzip_save_observer.js',import.meta.url),'utf8');
async function probe(page, action, value) {
  return page.evaluate(({source,action,value})=>new Function(`${source}\nreturn uuidProbe(arguments[0], arguments[1]);`)(action,value),{source,action,value});
}
function visibleText(page, text) {
  const escaped=text.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  return page.locator('span',{hasText:new RegExp(`^${escaped}$`)});
}
async function fillCount(count, value) {
  await count.click();await expect(count).toBeFocused();await count.fill(value);await count.press('Tab');await expect(count).toHaveValue(value);
}
async function openUuid(page) {
  await page.goto('/');
  const placeholder=page.locator('flt-semantics-placeholder');await placeholder.waitFor({state:'attached'});await placeholder.evaluate(node=>node.click());
  await page.getByRole('button',{name:'Generate UUID or GUID',exact:true}).click();
  await expect(page.getByRole('textbox',{name:'Positive integer count',exact:true})).toBeVisible();
  await page.context().setOffline(true);await probe(page,'setup');
}

test('GivenDefaults_WhenGeneratedCopiedSavedOffline_ThenSecureV4AndExactTransfer',async({page})=>{
  const requests=[];await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);await openUuid(page);
  page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
  await page.getByRole('button',{name:'Generate identifiers',exact:true}).click();
  await expect.poll(()=>probe(page,'result')).not.toBeNull();const value=await probe(page,'result');
  expect(value).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  await expect.poll(()=>probe(page,'copy')).toBe(true);await expect.poll(()=>probe(page,'copied',value)).toBe(true);
  const downloaded=page.waitForEvent('download');await page.getByRole('button',{name:'Save identifiers',exact:true}).press('Enter');const download=await downloaded;
  expect(download.suggestedFilename()).toBe('chimera-identifiers.txt');const chunks=[];for await(const chunk of await download.createReadStream())chunks.push(chunk);expect(Buffer.concat(chunks)).toEqual(Buffer.from(value));
  await expect.poll(()=>probe(page,'saved',[...Buffer.from(value)])).toBe(true);
  await fillCount(page.getByRole('textbox',{name:'Positive integer count',exact:true}),'2');await expect.poll(()=>probe(page,'noResult')).toBe(true);
  expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
});

test('GivenV7GuidCountTwo_WhenGeneratedOffline_ThenTimestampShapeAndUniquenessHold',async({page})=>{
  await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);
  await openUuid(page);
  await expect.poll(()=>probe(page,'openVersion')).toBe(true);await expect.poll(()=>probe(page,'option','Version 7 (time ordered)')).toBe(true);
  await expect.poll(()=>probe(page,'openRepresentation')).toBe(true);await expect.poll(()=>probe(page,'option','GUID (uppercase braces)')).toBe(true);
  await fillCount(page.getByRole('textbox',{name:'Positive integer count',exact:true}),'2');const before=Date.now();await page.getByRole('button',{name:'Generate identifiers',exact:true}).click();
  await expect.poll(()=>probe(page,'result')).not.toBeNull();const text=await probe(page,'result');const values=text.match(/\{[0-9A-F-]+\}/g);
  const after=Date.now();expect(values).toHaveLength(2);expect(new Set(values).size).toBe(2);for(const value of values){expect(value).toMatch(/^\{[0-9A-F]{8}-[0-9A-F]{4}-7[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}\}$/);const timestamp=Number.parseInt(value.slice(1,14).replace('-',''),16);expect(timestamp).toBeGreaterThanOrEqual(before);expect(timestamp).toBeLessThanOrEqual(after);}
  const transferred=values.join('\n');await expect.poll(()=>probe(page,'copy')).toBe(true);await expect.poll(()=>probe(page,'copied',transferred)).toBe(true);
  const downloaded=page.waitForEvent('download');await page.getByRole('button',{name:'Save identifiers',exact:true}).press('Enter');const download=await downloaded;const chunks=[];for await(const chunk of await download.createReadStream())chunks.push(chunk);expect(Buffer.concat(chunks)).toEqual(Buffer.from(transferred));await expect.poll(()=>probe(page,'saved',[...Buffer.from(transferred)])).toBe(true);
});

for(const failure of ['validation','processing','copy','save']) {
  test(`Given${failure}Failure_WhenActionRunsOffline_ThenVisibleErrorWithoutPartialIdentifiers`,async({page})=>{
    const requests=[];await openUuid(page);page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
    if(failure==='validation') await fillCount(page.getByRole('textbox',{name:'Positive integer count',exact:true}),'0');
    if(failure==='processing') await probe(page,'entropyFailure');
    await page.getByRole('button',{name:'Generate identifiers',exact:true}).click();
    if(failure==='copy'||failure==='save') {await expect.poll(()=>probe(page,'result')).not.toBeNull();await probe(page,`${failure}Failure`);await page.getByRole('button',{name:failure==='copy'?'Copy identifiers':'Save identifiers',exact:true}).evaluate(node=>node.click());}
    const message={validation:'Choose version 4 or 7, UUID or GUID representation, and a positive integer count.',processing:'Secure identifier generation failed. No identifiers were produced.',copy:'The generated identifiers could not be copied.',save:'The generated identifiers could not be saved or written.'}[failure];
    await expect(visibleText(page,message)).toBeVisible();await expect.poll(()=>probe(page,'noResult')).toBe(true);expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
  });
}
