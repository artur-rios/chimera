# UC-06 Format JSON Implementation Plan

**Goal:** Validate and format any JSON-compatible value through the shared
utility, CLI, and GUI.

**Architecture:** Parse and emit JSON once with explicit bounds in
`chimera_utilities`, map typed failures in `chimera_core`, and keep local
file/clipboard adapters and localized presentation at the interface boundary.

## Coverage checklist

- [x] Main flow: all JSON root kinds and nested structures are formatted.
- [x] Main flow: 2- and 4-space indentation are deterministic.
- [x] Main flow: formatted JSON and exact local-file output are returned.
- [x] Main flow: stable CLI JSON and localized human/GUI behavior.
- [x] AF-01: location/reason-aware invalid JSON and typed option failures.
- [x] AF-02: clipboard and output-file access failures expose no result.
- [x] CLI argument, stdin, and local-file inputs with documented exit codes.
- [x] GUI typed/pasted, clipboard, and local-file input; preview, copy, save,
  localization, accessibility, and responsive behavior.
- [x] No persistence, network call, or sensitive diagnostic content.

## Tasks

1. [x] Add failing utility tests for formatting, validation, and budgets.
2. [x] Implement the shared JSON format request, result, and formatter.
3. [x] Add and satisfy core typed-result tests.
4. [x] Add and satisfy CLI functional and output-file tests.
5. [x] Add and satisfy GUI widget and integration tests.
6. [x] Extend compiled-browser and native Safari coverage.
7. [x] Update localization and product documentation.
8. [x] Run formatting, analysis, focused suites, full suites, and platform checks.
9. [ ] Obtain independent review, resolve findings, merge, delete the branch,
   close the issue, and move its project item to Done.
