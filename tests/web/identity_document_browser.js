// Test-only observations executed unchanged by Playwright and native Safari.
function identityDocumentProbe(action, value) {
  const normalize = text => text.replace(/\s+/g, ' ').trim();
  const label = node => normalize(node.getAttribute('aria-label') || node.textContent);
  const button = name => [...document.querySelectorAll('[role="button"]')].find(node => label(node) === name && node.getAttribute('aria-disabled') !== 'true');
  const result = () => [...document.querySelectorAll('[role="region"][tabindex="0"]')].find(node => label(node).startsWith('Generated synthetic identity documents Synthetic identity documents generated.'));
  if (action === 'setup') {
    window.__chimeraIdentityDocumentCopied = null;
    window.__chimeraIdentityDocumentCopyFailure = false;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      writeText: async text => { if (window.__chimeraIdentityDocumentCopyFailure) throw Error('PRIVATE DOCUMENT'); window.__chimeraIdentityDocumentCopied = text; },
    }});
    performance.clearResourceTimings();
    return true;
  }
  if (action === 'values') {
    const node = result();
    if (!node) return null;
    const text = label(node).replace(/^Generated synthetic identity documents Synthetic identity documents generated\. Synthetic identity test data - not proof of issuance /, '');
    return text.replace(/ (?=[0-9A-Z]{2,3}[.\-])/g, '\n');
  }
  if (action === 'openSelect') {
    const node = [...document.querySelectorAll('[role="button"]')].find(item => label(item).startsWith(`${value} `) && item.getAttribute('aria-disabled') !== 'true');
    if (!node) return false; node.click(); return true;
  }
  if (action === 'option') {
    const node = [...document.querySelectorAll('[role="menuitem"]')].find(item => label(item) === value);
    if (!node) return false; node.click(); return true;
  }
  if (action === 'copy') { const node = button('Copy labeled identity data'); if (!node) return false; node.click(); return true; }
  if (action === 'copied') return window.__chimeraIdentityDocumentCopied === value;
  if (action === 'saved') return window.__chimeraSavedName === 'chimera-synthetic-identity-documents.txt' && JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(value) && window.__chimeraSaveCount === 1 && window.__chimeraLiveDownloadUrlCount === 0;
  if (action === 'noResult') return !result() && !button('Copy labeled identity data') && !button('Save labeled identity data');
  if (action === 'copyFailure') { window.__chimeraIdentityDocumentCopyFailure = true; return true; }
  if (action === 'saveFailure') { URL.createObjectURL = () => { throw Error('PRIVATE DOCUMENT'); }; return true; }
  if (action === 'entropyFailure') {
    Object.defineProperty(window.crypto, 'getRandomValues', { configurable: true, value: () => { throw Error('PRIVATE DOCUMENT'); } });
    return true;
  }
  throw Error('Unknown identity document probe action');
}
