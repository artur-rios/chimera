# Task 5 implementation report

## Outcome

Added native and browser GZIP decompression evidence without changing CI
matrices, workers, retries, or timeouts. The tests use literal independent
GZIP members and assert real UI, clipboard, file, download, semantics, and
network boundaries.

## TDD record

- RED: `npx playwright test --project=chromium
  --grep="GivenObservedDownloadObjectUrl"` failed because
  `window.__chimeraLiveObjectUrlCount` was undefined.
- Investigation showed `file_picker` creates an unrelated object URL for a
  selected input file, while its download path revokes the activated download
  URL synchronously. The observer now tracks activated download URLs
  separately, so input-platform ownership cannot produce a false leak.
- GREEN: the focused cleanup test passed, followed by the complete UC-21
  focused Chromium and WebKit flows.

## Coverage matrix

| Target | Mode / locale | Happy path and exact transfer | Failure / lifecycle / offline |
| --- | --- | --- | --- |
| Windows | Text + binary; EN + pt-BR | BOM text copy and `.txt` bytes; arbitrary `.bin` bytes; exact filename/MIME; one save; stable live-region semantics | AF-01 corruption, no partial result, discarded source, zero `HttpClient` attempts |
| Linux (mandatory CI) | Text + binary; EN + pt-BR | Same shared integration tests as Windows | Same AF-01 and offline assertions |
| Chromium | Text + binary; EN | BOM copy/download and arbitrary binary download; exact filename/MIME/bytes; one activation; stable focusable region | AF-01, no partial output, zero external/interaction requests, download URL count returns to zero |
| Firefox (mandatory CI) | Text + binary; EN | Same shared Playwright tests as Chromium | Same AF-01, offline, and URL-cleanup assertions |
| WebKit | Text + binary; EN | Same shared Playwright tests as Chromium | Same AF-01, offline, and URL-cleanup assertions |
| Native Safari (mandatory CI) | Text; EN | Real file dispatch; BOM copy; exact `.txt` filename/MIME/bytes; one activation; stable region/count semantics | Zero network requests and activated download URL count returns to zero |

Across the matrix both modes, both locales, AF-01, exact BOM copy/text save,
arbitrary binary save, filename/MIME/count, stable semantics, URL cleanup, and
zero unexpected external requests are covered. Every target has at least one
offline happy path.

## Files

- `apps/chimera_gui/integration_test/app_test.dart`
- `tests/web/smoke.spec.mjs`
- `tests/web/safari_smoke.dart`
- `tests/web/gzip_save_observer.js`

## Verification

- `flutter build web --release --no-web-resources-cdn`: passed.
- Focused Windows text/binary: 4/4 passed.
- Focused Windows AF-01: 2/2 passed.
- Full Windows integration: 38/38 passed.
- Focused Chromium: 4/4 passed.
- Focused WebKit: 4/4 passed.
- Safari observer source verification: passed.
- Dart analysis for integration and Safari harness: passed.
- Node syntax checks, formatting, and `git diff --check`: passed.

Local environment limitations retained for Task 6 CI validation:

- Playwright Firefox cannot launch on this Windows host (`spawn UNKNOWN`);
  direct launch reports an invalid side-by-side configuration. No harness or
  CI setting was changed; the mandatory Linux Firefox job remains authoritative.
- A combined full Chromium/WebKit run completed 85/92. The seven failures were
  load-dependent semantics-startup/font-fallback timeouts (six Chromium, one
  WebKit). An independent full Chromium rerun completed 41/46 with the same
  Windows 16-worker resource symptoms. All focused UC-21 checks passed at the
  unchanged worker setting. CI retries and target gates remain unchanged.

## Concerns

Linux, Firefox, and native Safari execution are intentionally deferred to the
existing mandatory CI jobs because they are unavailable on this Windows host.
Task 6 must require those jobs and the aggregate cross-platform gate before
delivery.
