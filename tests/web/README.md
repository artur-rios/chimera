# Web tests

Cross-browser functional tests for Chromium, Firefox, and WebKit live here.

UC-30 hash coverage lives in `hash.spec.mjs`, selected explicitly by the
Playwright configuration for all three engines. `hash_browser.js` contains the
same observation and failure probes used by `_generateHash` in the native
Safari harness. The matrix covers every algorithm and text/file/clipboard/empty
source, exact copied/saved digests, legacy warnings, input/history discard,
offline requests, malformed clipboard validation, file/clipboard access, and
copy/save failures. Deterministic allocation failures run in utility, service,
widget and native integration tests; browser tests do not force a real OOM.
