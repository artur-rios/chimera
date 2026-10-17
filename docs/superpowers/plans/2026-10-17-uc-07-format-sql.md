# UC-07 Format SQL Implementation Plan

**Goal:** Format supported SQL deterministically for PostgreSQL, MySQL, SQL
Server, and SQLite through the shared utility, CLI, and GUI.

**Architecture:** Tokenize and emit dialect-aware SQL once with explicit bounds
in `chimera_utilities`, map typed failures in `chimera_core`, and keep local
file/clipboard adapters and localized presentation at the interface boundary.

## Coverage checklist

- [x] Main flow: every supported dialect formats representative SQL.
- [x] Main flow: indentation and keyword-case options are deterministic.
- [x] Main flow: formatted SQL and exact local-file output are returned.
- [x] Main flow: stable CLI JSON and localized human/GUI behavior.
- [x] AF-01: dialect, option, and structure failures include safe locations.
- [x] AF-02: resource failures expose no partial output.
- [x] CLI argument, stdin, and local-file inputs with documented exit codes.
- [x] GUI typed/pasted, clipboard, and local-file input; preview, copy, save,
  localization, accessibility, and responsive behavior.
- [x] No persistence, network call, or sensitive diagnostic content.

## Tasks

1. [x] Add failing utility tests for dialects, options, validation, and budgets.
2. [x] Implement the bounded dialect-aware SQL tokenizer and formatter.
3. [x] Add and satisfy core typed-result tests.
4. [x] Add and satisfy CLI functional and output-file tests.
5. [x] Add and satisfy GUI widget and integration tests.
6. [x] Extend compiled-browser and native Safari coverage.
7. [x] Update localization and product documentation.
8. [x] Run formatting, analysis, focused suites, full suites, and platform checks.
9. [ ] Obtain independent review, resolve findings, merge, delete the branch,
   close the issue, and move its project item to Done.
