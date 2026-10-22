# Business Rules — Chimera

## Domain Entities

Chimera has no persisted domain records. These entities describe values that
exist during an operation or in the small local preference store.

| Entity | Meaning |
| --- | --- |
| **Utility** | A named conversion, encoding, decoding, formatting, comparison, analysis, or generation capability. |
| **Operation request** | The input values and options supplied to one utility invocation. |
| **Operation result** | The output or validation error produced by an operation request. |
| **User preference** | The locally stored theme or interface-language selection. |
| **Synthetic person** | A generated US or Brazilian test identity with internally consistent personal fields. |
| **Synthetic identifier** | A generated test identifier or payment-card number that follows the applicable structural and checksum rules. |
| **Release artifact** | A portable package or installer for a supported desktop or CLI platform. |

## Relationships

| Relationship | Cardinality and meaning |
| --- | --- |
| Utility → operation request | One utility accepts zero or more requests over time; requests are not retained after processing. |
| Operation request → operation result | One request produces one result: either output or a validation error. |
| Synthetic person → synthetic identifier | One synthetic person may contain multiple identifiers appropriate to its US or Brazilian locale. |
| Local installation → user preference | One installation stores at most one current value for each supported preference. |
| Supported platform → release artifact | Each desktop and CLI platform may have both a portable artifact and an installer artifact. |

## Rules

| ID | Rule | Rationale |
| --- | --- | --- |
| BR-01 | Every capability listed in `Brainstorm.md` is required. | The initial scope is the complete toolbox rather than a partial feature subset. |
| BR-02 | Utility behavior and results shall be consistent across web, desktop, and CLI surfaces where a visual interaction is not intrinsically required. | A shared toolbox should not produce platform-dependent results. |
| BR-03 | Every utility shall perform its work locally and remain functional offline. | Developer input must remain private and tools must remain available without a service dependency. |
| BR-04 | Utility inputs and outputs shall never be sent off the user's device. | Local processing is a product boundary, not merely a performance optimization. |
| BR-05 | Chimera shall not retain utility inputs, outputs, or operation history. | Utility processing is stateless. |
| BR-06 | Only theme and interface-language preferences may persist locally. | These preferences improve usability without creating stored domain data. |
| BR-07 | English and Brazilian Portuguese shall be supported, and English shall be the default language. | These are the approved interface locales and default. |
| BR-08 | The web application shall support Chromium, Firefox, and Safari. | These are the approved browser targets. |
| BR-09 | Desktop and CLI applications shall support Windows and Linux. | These are the approved native platforms for the initial scope. |
| BR-10 | Generated people, payment cards, and identity documents shall be synthetic test data rather than representations of known real people or accounts. | The generators exist for safe development and testing. |
| BR-11 | Generated identifiers shall satisfy every applicable official structural and checksum rule. | Test data must be valid enough to exercise validation logic. |
| BR-12 | The US document baseline shall include SSN, ITIN, and EIN; the Brazilian baseline shall include CPF, CNPJ, CNH, and CIN/RG. | This defines the otherwise ambiguous document-generator scope. |
| BR-13 | The person generator shall support US and Brazilian locales and generate names, birth dates, addresses, phone numbers, email addresses, and matching identifiers. | A generated person must be useful as internally consistent test data. |
| BR-14 | The cipher baseline shall include Caesar/ROT, Vigenère, Atbash, Affine, Bacon, and Rail Fence. | This defines the approved common-cipher scope. |
| BR-15 | The alphabet baseline shall include Morse code, the NATO phonetic alphabet, and Braille. | This defines the approved common-alphabet scope. |
| BR-16 | Desktop and CLI releases shall be available from GitHub as portable downloads and installers. | Users need both no-install and installed distribution options. |
| BR-17 | Installed desktop and CLI applications shall check for updates, ask the user before applying one, and apply an accepted update without a manual package download. | Installed distributions must have a guided update path controlled by the user. |
| BR-18 | Every utility shall have unit and functional test coverage. | Completeness, reliability, and cross-surface behavior must be verified. |
| BR-19 | Chimera shall provide no user accounts, cloud sync, plugins, mobile applications, or collaboration features. | These capabilities are explicitly outside the product boundary. |

## Validation Constraints

| Value | Constraints |
| --- | --- |
| Utility selection | Must identify one supported utility and one operation that utility exposes. |
| Operation input | Required inputs must be present and valid for the selected format, algorithm, or standard. Chimera imposes no product-specific size limit beyond platform resource constraints. |
| Theme preference | Must be either light or dark. |
| Language preference | Must be either English or Brazilian Portuguese; absent values resolve to English. |
| Synthetic person locale | Must be either US or Brazil, and every locale-dependent field must use that locale's conventions. |
| US identifier type | Must be SSN, ITIN, or EIN and satisfy the applicable official structural rules. |
| Brazilian identifier type | Must be CPF, CNPJ, CNH, or CIN/RG and satisfy the applicable official structural and checksum rules. |
| Payment-card number | Must be synthetic and satisfy the applicable checksum rules. |
| Cipher | Must be Caesar/ROT, Vigenère, Atbash, Affine, Bacon, or Rail Fence; required keys or parameters depend on the selected cipher. |
| Alphabet | Must be Morse code, the NATO phonetic alphabet, or Braille. |
| Release platform | Must be Windows or Linux for desktop and CLI artifacts. |

## UC-48 Periodic Command Rules

| ID | Rule | Rationale |
| --- | --- | --- |
| BR-DW-02 | Periodic commands run only inside a supported Windows native console created and owned by their operation. Missing or invalid positive signed 32-bit decimal intervals use 20 seconds. Startup waits 1 second before activation, 15 seconds initially, then one interval before every fixed `echo Hello World <n>` command, starting at 1. Verify ownership and foreground in the native send operation; stop on failure or focus loss. Cancellation removes timers and awaits owned helper/console cleanup. Linux and web return typed unsupported results. Never use global keystrokes, arbitrary command text, external services, or retained raw diagnostics. | Preserves the pinned ktype behavior while ensuring input cannot reach unrelated applications. |

## Permissions

There are no roles or permission tiers. The local user may invoke every installed
utility and change the two local preferences. Update installation occurs only
after that user accepts the update prompt.

## Lifecycle

1. A user or local script selects a utility and supplies an operation request.
2. Chimera validates the request and either returns a validation error or
   processes it locally.
3. Chimera returns the result to the calling interface.
4. Request and result data are discarded after the operation; no history is
   created.
5. Theme and language preferences remain in local storage until changed, reset,
   or removed with the application data.
6. An installed desktop or CLI application may detect a release, prompt the
   user, and download and apply it only after acceptance.

## Prohibitions

- Do not transmit utility input or output to the web host, GitHub, analytics,
  telemetry, or any other remote service.
- Do not store utility input, output, or operation history.
- Do not represent generated people, documents, or payment cards as belonging to
  real people or accounts.
- Do not add user accounts, authentication, cloud sync, plugins, mobile targets,
  or collaboration features within the approved scope.
- Do not apply a desktop or CLI update without first obtaining the user's
  confirmation.

## Developer workflow rules

- BR-DW-01: Templates are pinned offline snapshots. Template paths are relative, may not traverse or contain Git metadata, and all content is validated before writing. A scaffold never overwrites an existing path. Only output created and still owned by the current invocation may be removed on failure.


## .NET Solution Builds (UC-49)

- Default to `./src`, one top-level `.sln`, restore enabled, and Debug then Release.
  Explicit solutions must resolve within the selected root. Reject ambiguous
  discovery and invalid configurations before external build commands.
- Verify an installed .NET SDK before restoring or building. Stop on the first
  failed command and preserve its exit status and bounded, redacted diagnostics.
- Execute argument arrays without a shell. Cancellation terminates the owned
  process tree and prevents subsequent commands. Do not persist command output.
- CLI and Windows/Linux desktop share the service; web explicitly cannot build.
  Restore may contact the actor's configured NuGet sources as part of the
  explicitly requested native build workflow.

## UC-50 Cleanup Safety

| ID | Rule | Rationale |
| --- | --- | --- |
| BR-DW-04 | Cleanup operates only beneath one explicit resolved source root. Only exact `bin` and `obj` directory names qualify. Never traverse links or junctions, accept traversal/case aliases, delete the selected root itself, or expand scope after preview. Require explicit confirmation; `--yes` supplies it only for the current CLI invocation. Revalidate each entry before nonrecursive deletion, retain unsafe or inaccessible artifacts, and report actual removals. Empty discovery succeeds. | Destructive native actions require a visible, bounded and reviewable scope. |

## .NET Tests and Coverage (UC-51)

- Discover `.csproj` files recursively, excluding Setup fixtures regardless of
  case, generated output directories, and linked trees. No projects is a
  successful no-op without external tools or cleanup.
- Default outputs are `tests/TestResults` and `docs/coverage-report`; an explicit
  base stores both beneath itself. Prove both resolved output paths are within
  the selected project scope before deleting old contents; reject output links.
- Check SDK and ReportGenerator before cleanup. Verify new JSON, LCOV, and
  Cobertura artifacts after each project to detect missing XPlat collectors.
- Stop on the first failed test/report command. Retain artifacts and bounded,
  redacted diagnostics, and terminate owned process trees on cancellation.
  Desktop and CLI use the same service; web cannot execute local .NET tools.

## UC-52 Project Version Transactions

| ID | Rule | Rationale |
| --- | --- | --- |
| BR-DW-06 | Version changes accept one numeric MAJOR.MINOR.PATCH value or one major/minor/patch increment; incrementing resets lower components and requires a valid existing value. Discovery is nonrecursive and unambiguous. Preserve unrelated project bytes and supported encoding. Verify an exclusive backup before replacement and the complete updated bytes before removing the backup. Failed transactions always report the retained recovery path; no parse/validation failure creates a backup. | Project metadata edits must remain local, precise and recoverable. |

- BR-DW-07: Release tags are annotated, never forced or overwritten. Push is opt-in and sends one fully-qualified tag refspec with configured tag-following and submodule pushes explicitly disabled; cancellation or failed remote acknowledgement preserves and reports the local tag and an unconfirmed remote outcome. Tag discovery recursively scans the selected source scope without following links; explicit project files resolve ambiguity.

- BR-DW-08: NuGet library generation accepts either complete source-compatible fields or one explicit JSON document, validates field-level metadata before any write, preserves source capabilities and attribution using versioned offline templates, and delegates native writes/rollback to the shared scaffold service. Generation performs no dependency restore, build, Git initialization, publication, or network request; web returns typed unsupported.

## BR-DW-09 — Minimal .NET Library Repositories (UC-55)

- Require `RootFolder`, `SolutionName`, `ProjectName`, `Author`, and `Description`
  through fields/flags or one JSON file, never mixed modes. Return stable field
  identifiers for invalid data without logging supplied values.
- Use the pinned offline templates and retain original license attribution.
  Generate one minimal .NET 10 library below `src/<ProjectName>`, its solution,
  configuration and READMEs, plus empty docs/tests placeholders. Intentionally
  omit NuGet metadata and any generated test project.
- Reuse the shared transactional scaffold service/writer: reserve a new
  destination exclusively, verify file content, never overwrite an existing
  destination, and remove owned partial output on failure when safe.
- Desktop and CLI share validation/rendering/writing; web explicitly reports
  unsupported. Report every created file and the template version. SDK-backed
  Windows/Linux golden/build checks validate templates without requiring an
  installed SDK or network for the scaffold operation itself.

- BR-DW-10: Single-project scaffolding defaults to minimal; explicit minimal and NuGet modes are mutually exclusive. NuGet project scaffolds retain all metadata elements with empty values. Project names cannot be paths or reserved device names.
