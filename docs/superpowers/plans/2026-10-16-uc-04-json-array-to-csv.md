# UC-04 Convert JSON Array to CSV Implementation Plan

**Goal:** Serialize JSON-object arrays as deterministic standards-compliant CSV
through the shared utility, CLI, and GUI.

**Architecture:** Reuse the shared JSON-row contract in `chimera_utilities`,
serialize with the maintained `csv` package, map typed failures in
`chimera_core`, and keep adapters responsible only for local input/output and
localized presentation.

## Coverage checklist

- [x] Main flow: derived columns, delimiter selection, and headers on/off.
- [x] Main flow: standards-compliant quoting and nested JSON preservation.
- [x] Main flow: returned CSV and exact local-file output.
- [x] Main flow: stable CLI JSON and localized human/GUI behavior.
- [x] AF-01: location-aware JSON and typed CSV-option failures.
- [x] AF-02: typed output-access failure with no reported partial result.
- [x] CLI argument, stdin, and local-file inputs with documented exit codes.
- [x] GUI route, typed/pasted/local-file input, preview/save, localization,
  accessibility, and responsive behavior.
- [x] No persistence, network call, or sensitive diagnostic content.

## Tasks

1. [x] Add failing utility tests for serialization and invalid options.
2. [x] Implement the shared CSV request, result, and converter.
3. [x] Add and satisfy core typed-result tests.
4. [x] Add and satisfy CLI functional and output-file tests.
5. [x] Add and satisfy GUI widget and integration tests.
6. [x] Extend compiled-browser and native Safari coverage.
7. [x] Update localization and product documentation.
8. [x] Run formatting, analysis, focused suites, full suites, and platform checks.
9. [ ] Obtain independent review, resolve findings, merge, delete the branch,
   close the issue, and move its project item to Done.
