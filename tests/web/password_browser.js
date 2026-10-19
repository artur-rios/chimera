// Test-only observations executed unchanged by Playwright and native Safari.
function passwordProbe(action, value) {
  const normalize = text => text.replace(/\s+/g, ' ').trim();
  const label = node => normalize(node.getAttribute('aria-label') || node.textContent);
  const button = name => [...document.querySelectorAll('[role="button"]')].find(node => label(node) === name && node.getAttribute('aria-disabled') !== 'true');
  const toggle = name => [...document.querySelectorAll('[role="switch"]')].find(node => label(node) === name && node.getAttribute('aria-disabled') !== 'true');
  const result = () => [...document.querySelectorAll('[role="region"][tabindex="0"]')].find(node => label(node).startsWith('Generated password Password generated.'));
  if (action === 'setup') {
    window.__chimeraPasswordCopied = null;
    window.__chimeraPasswordCopyFailure = false;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      writeText: async text => { if (window.__chimeraPasswordCopyFailure) throw Error('PRIVATE'); window.__chimeraPasswordCopied = text; },
    }});
    performance.clearResourceTimings();
    return true;
  }
  if (action === 'result') {
    const node=result();
    if (!node) return null;
    return label(node).replace(/^Generated password Password generated\.\s*/, '');
  }
  if (action === 'toggle') { const node=toggle(value); if (!node) return false; node.click(); return true; }
  if (action === 'copy') { const node=button('Copy password'); if (!node) return false; node.click(); return true; }
  if (action === 'copied') return window.__chimeraPasswordCopied === value;
  if (action === 'saved') return window.__chimeraSavedName === 'chimera-password.txt' && JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(value) && window.__chimeraSaveCount === 1 && window.__chimeraLiveDownloadUrlCount === 0;
  if (action === 'noResult') return !result() && !button('Copy password') && !button('Save password');
  if (action === 'copyFailure') { window.__chimeraPasswordCopyFailure=true; return true; }
  if (action === 'saveFailure') { URL.createObjectURL = () => { throw Error('PRIVATE'); }; return true; }
  throw Error('Unknown password probe action');
}
