// Test-only observations executed unchanged by Playwright and native Safari.
function cardProbe(action, value) {
  const normalize = text => text.replace(/\s+/g, ' ').trim();
  const label = node => normalize(node.getAttribute('aria-label') || node.textContent);
  const button = name => [...document.querySelectorAll('[role="button"]')].find(node => label(node) === name && node.getAttribute('aria-disabled') !== 'true');
  const result = () => [...document.querySelectorAll('[role="region"][tabindex="0"]')].find(node => label(node).startsWith('Generated synthetic cards Synthetic cards generated.'));
  if (action === 'setup') {
    window.__chimeraCardCopied = null;
    window.__chimeraCardCopyFailure = false;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      writeText: async text => { if (window.__chimeraCardCopyFailure) throw Error('PRIVATE PAN'); window.__chimeraCardCopied = text; },
    }});
    performance.clearResourceTimings();
    return true;
  }
  if (action === 'values') {
    const node = result();
    const matches = node ? label(node).match(/\b\d{15,16}\b/g) : null;
    return matches ? matches.join('\n') : null;
  }
  if (action === 'openNetwork') {
    const node = [...document.querySelectorAll('[role="button"]')].find(item => label(item).startsWith('Card network ') && item.getAttribute('aria-disabled') !== 'true');
    if (!node) return false; node.click(); return true;
  }
  if (action === 'option') {
    const node = [...document.querySelectorAll('[role="menuitem"]')].find(item => label(item) === value);
    if (!node) return false; node.click(); return true;
  }
  if (action === 'copy') { const node = button('Copy labeled card data'); if (!node) return false; node.click(); return true; }
  if (action === 'copied') return window.__chimeraCardCopied === value;
  if (action === 'saved') return window.__chimeraSavedName === 'chimera-synthetic-cards.txt' && JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(value) && window.__chimeraSaveCount === 1 && window.__chimeraLiveDownloadUrlCount === 0;
  if (action === 'noResult') return !result() && !button('Copy labeled card data') && !button('Save labeled card data');
  if (action === 'copyFailure') { window.__chimeraCardCopyFailure = true; return true; }
  if (action === 'saveFailure') { URL.createObjectURL = () => { throw Error('PRIVATE PAN'); }; return true; }
  if (action === 'entropyFailure') {
    Object.defineProperty(window.crypto, 'getRandomValues', { configurable: true, value: () => { throw Error('PRIVATE PAN'); } });
    return true;
  }
  throw Error('Unknown card probe action');
}
