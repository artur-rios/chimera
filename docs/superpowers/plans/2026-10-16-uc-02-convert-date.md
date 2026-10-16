# UC-02 Convert Date Implementation Plan

**Goal:** Deliver strict local date, epoch, pattern, and IANA-zone conversion
through the shared utility, CLI, and GUI.

**Architecture:** Keep parsing, range policy, DST resolution, and formatting in
`chimera_utilities`. Map utility exceptions to typed core results. Keep CLI and
GUI limited to input collection and localized presentation.

## Coverage checklist

- [x] Main flow: ISO, Unix seconds, Unix milliseconds, and custom patterns.
- [x] Main flow: source and target IANA-zone conversion.
- [x] Main flow: stable CLI JSON and localized human output.
- [x] AF-01: typed date, epoch, pattern, time-zone, DST-gap, and DST-overlap
  validation failures.
- [x] AF-02: typed range failure with no partial result.
- [x] CLI arguments, stdin, and local-file input with documented exit codes.
- [x] GUI route, typed/pasted/local-file input, localization, accessibility,
  and responsive behavior.
- [x] No persistence, network call, or sensitive diagnostic content.

## Tasks

1. [x] Add failing utility tests for every representation and failure class.
2. [x] Implement the shared date request, result, pattern policy, and converter.
3. [x] Add failing core tests for success, validation, and range mappings.
4. [x] Implement the typed date service and exports.
5. [x] Add failing CLI functional tests for all input and output modes.
6. [x] Implement `chimera date convert` and localized human/JSON rendering.
7. [x] Add failing GUI widget and integration tests for the complete route.
8. [x] Implement the localized accessible date-conversion page.
9. [x] Update browser coverage, documentation, and dependency evidence.
10. [x] Run formatting, analysis, focused suites, full suites, and platform checks.
11. [ ] Obtain independent review, resolve findings, merge, delete the branch,
    close the issue, and move its project item to Done.
