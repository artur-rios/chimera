import { readFileSync } from 'node:fs';

const safariSource = readFileSync(new URL('./safari_smoke.dart', import.meta.url), 'utf8');

export const networkRequestPolicyScript = safariSource.match(/const _networkRequestPolicyScript = r'''([\s\S]*?)''';/)?.[1];

export function unexpectedHttpRequests(urls, applicationUrl, allowFontFallback = false) {
  if (!networkRequestPolicyScript) throw new Error('Safari network request policy is missing');
  return new Function(networkRequestPolicyScript)(urls, applicationUrl, allowFontFallback);
}

const origin = 'http://127.0.0.1:41731';
const fontPath = '/font-fallback/notosanssc/v37/font.116.woff2';
const font = `${origin}${fontPath}`;
const blocked = url => ({ urls: [url], expected: [url] });

export const networkPolicyCases = [
  { name: 'DefaultFontRequest', ...blocked(font), allow: false },
  { name: 'SameOriginFont', urls: [font], expected: [] },
  {
    name: 'SafariCjkFont',
    applicationUrl: 'http://127.0.0.1:4173/#/qr/decode',
    urls: ['http://127.0.0.1:4173/font-fallback/notosanssc/v37/k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaG9_FnYkldv7JjxkkgFsFSSOPMOkySAZ73y9ViAt3acb8NexQ2w.116.woff2'],
    expected: [],
  },
  { name: 'ExternalFont', ...blocked(`https://fonts.example${fontPath}`) },
  { name: 'DifferentPortFont', ...blocked(`http://127.0.0.1:4173${fontPath}`) },
  { name: 'DifferentSchemeFont', ...blocked(`https://127.0.0.1:41731${fontPath}`) },
  { name: 'DifferentHostFont', ...blocked(`http://localhost:41731${fontPath}`) },
  { name: 'CredentialedFont', ...blocked(`http://user:secret@127.0.0.1:41731${fontPath}`) },
  { name: 'FontQuery', ...blocked(`${font}?input=secret`) },
  { name: 'FontFragment', ...blocked(`${font}#secret`) },
  { name: 'OtherLocalRequest', ...blocked(`${origin}/api/utility`) },
  { name: 'SimilarDirectory', ...blocked(`${origin}/font-fallback-extra/notosanssc/v37/font.woff2`) },
  { name: 'NonFontExtension', ...blocked(`${origin}/font-fallback/notosanssc/v37/script.js`) },
  { name: 'UnversionedFontPath', ...blocked(`${origin}/font-fallback/input.woff2`) },
  { name: 'EncodedFontPath', ...blocked(`${origin}/font-fallback/notosanssc/v37/%66ont.woff2`) },
  { name: 'MalformedRequest', ...blocked('http://[') },
  { name: 'NonHttpResources', urls: ['blob:http://127.0.0.1:41731/example', 'data:text/plain,text'], expected: [] },
  { name: 'MixedRequests', urls: [font, `${origin}/api/utility`, `https://fonts.example${fontPath}`], expected: [`${origin}/api/utility`, `https://fonts.example${fontPath}`] },
].map(value => ({ applicationUrl: `${origin}/#/qr/decode`, allow: true, ...value }));
