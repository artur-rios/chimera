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
