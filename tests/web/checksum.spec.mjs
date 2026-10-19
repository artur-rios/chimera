import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { unexpectedHttpRequests } from './network_policy.mjs';

const checksumSource=readFileSync(new URL('./checksum_browser.js',import.meta.url),'utf8');
const saveSource=readFileSync(new URL('./gzip_save_observer.js',import.meta.url),'utf8');
const safariHarness=readFileSync(new URL('./safari_smoke.dart',import.meta.url),'utf8');
const fileReadyScript=safariHarness.match(/const _checksumFileReadyScript = r'''([\s\S]*?)''';/)[1];
const invalidClipboardScript=safariHarness.match(/const _checksumInvalidClipboardScript = r'''([\s\S]*?)''';/)[1];
const vectors=JSON.parse(readFileSync(new URL('../fixtures/checksums/vectors.json',import.meta.url),'utf8'));
async function probe(page, action, value) {
  return page.evaluate(({source,action,value})=>new Function(`${source}\nreturn checksumProbe(arguments[0], arguments[1]);`)(action,value),{source:checksumSource,action,value});
}
function visibleError(page, message) {
  // Exclude Flutter's hidden live-announcement mirror while matching every
  // character of the visible error text, as the URL browser contracts do.
  const escaped = message.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return page.locator('span', { hasText: new RegExp(`^${escaped}$`) });
}
async function openChecksum(page) {
  await page.goto('/');
  const placeholder=page.locator('flt-semantics-placeholder'); await placeholder.waitFor({state:'attached'});await placeholder.evaluate(node=>node.click());
  await page.getByRole('button',{name:'Generate checksum',exact:true}).click();
  await expect(page.getByRole('textbox',{name:'Text for checksum (UTF-8)',exact:true})).toBeVisible();
}
for(const algorithm of ['crc32','adler32']) {
 for(const source of ['text','file','clipboard','empty','allbytes']) {
  test(`Given${algorithm}${source}_WhenChecksumGeneratedCopiedSaved_ThenExactChecksumAndDiscardOffline`,async({page})=>{
    const requests=[]; await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);
    await openChecksum(page); await page.context().setOffline(true);
    page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
    const vector=vectors.find(v=>v.name===(source==='empty'?'empty':source==='file'?'binary':source==='allbytes'?'allbytes':'abc'));
    const expected=vector.checksums[algorithm]; await probe(page,'setup','abc');
    const editor=page.getByRole('textbox',{name:'Text for checksum (UTF-8)',exact:true});
    if(source==='text'){await editor.fill('abc');await editor.press('Tab');}
    if(source==='clipboard'){await page.getByRole('button',{name:'Paste text',exact:true}).evaluate(node=>node.click());await expect.poll(()=>probe(page,'inputHasValue','abc')).toBe(true);}
    if(source==='file'||source==='allbytes'){
      const oldEditor=await editor.elementHandle();const chooser=page.waitForEvent('filechooser');
      await page.getByRole('button',{name:'Choose local file bytes',exact:true}).click();
      await(await chooser).setFiles({name:'checksum.bin',mimeType:'application/octet-stream',buffer:Buffer.from(vector.bytes)});
      await expect.poll(()=>oldEditor.evaluate(node=>node.isConnected)).toBe(false);await expect(editor).toBeEnabled();
    }
    if(algorithm!=='crc32'){await expect.poll(()=>probe(page,'openAlgorithm')).toBe(true);await expect.poll(()=>probe(page,'algorithm',algorithm.toUpperCase())).toBe(true);}
    await page.getByRole('button',{name:'Generate checksum',exact:true}).click();
    const result=page.getByRole('region',{name:/^Checksum result Checksum generated\./});await expect(result).toBeVisible();await expect.poll(()=>probe(page,'result',expected)).toBe(true);
    await expect(result).toHaveAttribute('tabindex','0');
    await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);await page.keyboard.press('Control+z');await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);
    await expect.poll(()=>probe(page,'copy')).toBe(true);await expect.poll(()=>probe(page,'copied',expected)).toBe(true);
    const download=page.waitForEvent('download');await page.getByRole('button',{name:'Save checksum',exact:true}).press('Enter');const artifact=await download;expect(artifact.suggestedFilename()).toBe('chimera-checksum.txt');
    const chunks=[];for await(const chunk of await artifact.createReadStream())chunks.push(chunk);expect(Buffer.concat(chunks)).toEqual(Buffer.from(`${expected}\n`));
    await expect.poll(()=>probe(page,'saved',[...Buffer.from(`${expected}\n`)])).toBe(true);
    await page.getByRole('button',{name:'Paste text',exact:true}).evaluate(node=>node.click());await expect.poll(()=>probe(page,'noResult')).toBe(true);
    expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
  });
 }
}
for(const action of ['read','copy','save']) {
 test(`Given${action}Failure_WhenChecksumActionRuns_ThenNoPartialResultOrSourceOffline`,async({page})=>{
  const requests=[];await openChecksum(page);await page.context().setOffline(true);page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});await probe(page,'setup','abc');
  const editor=page.getByRole('textbox',{name:'Text for checksum (UTF-8)',exact:true});await editor.fill('SECRET');await editor.press('Tab');
  if(action!=='read'){await page.getByRole('button',{name:'Generate checksum',exact:true}).click();await expect(page.getByRole('region',{name:/^Checksum result Checksum generated\./})).toBeVisible();}
  await probe(page,`${action}Failure`);await page.getByRole('button',{name:action==='read'?'Paste text':action==='copy'?'Copy checksum':'Save checksum',exact:true}).evaluate(node=>node.click());
  await expect(visibleError(page,action==='read'?'Clipboard text could not be read.':action==='copy'?'The checksum could not be copied.':'The checksum could not be saved or written.')).toBeVisible();
  await expect.poll(()=>probe(page,'noResult')).toBe(true);await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
 });
}

test('GivenMalformedClipboard_WhenChecksumPasted_ThenValidationAndDiscardOffline',async({page})=>{
 await openChecksum(page);await page.context().setOffline(true);
 // Exercise Safari's actual script and argument shape through a valid JSON body.
 const script=`${checksumSource}\n${invalidClipboardScript}`;
 expect(script.isWellFormed()).toBe(true);
 const request=JSON.parse(JSON.stringify({script,args:[]}));
 await page.evaluate(({script,args})=>new Function(script)(...args),request);
 expect(await page.evaluate(()=>[window.__chimeraChecksumClipboard.length,window.__chimeraChecksumClipboard.charCodeAt(0)])).toEqual([1,0xd800]);
 await page.getByRole('button',{name:'Paste text',exact:true}).evaluate(node=>node.click());
 await expect(visibleError(page,'The checksum algorithm or input source is invalid.')).toBeVisible();
 await expect.poll(()=>probe(page,'noResult')).toBe(true);await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);
});

test('GivenLocalFileAccessFailure_WhenChecksumFileLoaded_ThenNoPartialResultOrSourceOffline',async({page})=>{
 const requests=[];await openChecksum(page);await page.context().setOffline(true);page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});await probe(page,'setup','abc');await probe(page,'fileFailure');
 const chooser=page.waitForEvent('filechooser');await page.getByRole('button',{name:'Choose local file bytes',exact:true}).click();await(await chooser).setFiles({name:'denied.bin',mimeType:'application/octet-stream',buffer:Buffer.from([0,255])});
 await expect(visibleError(page,'The local file could not be read.')).toBeVisible();await expect.poll(()=>probe(page,'fileFailureObserved')).toBe(true);await expect.poll(()=>probe(page,'noResult')).toBe(true);await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
});

for(const source of ['binary','allbytes']) {
test(`GivenDelayed${source}Read_WhenSafariChecksReadiness_ThenWaitForReplacementAndExactAdler32Offline`,async({page})=>{
 const requests=[];await openChecksum(page);await page.context().setOffline(true);page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});await probe(page,'setup','abc');
 const vector=vectors.find(v=>v.name===source);
 const editor=page.getByRole('textbox',{name:'Text for checksum (UTF-8)',exact:true});
 await editor.fill('previous source');await editor.press('Tab');
 // Hold the actual browser read, then release the original method with the
 // original File. Keep the compiled app's picker and byte processing intact.
 await page.evaluate(()=>{
  const read=FileReader.prototype.readAsArrayBuffer;
  FileReader.prototype.readAsArrayBuffer=function(file){window.__chimeraReleaseChecksumFile=()=>read.call(this,file);};
  const click=HTMLInputElement.prototype.click;
  HTMLInputElement.prototype.click=function(){if(this.type!=='file')return click.call(this);};
 });
 const ready=()=>page.evaluate(({source,script})=>new Function(`${source}\n${script}`)(),{source:checksumSource,script:fileReadyScript});
 // Dispatch in the same task as the click, before Flutter can render busy
 // semantics. An enabled algorithm still describes the previous source here.
 const initial=await page.evaluate(({source,script,bytes})=>{
  const checksum=new Function(`${source}\nreturn checksumProbe;`)();
  [...document.querySelectorAll('[role="button"]')].find(node=>node.textContent.trim()==='Choose local file bytes').click();
  const dispatched=checksum('file',bytes);
  return {dispatched,ready:new Function(`${source}\n${script}`)()};
 },{source:checksumSource,script:fileReadyScript,bytes:vector.bytes});
 expect(initial.dispatched).toBe(true);expect(initial.ready).toBe(false);
 await expect(editor).toBeDisabled();expect(await ready()).toBe(false);
 await page.evaluate(()=>window.__chimeraReleaseChecksumFile());
 await expect.poll(ready).toBe(true);
 await expect.poll(()=>probe(page,'openAlgorithm')).toBe(true);
 await expect.poll(()=>probe(page,'algorithm','ADLER32')).toBe(true);
 await page.getByRole('button',{name:'Generate checksum',exact:true}).click();
 await expect.poll(()=>probe(page,'result',vector.checksums.adler32)).toBe(true);
 await expect.poll(()=>probe(page,'sourceCleared')).toBe(true);
 expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
});
}
