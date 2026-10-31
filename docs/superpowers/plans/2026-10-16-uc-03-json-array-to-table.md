# UC-03 Convert JSON Array to Table Implementation Plan

**Goal:** Render JSON-object arrays as deterministic local tables through the
shared utility, CLI, and GUI.

**Architecture:** Parse and render once in `chimera_utilities`, map typed
failures in `chimera_core`, and keep adapters responsible only for local input
and localized presentation.

## Coverage checklist

- [x] Main flow: derived columns and complete rows.
- [x] Main flow: nested JSON remains serialized and row numbers are optional.
- [x] Main flow: stable CLI JSON and localized human output.
- [x] AF-01: location-aware malformed, non-array, and non-object failures.
- [x] AF-02: typed resource failure with no partial table.
- [x] CLI argument, stdin, and local-file inputs with documented exit codes.
- [x] GUI route, typed/pasted/local-file input, localization, accessibility,
  horizontal scrolling, and responsive behavior.
- [x] No persistence, network call, or sensitive diagnostic content.

## Tasks

1. [x] Add failing utility tests for rendering and both alternative flows.
2. [x] Implement the shared table request, result, and converter.
3. [x] Add and satisfy core typed-result tests.
4. [x] Add and satisfy CLI functional tests.
5. [x] Add and satisfy GUI widget and integration tests.
6. [x] Extend compiled-browser and native Safari coverage.
7. [x] Update localization and product documentation.
8. [x] Run formatting, analysis, focused suites, full suites, and platform checks.
9. [ ] Obtain independent review, resolve findings, merge, delete the branch,
   close the issue, and move its project item to Done.
