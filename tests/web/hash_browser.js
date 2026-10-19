// Test-only probes shared unchanged by Playwright and native Safari.
function hashProbe(action, value) {
  const label = node => (node.getAttribute('aria-label') || node.textContent).replace(/\s+/g, ' ').trim();
  const button = name => [...document.querySelectorAll('[role="button"]')].find(node => label(node) === name && node.getAttribute('aria-disabled') !== 'true');
  const result = () => [...document.querySelectorAll('[role="region"][tabindex="0"]')].find(node => label(node).startsWith('Hash result Hash generated.'));
  if (action === 'setup') {
    window.__chimeraHashCopied = null;
    window.__chimeraHashClipboard = value;
    window.__chimeraHashCopyFailure = false;
    window.__chimeraHashReadFailure = false;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      readText: async () => { if (window.__chimeraHashReadFailure) throw Error('PRIVATE'); return window.__chimeraHashClipboard; },
      writeText: async text => { if (window.__chimeraHashCopyFailure) throw Error('PRIVATE'); window.__chimeraHashCopied = text; },
    }});
    performance.clearResourceTimings();
    return true;
  }
  if (action === 'openAlgorithm') {
    const selector = [...document.querySelectorAll('[role="button"]')].find(node => label(node).startsWith('Hash algorithm ') && node.getAttribute('aria-disabled') !== 'true');
    if (!selector) return false; selector.click(); return true;
  }
  if (action === 'algorithm') {
    const option = [...document.querySelectorAll('[role="menuitem"]')].find(node => label(node) === value);
    if (!option) return false; option.click(); return true;
  }
  if (action === 'file') {
    const picker = [...document.querySelectorAll('input[type="file"]')].at(-1);
    if (!picker) return false;
    const transfer = new DataTransfer();
    transfer.items.add(new File([new Uint8Array(value)], 'hash-source.bin', { type: 'application/octet-stream' }));
    picker.files = transfer.files;
    picker.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }
  if (action === 'result') return result()?.getAttribute('aria-label')?.includes(value) === true;
  if (action === 'sourceCleared') {
    const input = [...document.querySelectorAll('input,textarea')].find(node => node.getAttribute('aria-label') === 'Text to hash (UTF-8)');
    if (!input) return false;
    input.focus();
    return input.value === '';
  }
  if (action === 'copy') { const node=button('Copy digest'); if (!node) return false; node.click(); return true; }
  if (action === 'copied') return window.__chimeraHashCopied === value;
  if (action === 'saved') return window.__chimeraSavedName === 'chimera-hash.txt' && JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(value) && window.__chimeraSaveCount === 1;
  if (action === 'noResult') return !result() && !button('Copy digest') && !button('Save digest');
  if (action === 'fileFailure') {
    const fetchOriginal=window.fetch.bind(window);
    window.fetch=(url,...args)=>String(url).startsWith('blob:')?Promise.reject(Error('PRIVATE')):fetchOriginal(url,...args);
    return true;
  }
  if (action === 'readFailure') { window.__chimeraHashReadFailure=true; return true; }
  if (action === 'copyFailure') { window.__chimeraHashCopyFailure=true; return true; }
  if (action === 'saveFailure') { URL.createObjectURL = () => { throw Error('PRIVATE'); }; return true; }
  throw Error('Unknown hash probe action');
}
