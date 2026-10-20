// Test-only observations executed unchanged by Playwright and native Safari.
function uuidProbe(action, value) {
  const normalize = text => text.replace(/\s+/g, ' ').trim();
  const label = node => normalize(node.getAttribute('aria-label') || node.textContent);
  const button = name => [...document.querySelectorAll('[role="button"]')].find(node => label(node) === name && node.getAttribute('aria-disabled') !== 'true');
  const result = () => [...document.querySelectorAll('[role="region"][tabindex="0"]')].find(node => label(node).startsWith('Generated identifiers Identifiers generated.'));
  if (action === 'setup') {
    window.__chimeraUuidCopied = null;
    window.__chimeraUuidCopyFailure = false;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      writeText: async text => { if (window.__chimeraUuidCopyFailure) throw Error('PRIVATE'); window.__chimeraUuidCopied = text; },
    }});
    performance.clearResourceTimings();
    return true;
  }
  if (action === 'result') {
    const node=result();
    return node ? label(node).replace(/^Generated identifiers Identifiers generated\.\s*/, '') : null;
  }
  if (action === 'openVersion') {
    const node=[...document.querySelectorAll('[role="button"]')].find(item => label(item).startsWith('Identifier version ') && item.getAttribute('aria-disabled') !== 'true');
    if (!node) return false; node.click(); return true;
  }
  if (action === 'openRepresentation') {
    const node=[...document.querySelectorAll('[role="button"]')].find(item => label(item).startsWith('Text representation ') && item.getAttribute('aria-disabled') !== 'true');
    if (!node) return false; node.click(); return true;
  }
  if (action === 'option') {
    const node=[...document.querySelectorAll('[role="menuitem"]')].find(item => label(item) === value);
    if (!node) return false; node.click(); return true;
  }
  if (action === 'copy') { const node=button('Copy identifiers'); if (!node) return false; node.click(); return true; }
  if (action === 'copied') return window.__chimeraUuidCopied === value;
  if (action === 'saved') return window.__chimeraSavedName === 'chimera-identifiers.txt' && JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(value) && window.__chimeraSaveCount === 1 && window.__chimeraLiveDownloadUrlCount === 0;
  if (action === 'noResult') return !result() && !button('Copy identifiers') && !button('Save identifiers');
  if (action === 'copyFailure') { window.__chimeraUuidCopyFailure=true; return true; }
  if (action === 'saveFailure') { URL.createObjectURL = () => { throw Error('PRIVATE'); }; return true; }
  if (action === 'entropyFailure') {
    Object.defineProperty(window.crypto, 'getRandomValues', { configurable: true, value: () => { throw Error('PRIVATE'); } });
    return true;
  }
  throw Error('Unknown UUID probe action');
}
