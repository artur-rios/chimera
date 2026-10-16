# UC-01 Parse Cron Expression Implementation Plan

**Goal:** Deliver deterministic, local-only cron parsing and occurrence
calculation through the shared utility, CLI, and GUI.

**Architecture:** Keep syntax and scheduling semantics in
`chimera_utilities`. The CLI and GUI translate shared typed results into their
own localized presentation while using existing core failure kinds and platform
adapters where applicable.

## Coverage checklist

- [x] Main flow: five-field and seconds-aware six-field expressions.
- [x] Main flow: localized explanation and previous/next IANA-zone occurrences.
- [x] Main flow: stable CLI JSON and human output.
- [x] AF-01: syntax, time-zone, reference, and count validation failures.
- [x] AF-02: bounded-search resource failure with no partial occurrences.
- [x] CLI arguments, stdin, and local-file inputs; documented exit codes.
- [x] GUI route, form, localization, accessibility, and responsive behavior.
- [x] No persistence, network call, or sensitive diagnostic content.

## Tasks

1. [x] Add failing utility tests for the parser, evaluator, time zones, and failures.
2. [x] Implement the shared cron request, compiled schedule, result, and calculator.
3. [x] Add failing CLI functional tests for all input and output modes.
4. [x] Implement `chimera cron parse` and localized human/JSON rendering.
5. [x] Add failing GUI widget and integration tests for the full route flow.
6. [x] Implement the cron route and localized accessible form.
7. [x] Update documentation and dependency/boundary evidence.
8. [x] Run formatting, analysis, focused suites, full suites, and local platform verification.
9. [ ] Obtain independent review, resolve findings, merge, delete the branch, close
   the issue, and move its project item to Done.

