# UC-37 Generate Person Design

## Scope and safety boundary

Generate ephemeral, clearly labeled synthetic people for the United States and
Brazil through one shared implementation. Every person contains a locale,
given and family names, birth date, structured address, phone, email, and
matching identity documents. The result is test data, not a real identity,
proof of residence, or proof of document issuance. Human, JSON, GUI, copy, and
saved output always include that warning.

The generator combines small locale-specific name and location fixtures; it
does not copy a known person's record or query any register. Email addresses
use IANA's reserved `example.com` domain. US phone numbers use NANPA's reserved
fictional `555-0100` through `555-0199` line-number range. Brazilian mobile
numbers follow Anatel's `+55`, two-digit DDD, and `9XXXX-XXXX` structure and are
explicitly labeled synthetic; Chimera does not assert that a generated
Brazilian number is unassigned.

## Shared model, constraints, and consistency

`PersonGenerator` owns generation and independent validation. `PersonLocale`
is `us` or `br`. A request accepts optional inclusive `minAge` and `maxAge`
constraints, defaulting to 18 and 90, plus a positive count. Ages from 0 through
130 are accepted when `minAge <= maxAge`; calculations use a single injected
calendar date so leap-day and birthday boundaries are stable and testable.

Each generated person is validated as one aggregate before it enters the
result batch:

- names are non-blank and selected from the requested locale's fixture set;
- the birth date satisfies the requested ages on the operation date;
- city, region, postal code, country, and phone DDD/area code come from one
  locale-specific location fixture;
- the email local part is derived from that person's names and ends in
  `@example.com`;
- a US person carries one structurally valid synthetic SSN;
- a Brazilian person carries CPF and CIN entries with the same CPF-based
  registration number, both accepted by the UC-36 document validator; and
- every model and collection returned to callers is immutable and marked
  synthetic.

Generation is atomic. An injected candidate source makes consistency failures
testable. Invalid candidates are retried at most 32 times per person; exhaustion
returns one typed processing failure and no partial batch. Candidate-source
failures are redacted, and allocation failures become resource failures.

## Adapters and lifecycle

Core maps raw locale, age bounds, and count through `PersonService` into typed,
redacted `ChimeraResult` outcomes. CLI adds
`chimera person generate [--locale=<us|br>] [--min-age=<n>]
[--max-age=<n>] [--count=<n>] [--output=<path>] [--json]`. GUI adds
`/person/generate` with locale, minimum age, maximum age, count, Generate, Copy,
and Save controls.

Adapters call only the shared service. Configuration changes invalidate prior
results and notices. Pending generation/copy/save completions are ignored after
configuration changes or disposal. Output-file writes remain transactional;
diagnostics never contain generated fields or dependency text. All new copy is
localized in English and Brazilian Portuguese, keyboard reachable, responsive,
and represented by explicit result/error semantics.

## Verification and traceability

Main-flow coverage includes both locales, age-boundary dates, locale-coherent
addresses and phones, reserved email/US phone values, matching documents,
multi-person batches, visible synthetic warnings, exact copy/save, and discard.
AF-01 covers locale, age syntax/range/order, count, and stray-option validation.
AF-02 covers rejected-candidate replacement, source failure, and bounded
exhaustion at utility, core, CLI, widget, native, and browser boundaries without
partial output.

Tests cover FR-GE-09 through FR-GE-13, FR-PL-01 through FR-PL-06, FR-PL-09
through FR-PL-11, BR-01 through BR-05, BR-10 through BR-13, and BR-19. Full-flow
evidence spans Windows/Linux native contracts, Chromium/Firefox/WebKit/Safari,
both interface locales, accessibility, offline behavior, and unexpected-network
detection.
