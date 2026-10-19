import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { unexpectedHttpRequests } from './network_policy.mjs';

const hashSource=readFileSync(new URL('./hash_browser.js',import.meta.url),'utf8');
const saveSource=readFileSync(new URL('./gzip_save_observer.js',import.meta.url),'utf8');
const vectors=JSON.parse(readFileSync(new URL('../fixtures/hashes/vectors.json',import.meta.url),'utf8'));
async function probe(page, action, value) {
  return page.evaluate(({source,action,value})=>new Function(`${source}\nreturn hashProbe(arguments[0], arguments[1]);`)(action,value),{source:hashSource,action,value});
}
function visibleError(page, message) {
  // Exclude Flutter's hidden live-announcement mirror while matching every
  // character of the visible error text, as the URL browser contracts do.
  const escaped = message.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return page.locator('span', { hasText: new RegExp(`^${escaped}$`) });
}
async function openHash(page) {
  await page.goto('/');
  const placeholder=page.locator('flt-semantics-placeholder'); await placeholder.waitFor({state:'attached'});await placeholder.evaluate(node=>node.click());
  await page.getByRole('button',{name:'Generate hash',exact:true}).click();
  await expect(page.getByRole('textbox',{name:'Text to hash (UTF-8)',exact:true})).toBeVisible();
}
for(const algorithm of ['sha256','sha384','sha512','md5','sha1']) {
 for(const source of ['text','file','clipboard','empty']) {
  test(`Given${algorithm}${source}_WhenHashGeneratedCopiedSaved_ThenExactDigestAndDiscardOffline`,async({page})=>{
    const requests=[]; await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);
    await openHash(page); await page.context().setOffline(true);
    page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
    const vector=vectors.find(v=>v.name===(source==='empty'?'empty':source==='file'?'binary':'abc'));
    const expected=vector.digests[algorithm]; await probe(page,'setup','abc');
    const editor=page.getByRole('textbox',{name:'Text to hash (UTF-8)',exact:true});
    if(source==='text'){await editor.fill('abc');await editor.press('Tab');}
    if(source==='clipboard'){await page.getByRole('button',{name:'Paste text',exact:true}).evaluate(node=>node.click());await expect.poll(()=>probe(page,'inputHasValue','abc')).toBe(true);}
    if(source==='file'){
      const oldEditor=await editor.elementHandle();const chooser=page.waitForEvent('filechooser');
      await page.getByRole('button',{name:'Choose local file bytes',exact:true}).click();
      await(await chooser).setFiles({name:'hash.bin',mimeType:'application/octet-stream',buffer:Buffer.from(vector.bytes)});
      await expect.poll(()=>oldEditor.evaluate(node=>node.isConnected)).toBe(false);await expect(editor).toBeEnabled();
    }
    if(algorithm!=='sha256'){await expect.poll(()=>probe(page,'openAlgorithm')).toBe(true);await expect.poll(()=>probe(page,'algorithm',algorithm.toUpperCase())).toBe(true);}
    await page.getByRole('button',{name:'Generate hash',exact:true}).click();
    const result=page.getByRole('region',{name:/^Hash result Hash generated\./});await expect(result).toBeVisible();await expect.poll(()=>probe(page,'result',expected)).toBe(true);
    await expect(result).toHaveAttribute('tabindex','0');
    if(['md5','sha1'].includes(algorithm))await expect(result).toHaveAttribute('aria-label',/legacy algorithms and unsuitable for security decisions/);
    await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);await page.keyboard.press('Control+z');await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);
    await expect.poll(()=>probe(page,'copy')).toBe(true);await expect.poll(()=>probe(page,'copied',expected)).toBe(true);
    const download=page.waitForEvent('download');await page.getByRole('button',{name:'Save digest',exact:true}).press('Enter');const artifact=await download;expect(artifact.suggestedFilename()).toBe('chimera-hash.txt');
    const chunks=[];for await(const chunk of await artifact.createReadStream())chunks.push(chunk);expect(Buffer.concat(chunks)).toEqual(Buffer.from(`${expected}\n`));
    await expect.poll(()=>probe(page,'saved',[...Buffer.from(`${expected}\n`)])).toBe(true);
    await page.getByRole('button',{name:'Paste text',exact:true}).evaluate(node=>node.click());await expect.poll(()=>probe(page,'noResult')).toBe(true);
    expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
  });
 }
}
for(const action of ['read','copy','save']) {
 test(`Given${action}Failure_WhenHashActionRuns_ThenNoPartialResultOrSourceOffline`,async({page})=>{
  const requests=[];await openHash(page);await page.context().setOffline(true);page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});await probe(page,'setup','abc');
  const editor=page.getByRole('textbox',{name:'Text to hash (UTF-8)',exact:true});await editor.fill('SECRET');await editor.press('Tab');
  if(action!=='read'){await page.getByRole('button',{name:'Generate hash',exact:true}).click();await expect(page.getByRole('region',{name:/^Hash result Hash generated\./})).toBeVisible();}
  await probe(page,`${action}Failure`);await page.getByRole('button',{name:action==='read'?'Paste text':action==='copy'?'Copy digest':'Save digest',exact:true}).evaluate(node=>node.click());
  await expect(visibleError(page,action==='read'?'Clipboard text could not be read.':action==='copy'?'The digest could not be copied.':'The digest could not be saved or written.')).toBeVisible();
  await expect.poll(()=>probe(page,'noResult')).toBe(true);await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
 });
}

test('GivenMalformedClipboard_WhenHashPasted_ThenValidationAndDiscardOffline',async({page})=>{
 await openHash(page);await page.context().setOffline(true);await probe(page,'setup','\ud800');
 await page.getByRole('button',{name:'Paste text',exact:true}).evaluate(node=>node.click());
 await expect(visibleError(page,'The hash algorithm or input source is invalid.')).toBeVisible();
 await expect.poll(()=>probe(page,'noResult')).toBe(true);await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);
});

test('GivenLocalFileAccessFailure_WhenHashFileLoaded_ThenNoPartialResultOrSourceOffline',async({page})=>{
 const requests=[];await openHash(page);await page.context().setOffline(true);page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});await probe(page,'setup','abc');await probe(page,'fileFailure');
 const chooser=page.waitForEvent('filechooser');await page.getByRole('button',{name:'Choose local file bytes',exact:true}).click();await(await chooser).setFiles({name:'denied.bin',mimeType:'application/octet-stream',buffer:Buffer.from([0,255])});
 await expect(visibleError(page,'The local file could not be read.')).toBeVisible();await expect.poll(()=>probe(page,'fileFailureObserved')).toBe(true);await expect.poll(()=>probe(page,'noResult')).toBe(true);await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
});
