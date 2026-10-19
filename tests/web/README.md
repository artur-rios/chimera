# Web tests

Cross-browser functional tests for Chromium, Firefox, and WebKit live here.

`checksum.spec.mjs` covers CRC32 and Adler32 text, exact file bytes, clipboard,
empty input, high-bit results, copy/download bytes, undo-history discard and
input/output adapter failures while offline. `checksum_browser.js` contains the
same observation body used unchanged by `safari_smoke.dart` on native Safari.
