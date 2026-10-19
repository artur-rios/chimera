# UC-29 Windows Path Portability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make UC-29's executable save verification portable across Windows and POSIX path separators without weakening its artifact check.

**Architecture:** Keep production URL decoding unchanged because the subprocess output and saved bytes are correct. Compare directory entries and expected files by canonical file URI so equivalent native paths match on every supported host.

**Tech Stack:** Dart 3.13.5 (workspace constraint `^3.13.0`), package:test, dart:io

**Spec:** `docs/requirements/Use Case Specification Document.md` (UC-29) and GitHub issue #30

## Global Constraints

- Preserve the assertion that exactly the input and output files exist after a successful save.
- Preserve all six source/JSON combinations and both malformed-input cases.
- Do not change production URL decoding behavior.

## Review Focus

- Windows directory enumeration may canonicalize separators differently from `File(String)` construction.
- POSIX paths must continue to compare exactly.
- Unexpected staging or temporary files must still fail the assertion.
- Argument, stdin, and file sources must all remain covered.
- Human and JSON output modes must both remain covered.

---

### Task 1: Canonicalize file identity in the subprocess test

**Files:**
- Modify: `apps/chimera_cli/test/functional/url_decode_process_test.dart`
- Test: `apps/chimera_cli/test/functional/url_decode_process_test.dart`

**Interfaces:**
- Consumes: `FileSystemEntity.uri` from `dart:io`.
- Produces: A platform-neutral assertion over the exact two expected file URIs.

- [ ] **Step 1: Verify the existing regression test fails on Windows**

Run: `dart test apps/chimera_cli/test/functional/url_decode_process_test.dart`
Expected: six failures showing `/input.txt` and `/output.txt` do not equal enumerated `\\input.txt` and `\\output.txt` paths.

- [ ] **Step 2: Compare canonical file URIs**

Change the final directory-entry assertion to map each enumerated entity to `entry.uri` and compare it with `input.uri` and `output.uri`.

- [ ] **Step 3: Verify the targeted test passes**

Run: `dart test apps/chimera_cli/test/functional/url_decode_process_test.dart`
Expected: 8 tests pass, 0 fail.

- [ ] **Step 4: Run the complete suite**

Run: `dart run melos run test:all`
Expected: every suite passes.

- [ ] **Step 5: Commit**

Commit the plan and test repair with subject `fix: make URL path checks portable`.
