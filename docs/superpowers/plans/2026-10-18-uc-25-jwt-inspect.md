# UC-25 JWT Inspect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Decode compact JWTs and optionally verify their signatures across
CLI, GUI, desktop, and web.

**Architecture:** Add one strict, `jose`-backed inspector to
`chimera_utilities`, expose it through a typed core service, and keep CLI/GUI as
ephemeral source and presentation adapters.

**Spec:** `docs/superpowers/specs/2026-10-18-uc-25-jwt-inspect-design.md`

## Constraints

- Decode only compact, signed JWTs using the supported HMAC, RSA, or ECDSA
  algorithms; reject `none`, detached payloads, and implicit key discovery.
- Treat a signature mismatch as parsed but explicitly untrusted AF-02 output,
  not as a successful verification or a partial failure.
- Accept strict JSON objects and compatible local verification key material.
- Do not log, persist, or transmit tokens, decoded claims, keys, or results.
- Clear adapter state and mutable byte copies at lifecycle boundaries.
- Return typed, stable, redacted failures and never expose partial output for a
  malformed token or invalid key.
- Cover both locales and every mandated native/browser target.

### Task 1: Shared inspector

- [ ] Add failing known-answer, decode-only, AF-01, AF-02, and boundary tests.
- [ ] Extract the strict JWT JSON decoder shared with JWT creation without
  changing creation behavior.
- [ ] Implement structural parsing, algorithm/header validation, compatible
  local-key parsing, verification, cleanup, typed failures, budgets, and a
  deterministic verification seam.
- [ ] Export the API and pass the complete utility suite.
- [ ] Commit `feat: add local JWT inspector`.

### Task 2: Core service

- [ ] Add failing tests for delegation, stable ordered JSON, every status, and
  every failure mapping.
- [ ] Implement request, output, and service without retaining sensitive input.
- [ ] Pass the complete core suite and commit `feat: add JWT inspect service`.

### Task 3: CLI and localization

- [ ] Add failing parser/source/locale/main-flow/AF-01/AF-02 tests, including
  validation-before-I/O and redaction.
- [ ] Implement `chimera jwt inspect`, strict UTF-8 sources, stable human/JSON
  output, documented exits, and localized messages.
- [ ] Pass l10n and CLI suites and commit `feat: expose JWT inspection in cli`.

### Task 4: GUI and accessibility

- [ ] Add failing route/source/status/discard/error/copy/accessibility widget
  tests in both locales.
- [ ] Implement the localized page, obscured optional-key editor,
  file/clipboard inputs, generation guards, explicit untrusted AF-02 result,
  copy action, and ephemeral state lifecycle.
- [ ] Update accessibility evidence, pass GUI/l10n suites, and commit
  `feat: add JWT inspect page`.

### Task 5: Platform evidence

- [ ] Add Windows/Linux, Chromium/Firefox/WebKit, and native Safari coverage for
  decode-only plus representative HMAC/RSA/ECDSA verified and failed results,
  cleanup, and zero network.
- [ ] Run locally available target suites and commit
  `test: cover JWT inspection targets`.

### Task 6: Delivery

- [ ] Audit all traced requirements and flows.
- [ ] Run formatting, fatal-info analysis, dependency checks, diff checks,
  focused suites, and exact unfiltered `dart run melos run test:all`.
- [ ] Obtain independent branch review and fix every Critical/Important finding
  test-first.
- [ ] Push, open and attach a PR closing issue #26, move it to Testing, wait for
  every required check, squash merge without overrides, and reconcile Done plus
  clean synchronized `develop`.
