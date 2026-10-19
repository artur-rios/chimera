// Test-only probes shared unchanged by Playwright and native Safari.
function checksumProbe(action, value) {
  const label = node => (node.getAttribute('aria-label') || node.textContent).replace(/\s+/g, ' ').trim();
  const button = name => [...document.querySelectorAll('[role="button"]')].find(node => label(node) === name && node.getAttribute('aria-disabled') !== 'true');
  const result = () => [...document.querySelectorAll('[role="region"][tabindex="0"]')].find(node => label(node).startsWith('Checksum result Checksum generated.'));
  // Flutter materializes the real editor value when it receives focus.
  // Observe the exact labeled value; never assign it in an observation probe.
  const inputHasValue = expected => {
    const input = [...document.querySelectorAll('input[aria-label],textarea[aria-label]')]
      .find(node => node.getAttribute('aria-label') === 'Text for checksum (UTF-8)');
    if (!input || input.disabled) return false;
    input.focus();
    return input.value === expected;
  };
  if (action === 'setup') {
    window.__chimeraChecksumCopied = null;
    window.__chimeraChecksumFileReadFailures = 0;
    window.__chimeraChecksumClipboard = value;
    window.__chimeraChecksumCopyFailure = false;
    window.__chimeraChecksumReadFailure = false;
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: {
      readText: async () => { if (window.__chimeraChecksumReadFailure) throw Error('PRIVATE'); return window.__chimeraChecksumClipboard; },
      writeText: async text => { if (window.__chimeraChecksumCopyFailure) throw Error('PRIVATE'); window.__chimeraChecksumCopied = text; },
    }});
    performance.clearResourceTimings();
    return true;
  }
  if (action === 'openAlgorithm') {
    const selector = [...document.querySelectorAll('[role="button"]')].find(node => label(node).startsWith('Checksum algorithm ') && node.getAttribute('aria-disabled') !== 'true');
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
    transfer.items.add(new File([new Uint8Array(value)], 'checksum-source.bin', { type: 'application/octet-stream' }));
    picker.files = transfer.files;
    picker.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }
  if (action === 'result') return result()?.getAttribute('aria-label')?.includes(value) === true;
  if (action === 'inputHasValue') return inputHasValue(value);
  if (action === 'sourceCleared') return inputHasValue('');
  if (action === 'copy') { const node=button('Copy checksum'); if (!node) return false; node.click(); return true; }
  if (action === 'copied') return window.__chimeraChecksumCopied === value;
  if (action === 'saved') return window.__chimeraSavedName === 'chimera-checksum.txt' && JSON.stringify(window.__chimeraSavedBytes) === JSON.stringify(value) && window.__chimeraSaveCount === 1;
  if (action === 'noResult') return !result() && !button('Copy checksum') && !button('Save checksum');
  if (action === 'fileFailure') {
    // file_picker_web 4.2.0 preloads small selections with FileReader because
    // FilePickerWebOptions.withData defaults to true; blob fetch is bypassed.
    FileReader.prototype.readAsArrayBuffer = function() {
      window.__chimeraChecksumFileReadFailures++;
      throw new DOMException('PRIVATE', 'NotReadableError');
    };
    return true;
  }
  if (action === 'fileFailureObserved') return window.__chimeraChecksumFileReadFailures === 1;
  if (action === 'readFailure') { window.__chimeraChecksumReadFailure=true; return true; }
  if (action === 'copyFailure') { window.__chimeraChecksumCopyFailure=true; return true; }
  if (action === 'saveFailure') { URL.createObjectURL = () => { throw Error('PRIVATE'); }; return true; }
  throw Error('Unknown checksum probe action');
}
