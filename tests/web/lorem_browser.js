// Test-only observations executed unchanged by Playwright and native Safari.
function loremProbe(action, value) {
  const normalize = text => text.replace(/\s+/g, ' ').trim();
  const label = node => normalize(node.getAttribute('aria-label') || node.textContent);
  const button = name => [...document.querySelectorAll('[role="button"]')].find(node => label(node) === name && node.getAttribute('aria-disabled') !== 'true');
  const result = () => [...document.querySelectorAll('[role="region"][tabindex="0"]')].find(node => label(node).startsWith('Generated Lorem Ipsum Text generated.'));
  if (action === 'setup') {
    window.__chimeraLoremCopied = null;
    window.__chimeraLoremCopyFailure = false;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      writeText: async text => { if (window.__chimeraLoremCopyFailure) throw Error('PRIVATE'); window.__chimeraLoremCopied = text; },
    }});
    performance.clearResourceTimings();
    return true;
  }
  if (action === 'openUnit') {
    const selector = [...document.querySelectorAll('[role="button"]')].find(node => label(node).startsWith('Unit ') && node.getAttribute('aria-disabled') !== 'true');
    if (!selector) return false; selector.click(); return true;
  }
  if (action === 'unit') {
    const option = [...document.querySelectorAll('[role="menuitem"]')].find(node => label(node) === value);
    if (!option) return false; option.click(); return true;
  }
  if (action === 'result') return result() && label(result()) === normalize(`Generated Lorem Ipsum Text generated. ${value}`);
  if (action === 'copy') { const node=button('Copy text'); if (!node) return false; node.click(); return true; }
  if (action === 'copied') return window.__chimeraLoremCopied === value;
  if (action === 'saved') return window.__chimeraSavedName === 'chimera-lorem.txt' && JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(value) && window.__chimeraSaveCount === 1 && window.__chimeraLiveDownloadUrlCount === 0;
  if (action === 'noResult') return !result() && !button('Copy text') && !button('Save UTF-8 text');
  if (action === 'copyFailure') { window.__chimeraLoremCopyFailure=true; return true; }
  if (action === 'saveFailure') { URL.createObjectURL = () => { throw Error('PRIVATE'); }; return true; }
  throw Error('Unknown Lorem probe action');
}
