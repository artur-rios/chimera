# Open issues implementation plan

## Intent and delivery

Implement GitHub issues #29–#47 (UC-28–UC-46) against the approved requirements.
The user approved implementation and testing without intermediate approval gates,
one pull request per issue, with merges and issue closure left to a human.
Existing specifications in `docs/requirements/` are the design authority.

Each issue branches from current `develop`, targets `develop`, and remains open
for human review. Independent issues branch separately. If an issue needs an
unmerged predecessor, include only its prerequisite commits and identify that
dependency explicitly in its PR. Do not merge, close issues, publish a release,
deploy production, or modify repository protection.

## Common design and verification

Read the target use case, its traced functional requirements, business rules,
Technology Stack, Testing Specification, and relevant Operations sections fresh.
Follow the existing utility → application service → GUI/CLI adapter architecture.
Use typed failures, safe diagnostics, English and Brazilian Portuguese catalogs,
strict input validation, and the existing transactional file output boundary.
Never persist or transmit utility input/output. Preference persistence contains
only theme and language. Update networking is confined to native update adapters.

For each issue: map the main flow and every AF to tests; add failing behavior
tests; implement shared behavior; wire GUI and CLI; add adapter and functional
tests; run focused tests followed by full `melos run test:all`; run formatting,
fatal-info analysis and boundary checks; obtain an independent code review;
fix findings; commit and prepare the issue PR with actual evidence and limitations.
Do not mark README work done before human merge. Native platform checks that
cannot run here must be identified precisely and covered by CI and adapter tests.

## Task 1: UC-28 — URL Encode (#29)

Implement strict full-value/component percent encoding using Dart URI primitives.
Add a URL encoder utility and typed application service, exports, localized GUI
route and home entry, and `chimera url encode` with argument/stdin/UTF-8 file
sources, mode, JSON and transactional output. Test Unicode, delimiters, empty
input, invalid mode/Unicode, unreadable input and output failure, both locales,
copy/save/discard behavior and no network. Mirror HTML Encode adapter patterns.

## Task 2: UC-29 — URL Decode (#30)

Implement strict percent and UTF-8 decoding, preserving literal plus signs unless
an explicit mode specifies form semantics. Share URL infrastructure from Task 1
where necessary. Add utility/service, CLI decode, GUI route, localized messages,
tests for malformed escapes/UTF-8, Unicode, empty text, file/output access and
discard behavior. Verify all main/alternative flows.

## Task 3: UC-30 — Generate Hash (#31)

Implement SHA-256/384/512, MD5 and SHA-1 over text/local bytes with crypto.
Explicitly label MD5/SHA-1 legacy and unsuitable for security decisions. Add
service, GUI and `hash generate`, all source/output adapters and localized errors.
Test standard known digests, binary/empty inputs, invalid algorithms, access and
resource failures, JSON/human output and sensitive-state cleanup.

## Task 4: UC-31 — Generate Checksum (#32)

Implement CRC32 and Adler-32 with standard known-answer vectors and shared byte
input handling. Add typed service, GUI, `checksum generate`, localized diagnostics,
file/stdin/argument and transactional output tests, invalid algorithms and resource
failure coverage. Keep checksum formatting stable and document it.

## Task 5: UC-32 — Generate Lorem Ipsum (#33)

Implement word/sentence/paragraph counts, validated unit/count, explicit resource
failure without partial text. Add service, GUI and `lorem generate`, localization,
copy/save/JSON and count boundary tests, matching requested unit counts exactly.

## Task 6: UC-33 — Generate Password (#34)

Use injectable secure randomness, length and requested character classes; guarantee
every required class, reject impossible constraints, never fall back on insecure
randomness. Add service, GUI and `password generate`, localized errors, invariant,
random-failure, source-discard and output-access tests. No password diagnostics.

## Task 7: UC-34 — Generate UUID or GUID (#35)

Implement v4/v7 and supported UUID/GUID representations using approved uuid
dependency. Inject randomness and clock where needed. Validate version/count and
representation; no partial output on failure. Add service, GUI, `uuid generate`,
locale, version/variant/time/format/uniqueness and output failure tests.

## Task 8: UC-35 — Generate Credit Card (#36)

Generate clearly labeled synthetic Visa/Mastercard/Amex/Discover test-range data,
validate range/length/Luhn internally, bounded replacement on failed validation.
Add service, GUI, `card generate`, network/count validation, deterministic fakes,
generation/output failure tests. Document and source the exact test ranges.

## Task 9: UC-36 — Generate Identity Document (#37)

Implement synthetic SSN/ITIN/EIN/CPF/CNPJ/CNH/CIN/RG with applicable official
structural/checksum rules; use fixtures and source references for each standard.
Validate locale/type/count and disallow ambiguous RG variants without selecting
and documenting the supported jurisdiction. Add service, GUI, `document generate`,
localized synthetic labels, all validators and failure/output tests.

## Task 10: UC-37 — Generate Person (#38)

Generate synthetic US/BR locale-consistent names, birth dates, addresses, phones,
emails and identifiers with validated optional constraints. Consume Task 9's
identifier validators; never return a partial person. Add service, GUI,
`person generate`, synthetic labels, cross-field invariant and failure tests.

## Task 11: UC-38 — Encode with Cipher (#39)

Implement Caesar/ROT, Vigenère, Atbash, Affine, Bacon and Rail Fence with explicit
unsupported-character policy, valid keys/parameters, localized typed errors and
safe diagnostic positions. Add service, GUI, `cipher encode`, published known
answers, all cipher/policy/invalid-key/output cases and discard tests.

## Task 12: UC-39 — Decode with Cipher (#40)

Implement matching decoding for all six ciphers using Task 11 shared definitions,
explicit character policy and strict malformed/ambiguous input handling. Add CLI,
GUI, service, localization, independent known-answer and round-trip tests plus
every alternative flow and output/discard test.

## Task 13: UC-40 — Encode with Alphabet (#41)

Implement Morse, NATO and Braille encoding, expose exact versioned mappings and
source references in results. Validate unsupported symbols with typed errors.
Add service, GUI, `alphabet encode`, localized output and error/copy/save paths,
mapping fixtures, whitespace/case/numeric rules and no-retention tests.

## Task 14: UC-41 — Decode Alphabet (#42)

Decode Task 13 mappings strictly, reject invalid/ambiguous symbol sequences.
Add service, GUI and `alphabet decode`, expose mapping reference, verify all
alphabets, word boundaries, numeric/case rules and file/output access failures.

## Task 15: UC-42 — Change Theme (#43)

Wire light/dark selection to app-level state and injectable shared_preferences
adapter, restoring the stored theme at startup. Invalid values default light;
write failures apply session choice and show localized unsaved status. Test both
themes, restart/invalid/read/write failures and exactly permitted persisted keys.

## Task 16: UC-43 — Change Language (#44)

Wire English/pt-BR choice into app-level localization and preference persistence.
Restore on launch; default English for invalid stored values/missing translations,
emit safe diagnostic and show session-only status on failed saves. Test routes,
catalog fallback, startup, persistence failure and both language UI flows.

## Task 17: UC-44 — Check for Update (#45)

Implement native release metadata transport, version/platform/architecture and
artifact compatibility validation, and check-only service. No artifact download
on check. Add native GUI and `update check`, localized availability/current/failure
states, deterministic network fixtures, malformed/unavailable/release-selection
tests. Keep browser and utility flows network-free; preserve installed version.

## Task 18: UC-45 — Apply Update (#46)

Require explicit acceptance of Task 17 compatible metadata, download to temporary
storage, validate published checksum before invoking injectable native installer,
clean temporary files on every path, preserve/restore installed version. Add
`update apply` and native GUI integration, localized elevation/actionable errors,
fake transport/installer and real temporary-file transaction tests. Never install
or download an actual update as part of implementation tests.

## Task 19: UC-46 — Publish Release (#47)

Read Operations UC-46 and existing Yggdrasil/Jenkins/branch-policy/artifact tooling.
Implement missing release readiness, catalog/check gates, artifact and metadata
validation and health/rollback contracts with deterministic tests and a concrete
operator runbook. Preserve release/x.y.z from exact approved develop commit, human
approval and existing infrastructure boundaries. Prepare the PR; actual release,
deployment, tagging and production publication require a separate operator action.
