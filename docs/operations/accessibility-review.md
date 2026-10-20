# Foundation Accessibility Review Evidence

This record covers the foundation application shell. Repeat it for each release
candidate as interactive utility surfaces are added.

- Release version: Foundation candidate for issue #1
- Commit: `feature/project-scaffold`
- Reviewer: Chimera foundation implementation review
- Date: 2026-10-16
- Target: web, Windows, and Linux shell
- Locale: English and Brazilian Portuguese

## Checks

- [x] The shell contains no interactive utility controls; the application root is keyboard focusable.
- [x] The foundation shell has a single logical focus region and no focus-order trap.
- [x] The application heading is exposed with heading semantics in both locales.
- [x] Flutter's automated text-contrast and tap-target guidelines pass for the shell.
- [x] The centered shell remains usable at narrow viewport sizes and 200% text scale.
- [x] English and Brazilian Portuguese shell labels render without clipping in widget tests.
- [x] No utility input or output exists in the shell or its diagnostic/accessibility artifacts.

## Evidence and Findings

Automated guideline output, widget coverage, and performance output are attached
to the `accessibility-and-performance-evidence` CI artifact. There are no open
foundation-shell findings. Each later utility PR must add controls to the
automated guideline checks and update this review when it changes the shell.

## UC-16 Base64 Encode

- Release version: UC-16 candidate for issue #17
- Branch: `feature/uc-16-base64-encode`
- Reviewer: Chimera UC-16 implementation review
- Date: 2026-10-17
- Target: web, Windows, and Linux Base64 encode surface
- Locale: English and Brazilian Portuguese

### Checks

- [x] Focus traversal follows text, file, paste, encode, bounded result,
  copy, and save order; buttons support keyboard activation.
- [x] The text field, binary-file summary, actions, result region, notices,
  and live errors expose localized labels in both locales.
- [x] Result semantics announce explicit localized success wording plus input
  bytes and output characters without exposing an arbitrarily long Base64
  value; the visible Base64 remains selectable and the labeled copy action
  transfers it exactly.
- [x] Flutter's automated Android tap-target, labeled-target, and text-contrast
  guidelines pass with an encoded result present in both English and Brazilian
  Portuguese.
- [x] The page remains usable at a 320-pixel logical width and 200% text scale
  in English and Brazilian Portuguese without overflow.
- [x] Busy source acquisition disables competing actions and clears stale
  output; localized access and resource errors use live-region semantics.

### Evidence and Findings

The GUI widget regression run covers 126 tests, including focused UC-16 text,
empty text, binary file, clipboard, exact copy/save, exclusive input mode,
clipboard-writer/file-saver/output-buffer allocation cleanup, stale/busy state,
keyboard traversal, localized bounded semantics, automated guidelines in both
locales, and narrow large-text cases. No UC-16 accessibility findings remain
open.

## UC-17 Base64 Decode

- Release version: UC-17 candidate for issue #18
- Branch: `feature/uc-17-base64-decode`
- Reviewer: Chimera UC-17 implementation review
- Date: 2026-10-17
- Target: web, Windows, and Linux Base64 decode surface
- Locale: English and Brazilian Portuguese

### Checks

- [x] Focus traversal follows Base64 input, file, paste, output mode, decode,
  bounded result, text copy when available, and save; controls support keyboard
  activation and the completed result receives focus.
- [x] The multiline input, source actions, output modes, result, copy/save
  actions, notices, and errors expose localized labels in both locales.
- [x] Success semantics announce mode, input characters, output bytes, and
  renderer-confirmed image availability without announcing arbitrary decoded
  content; visible decoded text remains selectable.
- [x] Binary image previews are excluded from duplicate semantics, rendered
  from page-owned disposable images, and accompanied by a localized live-region
  availability notice.
- [x] Flutter's automated Android tap-target, labeled-target, and text-contrast
  guidelines pass in English and Brazilian Portuguese.
- [x] The page remains usable at a 320-pixel logical width and 200% text scale
  in both locales without overflow.
- [x] Busy source/preview work disables racing actions, while localized access,
  resource, and nonfatal preview notices use live-region semantics.

### Evidence and Findings

The GUI widget regression run covers 141 tests, including focused UC-17 text,
empty text, binary file, clipboard, exact copy/save, exclusive sources and
modes, real PNG/JPEG/GIF/WebP renderer fixtures, corrupt and failing previews,
owned-preview disposal at every lifecycle boundary, stale/busy behavior,
keyboard traversal, bounded semantics, automated guidelines, and narrow
large-text layouts. No UC-17 accessibility findings remain open.

## UC-18 Inspect Certificate

- Release version: UC-18 candidate for issue #19
- Branch: `feature/uc-18-inspect-certificate`
- Reviewer: Chimera UC-18 GUI implementation self-review
- Date: 2026-10-17
- Target: shared Flutter web, Windows, and Linux certificate inspection surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Keyboard traversal follows multiline certificate input, local file,
  clipboard paste, Auto/PEM/DER/Base64, inspect, result, and JSON copy. Keyboard
  activation works and inspection success focuses the result region.
- [x] The page title, home action, input, source actions, representation,
  inspect/copy, human metadata labels, notices, and failures are localized.
- [x] The selectable metadata report scrolls within a maximum 320 logical-pixel
  viewport. Its region semantics announce success, detected representation,
  and subject/issuer/extension counts; certificate values are excluded from
  duplicate result semantics.
- [x] Errors and copy notices use live regions. File, clipboard, and copy access
  failures and allocation failures show only safe localized messages and clear
  prior source, result, and enabled result actions.
- [x] In-flight actions disable input, source actions, representation, inspect,
  and copy. Generation checks suppress late success and failure after source or
  representation changes and after disposal.
- [x] Flutter Android tap-target, labeled-target, and text-contrast guidelines
  pass for the inspection page in both locales.
- [x] Both locales render input, source/representation controls, selectable
  metadata, and copy without overflow at 320 logical pixels and 200% text scale.

### Evidence and Findings

`flutter test --no-pub --reporter expanded` in `apps/chimera_gui` passes all
189 GUI tests, including the complete widget suite, a catalog check, and the
startup performance test.
The 45 focused certificate tests cover real public PEM/DER/Base64 fixtures,
text/file/clipboard exclusivity, explicit text/DER mismatch, exact JSON copy,
localized human metadata, malformed/unsupported/multiple certificates, access
and allocation failures, cancellation, all asynchronous stale-completion paths,
busy controls, keyboard order, bounded semantics, automated accessibility
guidelines, and narrow large-text layouts. A separate widget test opens the
certificate route through the localized home action.

Strict Flutter analysis passes with no issues. These are automated widget
findings; native screen-reader and real-browser platform evidence is recorded
separately by the cross-platform acceptance work. No automated UC-18
accessibility findings remain open.

## UC-19 Convert Certificate

- Release version: UC-19 candidate for issue #20
- Branch: `feature/uc-19-convert-certificate`
- Reviewer: Chimera UC-19 GUI implementation self-review
- Date: 2026-10-17
- Target: shared Flutter web, Windows, and Linux certificate conversion surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Keyboard traversal follows certificate input, file, clipboard paste,
  Auto/PEM/DER/Base64 source, PEM/DER/Base64 target, convert, result, copy for
  text targets, and save. Keyboard activation works; success focuses the result.
- [x] Selector semantics include localized source/target context, making the
  repeated PEM/DER/Base64 choices distinguishable without sight.
- [x] PEM/Base64 output is exact selectable text in a bounded 320 logical-pixel
  viewport. DER shows source/target representations and byte counts, with save
  available and no certificate text or copy action.
- [x] The live result region announces only safe source/target representations
  and input/DER/output byte counts; certificate data is excluded from semantics.
- [x] Errors and copy/save notices use localized live regions. Failed load,
  conversion, copy, and save clear source/result/notices and result actions.
  Allocation exhaustion, including deferred text materialization, is localized.
- [x] File-picker and save cancellation preserve completed output. Generation
  guards ignore stale success/failure after source/selector changes or disposal;
  every source, selector, conversion, copy, and save control disables while busy.
- [x] All source/selector/convert controls measure at least 48 by 48 logical
  pixels. Flutter Android tap-target, labeled-target, and text-contrast guidelines
  pass before and after conversion in both locales.
- [x] Both locales render at 320 logical pixels and 200% text scale without
  overflow; selectable output and copy/save remain reachable by scrolling.

### Evidence and Findings

The focused conversion widget file passes 94 tests. The full GUI widget suite
passes 284 tests, including localized conversion home navigation. The complete
localization suite passes 15 tests with exact catalog key parity. Tests cover
real public certificate fixtures, all file source/target pairs, exclusive text,
file and clipboard input, exact copy text, immutable save-byte identity and one
handoff, DER presentation, malformed/multiple/mismatched input, typed injected
target validation, boundary and allocation failures, neutral cancellation,
source/result cleanup, deferred text resource failure, 30 stale/disposal paths,
keyboard order, safe semantics, control sizes, contrast, and narrow large text.

The GUI save guarantee is exact byte handoff to the injected/platform adapter;
platform file-picker implementations own their save transaction. No GUI path-level
staging or rollback claim is made. These are automated widget findings; native
screen-reader and compiled browser/platform evidence belongs to cross-platform
acceptance. No automated UC-19 accessibility findings remain open.

## UC-20 GZIP Compress

- Release version: UC-20 candidate for issue #21
- Branch: `feature/uc-20-gzip-compress`
- Reviewer: Chimera UC-20 GUI implementation self-review
- Date: 2026-10-17
- Target: shared Flutter web, Windows, and Linux compression surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Keyboard focus follows multiline text, local file, clipboard paste,
  compression level, compress, binary result, and save. Enter activates compress;
  success focuses the result and Tab reaches save.
- [x] The title, home action, input, source actions, level, compress/save,
  result labels, notices, and errors are localized in both locales.
- [x] The result is a live region announcing success, level, input bytes, and
  output bytes. Binary content is never rendered, selected, or copied.
- [x] Successful compression immediately discards text, file bytes, and editor
  undo history while preserving the exact output for save and focusing result.
- [x] File, clipboard, service, and save access/allocation failures publish only
  safe localized live errors and clear source, result, notices, and save actions.
- [x] Busy actions disable input, file, paste, level, compress, and save.
  Generation guards ignore late success/failure after text or level changes and
  disposal. Disposal explicitly clears the text controller.
- [x] File-picker and save cancellation are neutral and preserve completed
  output. Source/level changes clear prior output and notices.
- [x] Source, level, compress, and save controls measure at least 48 by 48 logical
  pixels. Flutter Android tap-target, labeled-target, and text-contrast
  guidelines pass with a completed result in both locales.
- [x] At 320 logical pixels and 200% text scale, both locales render without
  overflow and the save action remains reachable by scrolling.

### Evidence and Findings

`flutter test --no-pub --reporter expanded test` passes all 396 GUI tests,
including 109 focused GZIP tests, localized home navigation, the existing widget
surfaces, catalog checks, and startup performance. The complete localization
suite passes 17 tests with exact English/PT-BR key parity; reviewed CLI/shared
GZIP messages remain unchanged. Strict GUI and localization analysis pass.

The GZIP regressions cover empty/text/raw-file/clipboard input, default level 6,
levels 0 and 9, all ten selector choices, independent GZIP decoding, one service
call per compression, immutable byte identity at the injected save boundary and
platform file picker, default `.gz` filename and `application/gzip` MIME,
exclusive sources, neutral cancellation, typed invalid Unicode/byte/level and
input/output resource limits, access/allocation redaction in both locales,
24 stale success/failure/disposal paths, source clearing on disposal, focus,
live regions, control sizes, contrast, and narrow large-text layouts.

Review follow-up also verifies that source cleanup disposes the editor's undo
history and pending snapshot timer. Ctrl+Z/Ctrl+Shift+Z cannot restore discarded
text after successful compression, file/clipboard replacement, or access/resource
failure. Both settled and pending success snapshots are covered. Ordinary
editing undo/redo still works before and after a source reset; keyboard focus
and page-owned controller listeners remain intact.

Saving promises exact one-time payload handoff; platform file-picker
implementations own their save transaction. These are automated widget findings;
native screen-reader and compiled browser/platform evidence belongs to Task 5.
No automated UC-20 accessibility findings remain open.

## UC-21 GZIP Decompress

- Release version: UC-21 candidate for issue #22
- Branch: `feature/uc-21-gzip-decompress`
- Reviewer: Chimera UC-21 GUI implementation self-review
- Date: 2026-10-17
- Target: shared Flutter web, Windows, and Linux decompression surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Keyboard focus follows local file, explicit Text/Binary mode,
  decompress, result, text copy when applicable, and save. Success focuses the
  result; all actions support keyboard activation.
- [x] The title, home action, file input, mode choices, decompress/copy/save,
  result summaries, notices, and failures are localized in both locales.
- [x] The live result region announces only success and byte counts. Exact text
  remains selectable and copyable, including U+FEFF, while binary bytes are
  never rendered or exposed to the clipboard.
- [x] Successful decompression discards application-owned source state before
  the asynchronous operation completes and retains only the immutable result
  needed for one exact copy/save handoff.
- [x] File, service, clipboard, and save failures publish only safe localized
  live errors and clear source, result, notices, and result actions. Resource
  exhaustion is distinguished from validation/access failures.
- [x] Busy work disables file, mode, decompress, copy, and save actions.
  Generation guards ignore late service/file/copy/save completions after
  disposal; file and save cancellation remain neutral.
- [x] File, mode, decompress, copy, and save controls meet the 48-by-48 logical
  pixel target. Flutter Android tap-target, labeled-target, and text-contrast
  guidelines pass with completed results in both locales.
- [x] At 320 logical pixels and 200% text scale, both locales render without
  overflow and selectable output plus copy/save remain reachable by scrolling.

### Evidence and Findings

The focused UC-21 widget file passes 21 tests. The complete GUI suite passes
419 tests, including localized home navigation, every existing widget surface,
catalog checks, and startup performance. The complete localization suite passes
19 tests with exact English/PT-BR key parity; strict GUI and localization
analysis report no issues.

UC-21 regressions cover extension-independent GZIP input, empty/ASCII/Unicode
and BOM-prefixed text, arbitrary binary, explicit mode behavior, invalid UTF-8,
corruption, resource limits, exact immutable byte identity and one-time platform
save handoff, `.txt`/`.bin` filenames and MIME types, source discard, redacted
file/copy/save/service failures, cancellation, busy controls, disposal guards,
focus order, bounded live semantics, target sizes, contrast, and narrow large
text layouts. Platform adapters own their save transaction; native screen-reader
and compiled browser/platform evidence belongs to Task 5. No automated UC-21
accessibility findings remain open.

## UC-22 HTML Encode

- Release version: UC-22 candidate
- Branch: `feature/uc-22-html-encode`
- Reviewer: Chimera UC-22 GUI implementation self-review
- Date: 2026-10-18
- Target: shared Flutter web, Windows, and Linux encoding surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Focus follows typed input, file, paste, context, encode, result, copy,
  and save. Keyboard activation works and success focuses the result.
- [x] The home action, title, input, sources, four contexts, actions, result,
  notices, and failures are localized in both locales.
- [x] Exact output is selectable in a scrolling region bounded to 240 logical
  pixels. The live result semantics announce only the localized result label
  and success summary; long source/output text is excluded from announcements.
- [x] Copy/save success and safe failures use localized live semantics. File,
  clipboard, service, copy, save, and output-buffer failures distinguish access,
  validation, and resource categories and clear source, result, and notices.
- [x] All competing controls disable during asynchronous actions. Thirty
  success/failure paths verify generation guards after source/context changes
  or disposal. File, clipboard, and save cancellation preserve completed output.
- [x] File and clipboard sources replace typed input exclusively. Successful
  encoding discards the editor history and raw source; Undo/Redo cannot restore
  discarded text. Disposal clears the source and invalidates pending work.
- [x] The six source/context/encode/copy/save controls measure at least 48 by 48
  logical pixels. Android tap-target, labeled-target, and text-contrast
  guidelines pass with completed results in both locales.
- [x] At 320 logical pixels and 200% text scale, both locales support opening
  the actual selector and choosing every context without overflow. Output,
  copy, and save remain reachable by scrolling.

### Evidence and Findings

The focused HTML suite passes 134 tests. App navigation plus both existing GZIP
regression files pass 285 tests. The complete GUI suite passes 559 tests,
including all existing widgets and startup performance. The complete
localization suite passes 21 tests with exact English/PT-BR key parity. Strict
GUI and localization analysis and formatting checks pass.

Coverage includes every context and typed/file/clipboard/empty source, strict
malformed UTF-8 and Unicode failures, clipboard rejection before invalid UTF-16
can reach Flutter's renderer, BOM/CRLF/NUL preservation, existing entity-looking
text, source exclusivity and Undo-history disposal, safe typed service
categories, access/allocation failures in both locales, neutral cancellation,
all asynchronous lifecycle guards, exact one-time copy/save handoffs, empty
output, `.txt` filename/MIME, and native default-picker fallthrough.

The current release web build succeeds. The unchanged compiled generic-adapter
regressions pass all four empty text/binary scenarios across Chromium and
WebKit: exact zero bytes, one download, expected MIME/filename, zero live object
URLs after activation, zero observer errors, and no interaction/external HTTP
requests. This repeats Task 4's empty Blob/one click/revocation proof as a shared
adapter dependency check; it does not replace HTML-specific Task 6 coverage.

These findings are automated GUI evidence. HTML-specific compiled browser,
native platform, and screen-reader evidence belongs to Task 6. No automated
UC-22 accessibility finding remains open.

## UC-23 HTML Decode

- Release version: UC-23 candidate
- Branch: `feature/uc-23-html-decode`
- Reviewer: Chimera UC-23 GUI implementation self-review
- Date: 2026-10-18
- Target: shared Flutter web, Windows, and Linux decoding surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Focus follows typed input, file, paste, decode, result, copy, and save.
  Keyboard activation works and successful decoding focuses the result region.
- [x] The home action, title, input, source actions, result actions, notices,
  and safe failure messages are localized in both locales.
- [x] Exact decoded output is selectable in a scrolling region bounded to 240
  logical pixels. The live result region announces a localized label and
  success summary without exposing source or output contents.
- [x] File, clipboard, service, copy, save, and output-buffer access or
  allocation failures clear source, result, and notices and publish only a
  localized live-region category.
- [x] Competing controls disable during asynchronous work. Generation and
  disposal guards prevent stale completion from publishing; canceled file and
  clipboard selection preserves an existing completed result.
- [x] File and clipboard sources replace typed input exclusively. Completion
  discards raw source and editor history so Undo/Redo cannot recover it.
- [x] Every action target measures at least 48 by 48 logical pixels. Android
  tap-target, labeled-target, and text-contrast guidelines pass in both locales.
- [x] At 320 logical pixels and 200% text scale, output, copy, and save remain
  reachable by scrolling without overflow.

### Evidence and Findings

The focused HTML Decode suite passes 40 tests. Combined focused Decode and app
navigation suites pass 196 tests, with strict GUI analysis reporting no issues.
The complete GUI suite passes 604 tests, and the complete localization suite
passes 23 tests with exact English/PT-BR key parity and clean analysis.
Coverage includes typed/file/clipboard/empty input, named and decimal/hex
numeric entities, decode-once behavior, strict malformed entities, invalid
UTF-8 and Unicode scalars, typed service categories, access/allocation failures,
safe redaction, cancellation, stale completion, disposal, source/history
discard, keyboard traversal, live semantics, target sizes, contrast, large
text, exact UTF-8 copy/save data, zero-byte output, filename, and MIME type.

Task 5 adds 62 passing Windows native integration tests and 183 passing
compiled-browser tests across Chromium, Firefox, and WebKit. The native Safari
driver validates all 16 embedded HTML helpers before its mandatory macOS CI run.
The platform coverage exercises real keyboard submission, exact localized
results, copy/save bytes (including empty output), URL cleanup, malformed UTF-8
recovery, and zero external requests. No automated UC-23 accessibility finding
remains open.

## UC-24 JWT Create

- Release version: UC-24 candidate
- Branch: `feature/uc-24-jwt-create`
- Reviewer: Chimera UC-24 GUI implementation self-review
- Date: 2026-10-18
- Target: shared Flutter web, Windows, and Linux JWT creation surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Algorithm, header, claims, key, submit, result, copy, and save controls
  follow document order and remain keyboard operable.
- [x] The private key editor obscures content and disables suggestions and
  autocorrection. Header, claims, key, and editor history are discarded when a
  signing attempt begins and again on failure or disposal.
- [x] Result, notice, and error regions use localized accessible labels and live
  announcements without including claims or key material.
- [x] File and clipboard loading is local, cancellation is neutral, competing
  controls disable while busy, and generation guards reject stale completion.
- [x] The responsive scrolling layout keeps all actions reachable at narrow
  widths and large text. Material buttons retain minimum accessible targets and
  theme-derived contrast.
- [x] Copy and save hand off one exact compact token; failures clear stale
  output and publish only localized safe categories.

### Evidence and Findings

Focused widget coverage exercises home routing, direct/file/clipboard sources,
source discard, key obscuring, HMAC signing, redacted validation, both locales,
and exact copy/save filename, MIME, and bytes. The complete GUI suite and
fatal-info analysis are mandatory delivery gates. Native and compiled-browser
coverage is recorded with Task 5. No automated UC-24 accessibility finding is
open.

## UC-25 JWT Inspect

- Release version: UC-25 candidate
- Branch: `feature/uc-25-jwt-inspect`
- Reviewer: Chimera UC-25 GUI implementation self-review
- Date: 2026-10-18
- Target: shared Flutter web, Windows, and Linux JWT inspection surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Token, optional key, submit, result, and copy controls follow document
  order, remain keyboard operable, and use localized labels in both locales.
- [x] The optional key editor obscures content and disables suggestions and
  autocorrection. Token, key, and editor history are discarded when an
  inspection attempt begins and again on failure or disposal.
- [x] The result is a focusable live region with bounded localized semantics.
  A signature mismatch keeps decoded data visible while an additional live
  warning explicitly identifies that data as untrusted.
- [x] File and clipboard loading remains local, cancellation is neutral,
  competing controls disable while busy, and generation guards reject stale
  completion after source changes or disposal.
- [x] File, paste, submit, and copy actions measure at least 48 by 48 logical
  pixels and satisfy labeled-target and theme-derived contrast guidance.
- [x] At 320 logical pixels and 200% text scale, both locales keep every source,
  submit, result, warning, and copy action reachable through scrolling without
  overflow.
- [x] Copy hands off one stable JSON result. Service, file, clipboard, copy,
  decoding, and allocation failures clear sensitive sources and stale output
  while publishing only a localized safe category.

### Evidence and Findings

Focused widget coverage exercises home and direct routing, typed/file/clipboard
sources, optional-key obscuring, verified and failed statuses, explicit
untrusted-state presentation, source/history discard, exact stable JSON copy,
safe redaction, access and allocation boundaries, cancellation, source-change
invalidation, late completion, live semantics, target sizes, contrast, and
narrow large-text layouts in both locales. All 14 focused widget tests pass;
the complete GUI suite passes 630 tests, and the localization suite passes 24
tests with exact locale parity. Fatal-info analysis reports no GUI or
localization issues. The Windows native suite passes 66 integration tests,
including both locale matrices for decode-only, verified HMAC/RSA/ECDSA, and
failed/untrusted results with exact copy and zero network. The focused compiled
web scenario passes Chromium and WebKit locally; the same Firefox scenario is
committed for the Linux/Docker CI runner because the installed Windows Firefox
binary fails before launch. The analyzed native Safari harness exercises the
same five scenarios in its mandatory macOS CI job. No automated UC-25
accessibility finding is open.

## UC-26 QR Encode

- Release version: UC-26 candidate
- Branch: `feature/uc-26-qr-encode`
- Reviewer: Chimera UC-26 GUI implementation self-review
- Date: 2026-10-18
- Target: shared Flutter web, Windows, and Linux QR encoding surface
- Locales: English and Brazilian Portuguese

### Checks

- [x] Text, file, paste, correction, size, margin, color, generate, preview,
  metadata, and save controls follow document order and remain keyboard
  operable.
- [x] The generated preview has a localized image label. The result is a
  focusable live region with bounded localized size, version, and correction
  metadata; focus moves to it after generation.
- [x] Source text and editor undo history are discarded after success or
  failure. Source changes invalidate stale output, and adapter failures expose
  only localized safe categories.
- [x] File and clipboard loading stays local, cancellation is neutral, and
  controls disable while an operation is busy.
- [x] File, paste, generate, and save controls measure at least 48 by 48
  logical pixels. Both locales remain free of overflow at 320 logical pixels
  and 200% text scale and satisfy labeled-target and contrast guidance.
- [x] Preview and save consume the same unmodifiable PNG byte buffer without a
  presentation-layer re-encode.

### Evidence and Findings

Focused widget coverage exercises home routing, typed/file/clipboard sources,
every configurable option, exact preview/save bytes, source and undo-history
discard, stale-result invalidation, safe adapter failures, focus, live
semantics, localization, target sizes, contrast, and narrow large-text layouts
in both locales. The 14 focused widget tests now include explicit keyboard
traversal, neutral file/clipboard cancellation, bounded file input, and Flutter
image-cache eviction. The complete GUI suite passes 647 widget tests and 68
Windows integration tests. The 195-test Playwright matrix passes across
Chromium, Firefox, and WebKit; the analyzed native Safari harness covers the
same local generation, PNG download, validation, source discard, and zero
external-request contract. No automated UC-26 accessibility finding remains
open.

## UC-27 QR Decode

- Branch: `feature/uc-27-qr-decode`
- Date: 2026-10-19
- Targets: shared Flutter web, Windows, and Linux image-decoding surface
- Locales: English and Brazilian Portuguese

The image picker, decode, focusable result, copy, and save controls follow
keyboard order. Successful decoding moves focus to a localized live result
region; errors and notices use live announcements. Decoded text remains
selectable within a bounded scrolling region. Metadata labels, actions, safe
errors, and notices are localized in both catalogs.

Widget coverage checks cancellation, stale-result cleanup, busy controls,
resource and access failures, disposal of pending file/service work, and exact
Unicode copy/save behavior. Native integration and compiled-browser scenarios
exercise local image loading, successful decoding, exact UTF-8 output, corrupt
image rejection, and absence of utility network requests. The native Safari
harness executes the same fixture through the real browser file adapter.

## UC-33 Generate Password

- Branch: `feature/uc-33-generate-password`
- Date: 2026-10-19
- Targets: shared Flutter web, Windows, and Linux password-generation surface
- Locales: English and Brazilian Portuguese

The length field and each character-class switch expose localized labels and
follow document-order keyboard traversal. Enter submits the form. Generate,
copy, and save actions disable while work is pending, while validation and
processing failures are announced through localized live messages without
including generated or diagnostic-sensitive data.

Successful generation moves focus to a localized live result region whose
accessible value is the generated password. Copy and save consume that exact
result. Configuration changes, failures, late completions, and disposal clear
stale result state so a previous password cannot remain available through the
presentation controls.

Focused widget and save-adapter coverage exercises both locales, keyboard
submission, labeled controls, focus and live semantics, exact copy/save output,
busy behavior, stale completion, source changes, disposal, and redacted failure
messages. Seven Windows integration tests exercise production secure entropy,
local generation, exact
character-class constraints, copy/save/discard behavior, validation and secure
random failures, and zero network access. Twenty-one compiled-browser scenarios
pass across Chromium, Firefox, and WebKit; the native Safari harness includes
the same local-generation, production secure-entropy-failure, resource-limit,
and no-network contract for its mandatory macOS CI job. No automated UC-33
accessibility finding remains open.

## UC-34 Generate UUID or GUID

- Branch: `feature/uc-34-generate-uuid`
- Date: 2026-10-19
- Targets: shared Flutter web, Windows, and Linux identifier-generation surface
- Locales: English and Brazilian Portuguese

The version and representation selectors, positive-integer count field, and generate,
copy, and save actions expose localized labels in document-order keyboard
traversal. Enter submits the count field. Actions disable while work is
pending, while validation, processing, resource, and adapter failures are
announced through localized live messages without exposing partial values or
private diagnostics.

Successful generation moves focus to a localized live result region whose
accessible value contains the complete generated batch. Copy and save consume
the same newline-delimited value. Configuration changes, failures, late
completions, and disposal clear stale result state.

Focused widget and save-adapter coverage exercises both locales, v4/v7 and
UUID/GUID choices, positive counts, keyboard submission, focus and live
semantics, exact multi-value copy/save output, busy behavior, stale completion,
and redacted failures. Native and compiled-browser scenarios exercise secure
production generation, RFC version and variant shapes, v7 time ordering,
uniqueness, exact transfer, discard behavior, and zero network access. The
native Safari harness covers the same local-only path. No automated UC-34
accessibility finding remains open.

## UC-35 Generate Credit Card

- Branch: `feature/uc-35-generate-credit-card`
- Date: 2026-10-20
- Targets: shared Flutter web, Windows, and Linux synthetic-card surface
- Locales: English and Brazilian Portuguese

The network selector, positive-integer count field, and generate, copy, and save
actions expose localized labels in document-order keyboard traversal. Enter
submits the count field. Actions disable while work is pending. Validation,
processing, resource, and adapter failures are announced through localized live
messages without exposing partial card numbers or private diagnostics.

Successful generation moves focus to a localized live result region. A visible
and accessible warning labels every value as synthetic test data that must not
be used for real transactions. Copy and save include that warning before the
same newline-delimited values. Configuration changes, failures, late
completions, and disposal clear stale result state.

Focused widget and save-adapter coverage exercises both locales, all four
networks, positive counts, keyboard submission, focus and live semantics,
exact labeled multi-value copy/save output, busy behavior, stale completion,
and redacted failures. Native and compiled-browser scenarios exercise the
closed published sandbox catalogue, exact transfer, discard behavior, and zero
network access. The native Safari harness covers the same local-only path. No
automated UC-35 accessibility finding remains open.

## UC-36 Generate Identity Document

- Branch: `feature/uc-36-generate-identity-document`
- Date: 2026-10-20
- Targets: shared Flutter web, Windows, and Linux synthetic-identity surface
- Locales: English and Brazilian Portuguese

The locale, document-type, optional CNPJ-format, and positive-integer count
controls expose localized labels in document-order keyboard traversal. Enter
submits the count field. Actions disable while work is pending, and the CNPJ
format control is present only when it applies. Long document labels remain
responsive at narrow widths.

Successful generation moves focus to a localized live result region. A visible
and accessible warning labels every value as synthetic test data and explicitly
states that it is not proof of issuance. Copy and save include that warning
before the same newline-delimited values. Configuration changes, failures, late
completions, and disposal clear stale result state.

Focused widget and save-adapter coverage exercises both locales, every selector,
both CNPJ formats, positive counts, keyboard submission, focus and live
semantics, exact labeled multi-value copy/save output, cancellation, busy
behavior, stale completion, retry exhaustion, and redacted failures. Native and
compiled-browser scenarios exercise representative US and Brazilian documents,
both CNPJ formats, exact transfer, discard behavior, and zero network access.
The native Safari harness covers the same local-only path. No automated UC-36
accessibility finding remains open.

## UC-39 Decode with Cipher

- Branch: `feature/uc-39-decode-cipher`
- Date: 2026-10-20
- Targets: shared Flutter web, Windows, and Linux classical-cipher surface
- Locales: English and Brazilian Portuguese

The source editor, file and clipboard actions, cipher and unsupported-symbol
selectors, conditional parameter fields, decode action, result region, copy,
and save controls expose localized labels in document-order keyboard traversal.
Every interactive target remains at least 48 logical pixels, and the page stays
usable at a 320-pixel logical width and 200% text scale.

Successful decoding moves focus to a localized live result region whose visible
plaintext remains selectable. Copy and save consume that exact result. Input,
key material, and parameters are cleared when the request starts; configuration
changes, failures, late adapter completions, and disposal cannot retain or
restore stale plaintext or source data.

Focused widget coverage exercises both locales, conditional controls, all input
adapters, exact copy/save, keyboard order, automated accessibility guidelines,
redacted validation and access failures, and pending-operation disposal. Native
Windows integration verifies both locales, exact local transfer, invalid keys,
unsupported-symbol rejection, discard behavior, and zero network attempts.
Compiled Chromium, Firefox, and WebKit plus the native Safari harness cover the
same main and alternate flows. No automated UC-39 accessibility finding remains
open.
