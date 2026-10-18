# UC-24 JWT Create Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create and locally sign JWTs across CLI, GUI, desktop, and web.

**Architecture:** Add one `jose`-backed, redacted signer to
`chimera_utilities`, expose it through a typed core service, and keep CLI/GUI as
ephemeral source and output adapters.

**Spec:** `docs/superpowers/specs/2026-10-18-uc-24-jwt-create-design.md`

## Constraints

- Support signed HMAC, RSA, and ECDSA algorithms only; reject `none`.
- Accept strict JSON objects and compatible local private key material.
- Do not log or persist headers, claims, keys, or tokens.
- Clear adapter state and mutable byte copies at lifecycle boundaries.
- Return typed, stable, redacted failures and never partial output.
- Keep output writes transactional and all processing offline.
- Cover both locales and every mandated native/browser target.

### Task 1: Shared signer

- [ ] Add exact `jose` dependency and failing known-answer/validation tests.
- [ ] Implement strict parsing, compatibility checks, signing, cleanup, typed
  failures, budgets, and a deterministic signing seam.
- [ ] Export the API and pass the complete utility suite.
- [ ] Commit `feat: add local JWT signer`.

### Task 2: Core service

- [ ] Add failing tests for delegation, ordered JSON, and every failure mapping.
- [ ] Implement request, output, and service without retaining sensitive input.
- [ ] Pass the complete core suite and commit `feat: add JWT create service`.

### Task 3: CLI and localization

- [ ] Add failing parser/source/output/locale/AF-01/AF-02 tests.
- [ ] Implement `chimera jwt create`, strict UTF-8 sources, transactional save,
  stable exits, redacted diagnostics, and localized messages.
- [ ] Pass l10n and CLI suites and commit `feat: expose JWT creation in cli`.

### Task 4: GUI and accessibility

- [ ] Add failing route/source/result/discard/error/accessibility widget tests.
- [ ] Implement the localized page, obscured key editor, file/clipboard inputs,
  generation guards, copy/save, and ephemeral state lifecycle.
- [ ] Update the accessibility review, pass GUI/l10n suites, and commit
  `feat: add JWT create page`.

### Task 5: Platform evidence

- [ ] Add Windows/Linux, Chromium/Firefox/WebKit, and native Safari coverage for
  representative HMAC/RSA/ECDSA success, failure, cleanup, and zero network.
- [ ] Run locally available target suites and commit
  `test: cover JWT creation targets`.

### Task 6: Delivery

- [ ] Audit all traced requirements and flows.
- [ ] Run formatting, fatal-info analysis, dependency checks, diff checks,
  focused suites, and exact unfiltered `dart run melos run test:all`.
- [ ] Obtain independent branch review and fix every Critical/Important finding
  test-first.
- [ ] Push, open and attach a PR closing issue #25, move it to Testing, wait for
  every required check, squash merge without overrides, and reconcile Done plus
  clean synchronized `develop`.
