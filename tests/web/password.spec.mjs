import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { unexpectedHttpRequests } from './network_policy.mjs';

const source=readFileSync(new URL('./password_browser.js',import.meta.url),'utf8');
const saveSource=readFileSync(new URL('./gzip_save_observer.js',import.meta.url),'utf8');
async function probe(page, action, value) {
  return page.evaluate(({source,action,value})=>new Function(`${source}\nreturn passwordProbe(arguments[0], arguments[1]);`)(action,value),{source,action,value});
}
function visibleText(page, text) {
  const escaped=text.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  return page.locator('span',{hasText:new RegExp(`^${escaped}$`)});
}
async function fillLength(length, value) {
  await length.click();await expect(length).toBeFocused();await length.fill(value);await length.press('Tab');await expect(length).toHaveValue(value);
}
async function openPassword(page) {
  await page.goto('/');
  const placeholder=page.locator('flt-semantics-placeholder');await placeholder.waitFor({state:'attached'});await placeholder.evaluate(node=>node.click());
  await page.getByRole('button',{name:'Generate Password',exact:true}).click();
  await expect(page.getByRole('textbox',{name:'Positive integer length',exact:true})).toBeVisible();
  await page.context().setOffline(true);await probe(page,'setup');
}

test('GivenDefaults_WhenGeneratedCopiedSavedOffline_ThenSecureShapeAndExactTransfer',async({page})=>{
  const requests=[];await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);await openPassword(page);
  page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
  await page.getByRole('button',{name:'Generate password',exact:true}).click();
  await expect.poll(()=>probe(page,'result')).not.toBeNull();const password=await probe(page,'result');
  expect(password).toHaveLength(16);expect(password).toMatch(/[a-z]/);expect(password).toMatch(/[A-Z]/);expect(password).toMatch(/[0-9]/);expect(password).toMatch(/[!@#$%^&*()\-_=+\[\]{}:,.?]/);
  await expect.poll(()=>probe(page,'copy')).toBe(true);await expect.poll(()=>probe(page,'copied',password)).toBe(true);
  const downloaded=page.waitForEvent('download');await page.getByRole('button',{name:'Save password',exact:true}).press('Enter');const download=await downloaded;
  expect(download.suggestedFilename()).toBe('chimera-password.txt');const chunks=[];for await(const chunk of await download.createReadStream())chunks.push(chunk);expect(Buffer.concat(chunks)).toEqual(Buffer.from(password));
  await expect.poll(()=>probe(page,'saved',[...Buffer.from(password)])).toBe(true);
  await fillLength(page.getByRole('textbox',{name:'Positive integer length',exact:true}),'20');await expect.poll(()=>probe(page,'noResult')).toBe(true);
  expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
});

test('GivenOnlyDigits_WhenGeneratedOffline_ThenAllConstraintsAreHonored',async({page})=>{
  await openPassword(page);
  for(const name of ['Lowercase letters','Uppercase letters','Symbols']) await expect.poll(()=>probe(page,'toggle',name)).toBe(true);
  await fillLength(page.getByRole('textbox',{name:'Positive integer length',exact:true}),'8');await page.getByRole('button',{name:'Generate password',exact:true}).click();
  await expect.poll(()=>probe(page,'result')).not.toBeNull();const password=await probe(page,'result');expect(password).toMatch(/^\d{8}$/);
});

for(const failure of ['validation','copy','save']) {
  test(`Given${failure}Failure_WhenActionRunsOffline_ThenVisibleErrorWithoutPartialPassword`,async({page})=>{
    const requests=[];await openPassword(page);page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
    if(failure==='validation') await fillLength(page.getByRole('textbox',{name:'Positive integer length',exact:true}),'3');
    await page.getByRole('button',{name:'Generate password',exact:true}).click();
    if(failure!=='validation') {await expect.poll(()=>probe(page,'result')).not.toBeNull();await probe(page,`${failure}Failure`);await page.getByRole('button',{name:failure==='copy'?'Copy password':'Save password',exact:true}).evaluate(node=>node.click());}
    await expect(visibleText(page,failure==='validation'?'Choose a positive integer length that can include every selected character class, and select at least one class.':failure==='copy'?'The generated password could not be copied.':'The generated password could not be saved or written.')).toBeVisible();
    await expect.poll(()=>probe(page,'noResult')).toBe(true);expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
  });
}
