# UC-36 Generate Identity Document Design

## Scope and safety boundary

Generate ephemeral, clearly labeled synthetic identity-document values for the
United States and Brazil through one shared implementation. The supported US
types are SSN, ITIN, and EIN. The supported Brazilian types are CPF, CNPJ, CNH,
and CIN. A legacy `rg` request is rejected with a typed jurisdiction-required
failure because RG structure is state-specific; Chimera selects the current
national CIN standard instead, whose registration number is the CPF.

The result is test data, not proof of issuance or an identity. Human, JSON, GUI,
copy, and saved output always include that warning. Generators never query a
government register or transmit values. SSN production uses the SSA-published
specimen number rather than an arbitrary assignable range. Alphanumeric CNPJ
production uses locally bundled fictitious examples from Receita Federal's
official simulator. Other types are generated from secure local random bases,
validated structurally, and labeled synthetic; they are not asserted to be
unassigned.

## Shared model and validation

`IdentityDocumentGenerator` owns generation, formatting, and independent
validation. `IdentityLocale` is `us` or `br`; `IdentityDocumentType` is `ssn`,
`itin`, `ein`, `cpf`, `cnpj`, `cnh`, or `cin`; and `CnpjFormat` is `numeric` or
`alphanumeric`, defaulting to the current alphanumeric format. Locale/type
mismatches and `rg` are rejected before candidate generation. Count is a
positive decimal integer with no product-specific maximum.

Every requested value is generated atomically. A candidate is accepted only
after the applicable independent validator succeeds. Invalid injected
candidates are retried at most 32 times per value; exhaustion returns one typed
processing failure and no partial batch. Allocation failures become resource
failures. Results are immutable and contain locale, type, CNPJ format when
applicable, `synthetic: true`, `label: synthetic-test-data`, and values.

Validation follows the primary-source rules documented in
`docs/reference/identity-document-rules.md`: SSA SSN exclusions; IRS ITIN ranges
and EIN prefixes; Receita Federal CPF and numeric/alphanumeric CNPJ modulus-11
rules; the current CONTRAN CNH 9-character plus 2-check-digit structure; and the
federal CIN/CPF identity rule. Canonical human values use official punctuation;
JSON carries the same exact strings.

## Adapters and lifecycle

Core maps raw locale, type, CNPJ format, and count through
`IdentityDocumentService` into typed, redacted `ChimeraResult` outcomes. CLI
adds `chimera document generate --locale=<us|br> --type=<...>
[--cnpj-format=<numeric|alphanumeric>] [--count=<n>] [--output=<path>]
[--json]`. GUI adds `/document/generate` with compatible locale/type selectors,
CNPJ format control, count, Generate, Copy, and Save.

Adapters call only the shared service. Configuration changes invalidate prior
results and notices. Pending generation/copy/save completions are ignored after
configuration changes or disposal. Output-file writes remain transactional;
diagnostics never contain candidate values or dependency text. All new copy is
localized in English and Brazilian Portuguese, keyboard reachable, responsive,
and represented by explicit result/error semantics.

## Verification and traceability

Main flow covers every supported type, both CNPJ formats, count batches,
canonical formatting, visible synthetic warning, exact copy/save, and discard.
AF-01 covers locale, type, mismatch, RG ambiguity, CNPJ-format applicability,
and count validation. AF-02 covers rejected-candidate replacement and bounded
exhaustion at utility, CLI, widget, native, and browser boundaries without
partial output. Unit fixtures include primary-source known answers and every
checksum mutation. Full-flow tests cover Windows/Linux-native contracts,
Chromium/Firefox/WebKit/Safari, both locales, accessibility, offline behavior,
and unexpected-network detection.

