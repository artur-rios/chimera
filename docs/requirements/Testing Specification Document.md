# Testing Specification Document — Chimera

## 1. Purpose

This document defines how every Chimera use case is tested. Tests are delivered
in the same change as their behavior; a use case without complete test evidence
is unfinished.

The tools and version policy are defined in the
[Technology Stack Document](Technology%20Stack%20Document.md). The point at which
tests run in delivery is defined in the
[Development Workflow Document](Development%20Workflow%20Document.md).

---

## 2. Testing Philosophy

1. **Behavior over implementation.** Tests name observable input, action, and
   outcome rather than private methods or internal class shape.
2. **One shared behavior contract.** Core utility tests establish the algorithmic
   contract consumed by GUI and CLI adapters.
3. **Test at the narrowest useful layer.** Pure algorithms and validators use
   unit tests; widgets test interaction and localization; executable-level tests
   cover complete GUI and CLI flows.
4. **Isolation in unit tests.** Hand-written fakes replace file, clipboard,
   preference, update, clock, random, and process collaborators.
5. **Realistic functional tests.** Functional tests use actual parsers,
   algorithms, serialization, routing, commands, and local files while replacing
   network access with deterministic fixtures.
6. **Traceability governs completeness.** Every requirement, business rule, main
   flow, alternative flow, target, and localization path has test evidence. A
   line-coverage percentage does not substitute for this evidence.
7. **No live external dependency.** Automated tests never call GitHub or another
   internet service and never require the production VPS.

---

## 3. Test Categories

| Artifact produced | Test kind | Location |
| --- | --- | --- |
| Pure algorithm, parser, formatter, validator, or generator | Unit | Owning package's `test/` tree |
| Application service and typed result mapping | Unit | `packages/chimera_core/test/` |
| GUI component, route, validation, and localization | Widget | `apps/chimera_gui/test/` |
| CLI command, stdin/stdout, JSON output, file flag, and exit code | Functional | `apps/chimera_cli/test/functional/` |
| Complete browser or desktop use-case flow | Functional/integration | `apps/chimera_gui/integration_test/` |
| Compiled web application in each supported browser | Cross-browser functional | `tests/web/` |
| Built web container and liveness response | Deployment smoke | `tests/deployment/` |
| Native package metadata, checksum, and update transaction | Functional | `tests/update/` |

Plain immutable data holders with no validation, mapping, or behavior do not need
standalone tests. Their construction and serialization are covered through the
behavior that consumes them.

---

## 4. Test Project Layout

```text
apps/
├── chimera_gui/
│   ├── test/
│   │   ├── widgets/
│   │   ├── routes/
│   │   └── localization/
│   └── integration_test/
├── chimera_cli/
│   └── test/
│       ├── commands/
│       └── functional/
packages/
├── chimera_core/test/
├── chimera_utilities/test/
├── chimera_platform/test/
└── chimera_l10n/test/
tests/
├── fixtures/
│   ├── certificates/
│   ├── encoded/
│   ├── structured-data/
│   ├── standards/
│   └── updates/
├── web/
├── deployment/
└── update/
```

Each production path has a mirrored test path. Shared fixtures are immutable,
small, provenance-documented, and contain no real secrets, identities, tokens, or
private data.

---

## 5. Naming & Structure

Every test uses the Given–When–Then naming pattern:

```text
GivenSomeCondition_WhenSomeAction_ThenSomeOutcome
```

Test bodies use Arrange–Act–Assert with one behavioral reason to fail:

```dart
test('GivenInvalidBase_WhenConverting_ThenReturnsValidationFailure', () {
  // Arrange
  final request = numberRequest(sourceBase: 1, targetBase: 10);

  // Act
  final result = converter.convert(request);

  // Assert
  expect(result, isA<ValidationFailure>());
});
```

Parameterized cases may share one test body when each case produces an
individually named result. Snapshot or golden tests supplement behavioral
assertions but do not replace them.

---

## 6. Unit Testing Standard

### 6.1 Scope

A unit test exercises one public behavior of an algorithm, validator, application
service, or adapter. It may use in-memory values and hand-written fakes, but it
shall not access the network, production preferences, the real clipboard, the
real filesystem outside its temporary directory, or a subprocess.

### 6.2 Test Doubles

| Collaborator | Double |
| --- | --- |
| File access | In-memory file gateway or isolated temporary directory |
| Clipboard | In-memory clipboard adapter |
| Preferences | In-memory key/value adapter |
| Release metadata and downloads | Deterministic fake update transport |
| Clock and time zone | Fixed clock and version-controlled time-zone fixtures |
| Random source | Deterministic injectable source plus separate secure-source contract test |
| Process/update installer | Recording fake that returns configured outcomes |

A second mocking framework is not introduced. If a collaborator cannot be
represented by a small fake, its boundary is redesigned before adding a tool.

### 6.3 Coverage Per Unit

Each production behavior covers, as applicable:

- the successful main flow;
- each validation and alternative-flow failure;
- empty, minimum, maximum, boundary, Unicode, and malformed values;
- every supported algorithm, dialect, representation, locale, and option;
- determinism or invariants for generated output;
- standard-derived known-answer fixtures for checksums, ciphers, formats, and
  identity documents;
- redaction and discard behavior for sensitive in-memory values; and
- regression cases for every corrected defect.

---

## 7. Functional Testing Standard

### 7.1 GUI and Browser Scope

Widget and integration tests exercise route selection, form input, file and
clipboard adapters, validation, localized output, save/copy behavior, preference
persistence, keyboard navigation, focus, contrast, accessible labels, and
responsive layout.

The compiled web build runs through the same high-value flows in Chromium,
Firefox, and Safari. Browser tests assert only local processing and fail if a
utility flow makes an unexpected network request.

### 7.2 Desktop Scope

The Windows and Linux GUI matrices exercise supported file operations, clipboard
flows, local preferences, representative utility flows, and the update boundary.
Native permission or installer UI that cannot be controlled by the application
is validated through adapter contract tests and release smoke tests.

### 7.3 CLI Scope

CLI functional tests invoke the executable entry point with arguments, standard
input, and temporary files. Each command asserts:

- human-readable stdout and JSON output;
- stderr contains an actionable diagnostic without sensitive input;
- documented exit code;
- output-file behavior and cleanup; and
- identical core result semantics to the GUI-facing application service.

### 7.4 External Dependencies

GitHub metadata, download streams, failures, slow responses, corrupt artifacts,
and checksum mismatches come from local fakes and fixtures. The web container is
built and run locally for deployment smoke tests. No functional suite uses a live
GitHub API, public website, or production host.

### 7.5 Coverage Per Entry Point

For every use case, functional coverage includes the main flow and each `AF-xx`
that reaches the entry point. It asserts the visible result, typed failure, local
side effect when one is permitted, absence of forbidden persistence or network
activity, and disposal of temporary data.

---

## 8. Per-Use-Case Workflow

1. Read the use case, traced functional requirements, business rules, and
   applicable non-functional requirements.
2. Create a coverage checklist containing the main flow, every `AF-xx`, target
   interfaces, locales, and standards-based boundaries.
3. Add or update failing unit tests before the behavior is implemented.
4. Implement the smallest shared behavior that makes the unit tests pass.
5. Add adapter, widget, CLI, and full-flow tests required by the checklist.
6. Run the narrow suite, then every affected platform suite, then the complete
   repository suite.
7. Record commands and results in the pull request and resolve every failure or
   explicit coverage gap before requesting review.

---

## 9. Running the Suites

```bash
melos run test:all
```

| Suite | Command |
| --- | --- |
| Static analysis | `melos run analyze` |
| Unit and widget tests | `melos run test:unit` |
| CLI functional tests | `melos run test:cli` |
| GUI integration tests | `melos run test:gui` |
| Cross-browser tests | `melos run test:web` |
| Deployment and update smoke tests | `melos run test:deployment` |
| All tests | `melos run test:all` |
| Coverage report | `flutter test --coverage` |

Suite scripts are defined at the repository root and select projects or folders,
so each category can run independently. CI expands GUI, browser, and native
commands into the supported target matrix.

## UC-50 Cleanup Coverage

Native tests create isolated real temporary trees and verify discovery and deletion,
source-file preservation, default `src`, missing/non-directory/traversal roots,
zero no-op, exact `bin`/`obj` selection, no mutation before confirmation, locked
paths through an injected per-entry delete failure, symlink/junction escapes,
artifact replacement after preview, linked roots, and changed scope. Windows
runs create real directory junctions with `mklink /J`; Linux runs create symlinks.
Pure path contracts exercise Windows and Linux separators, exact case, traversal,
and component-prefix collisions on every host. CLI tests cover English/Portuguese,
explicit affirmative/negative answers, `--yes`, invalid/duplicate options, and help.
Widget tests verify scope preview, cancel/confirm, stale preview invalidation, and
an explicitly unsupported target. Windows native execution remains a CI matrix
requirement; a Linux run alone is not evidence of Windows filesystem behavior.
