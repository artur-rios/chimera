import { expect, test } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { unexpectedHttpRequests } from './network_policy.mjs';
import { fillFlutterTextInput, observeFlutterTextInput } from './flutter_text_input.mjs';

const source=readFileSync(new URL('./lorem_browser.js',import.meta.url),'utf8');
const saveSource=readFileSync(new URL('./gzip_save_observer.js',import.meta.url),'utf8');
const paragraph='Lorem ipsum dolor sit amet. Consectetur adipiscing elit.';
async function probe(page, action, value) {
  return page.evaluate(({source,action,value})=>new Function(`${source}\nreturn loremProbe(arguments[0], arguments[1]);`)(action,value),{source,action,value});
}
function visibleText(page, text) {
  const escaped=text.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  return page.locator('span',{hasText:new RegExp(`^${escaped}$`)});
}
async function openLorem(page) {
  await observeFlutterTextInput(page);
  await page.goto('/');
  const placeholder=page.locator('flt-semantics-placeholder');await placeholder.waitFor({state:'attached'});await placeholder.evaluate(node=>node.click());
  await page.getByRole('button',{name:'Generate Lorem Ipsum',exact:true}).click();
  await expect(page.getByRole('textbox',{name:'Positive integer count',exact:true})).toBeVisible();
  await page.context().setOffline(true);await probe(page,'setup');
}
for(const unit of ['words','sentences','paragraphs']) {
  test(`Given${unit}_WhenGeneratedCopiedSavedOffline_ThenExactCountsAndBytes`,async({page})=>{
    const requests=[];await page.addInitScript(`${saveSource}\nobserveGzipSaves();`);await openLorem(page);
    page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
    if(unit!=='paragraphs'){await expect.poll(()=>probe(page,'openUnit')).toBe(true);await expect.poll(()=>probe(page,'unit',unit==='words'?'Words':'Sentences')).toBe(true);}
    const count=page.getByRole('textbox',{name:'Positive integer count',exact:true});await fillFlutterTextInput(count,'2');
    await page.getByRole('button',{name:'Generate text',exact:true}).click();
    const expected=unit==='words'?'Lorem ipsum':unit==='sentences'?paragraph:`${paragraph}\n\n${paragraph}`;
    await expect.poll(()=>probe(page,'result',expected)).toBe(true);
    const region=page.getByRole('region',{name:/^Generated Lorem Ipsum Text generated\./});await expect(region).toBeVisible();await expect(region).toHaveAttribute('tabindex','0');
    await expect.poll(()=>probe(page,'copy')).toBe(true);await expect.poll(()=>probe(page,'copied',expected)).toBe(true);
    const downloaded=page.waitForEvent('download');await page.getByRole('button',{name:'Save UTF-8 text',exact:true}).press('Enter');const download=await downloaded;
    expect(download.suggestedFilename()).toBe('chimera-lorem.txt');const chunks=[];for await(const chunk of await download.createReadStream())chunks.push(chunk);expect(Buffer.concat(chunks)).toEqual(Buffer.from(expected));
    await expect.poll(()=>probe(page,'saved',[...Buffer.from(expected)])).toBe(true);
    await fillFlutterTextInput(count,'3');
    await expect.poll(()=>probe(page,'noResult')).toBe(true);
    expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
  });
}
test('GivenDefaults_WhenGeneratedOffline_ThenKnownSingleParagraph',async({page})=>{
  await openLorem(page);await page.getByRole('button',{name:'Generate text',exact:true}).click();await expect.poll(()=>probe(page,'result',paragraph)).toBe(true);
});
for(const failure of ['validation','copy','save']) {
  test(`Given${failure}Failure_WhenActionRunsOffline_ThenVisibleErrorWithoutPartialText`,async({page})=>{
    const requests=[];await openLorem(page);page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url());});
    if(failure==='validation'){const count=page.getByRole('textbox',{name:'Positive integer count',exact:true});await fillFlutterTextInput(count,'0');}
    await page.getByRole('button',{name:'Generate text',exact:true}).click();
    if(failure!=='validation'){
      await expect.poll(()=>probe(page,'result',paragraph)).toBe(true);await probe(page,`${failure}Failure`);
      await page.getByRole('button',{name:failure==='copy'?'Copy text':'Save UTF-8 text',exact:true}).evaluate(node=>node.click());
    }
    await expect(visibleText(page,failure==='validation'?'Choose words, sentences or paragraphs and a positive integer count.':failure==='copy'?'The generated text could not be copied.':'The generated text could not be saved or written.')).toBeVisible();
    await expect.poll(()=>probe(page,'noResult')).toBe(true);expect(unexpectedHttpRequests(requests,page.url())).toEqual([]);
  });
}
