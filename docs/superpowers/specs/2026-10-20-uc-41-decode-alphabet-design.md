# UC-41 Decode Alphabet Design

## Intent and scope

Decode ephemeral local input expressed as International Morse code, ICAO/NATO
radiotelephony words, or uncontracted Unified English Braille (UEB). One pure
Dart implementation serves the CLI, desktop, and browser adapters. Inputs and
decoded results are never logged, retained as history, or transmitted; adapters
discard source and result state after request construction, replacement,
failure, or disposal.

Empty input is valid. Every non-empty input must be a canonical sequence for
the selected published mapping. Unknown alphabets, malformed Unicode, unknown
tokens or cells, non-canonical separators, and incomplete or contradictory UEB
indicators return a typed validation failure without partial output. A failure
may include only a zero-based Unicode-scalar position, never source content or
partial decoded output.

## Canonical decoding grammar

Every success returns the decoded value plus the same immutable mapping
descriptor exposed by UC-40: stable ID, edition, source URLs, ordered symbol
table, and structural rules. Reference URLs are metadata and are never fetched
during decoding.

- **Morse (`morse`)** accepts the exact dot/dash groups in ITU-R M.1677-1 for
  ASCII `A` through `Z` and digits `0` through `9`. `/` decodes to one ASCII
  space. Tokens on a line are separated by exactly one ASCII space; leading,
  trailing, repeated, empty, or unknown tokens are invalid. CR and LF scalars
  are preserved and delimit token lines. Decoded letters are uppercase.
- **NATO (`nato`)** accepts the ICAO spelling words and digit words represented
  by the published mapping. Matching is ASCII case-insensitive, while decoded
  letters are uppercase and digits are unchanged. `/`, token separation, and
  CR/LF rules match Morse. Misspellings and non-ASCII lookalikes are invalid.
- **Braille (`braille`)** accepts only the Unicode cells emitted by UC-40 plus
  ASCII space and CR/LF. Ordinary letter cells decode lowercase. Dot-six must
  be followed immediately by one letter cell and yields uppercase. Dots-3456
  starts numeric mode and must be followed by an `a` through `j` cell, which
  yields `1` through `0`; further `a` through `j` cells continue the digit run.
  A `k` through `z` cell or capital prefix terminates numeric mode. Dots-56 is
  valid only in numeric mode immediately before an `a` through `j` cell and
  decodes that cell as a lowercase letter, terminating numeric mode. Space and
  line breaks terminate numeric mode. Orphaned, repeated, misplaced, or
  contradictory indicators are invalid at the first offending scalar.

Strict canonical grammar is intentional. It prevents different source strings
from silently collapsing to the same output, makes AF-01 deterministic, and
guarantees that every UC-40 result round-trips through UC-41. Automatic
whitespace repair, fuzzy NATO matching, and Braille contraction interpretation
are outside this use case.

## Shared layers and failures

`AlphabetDecoder` in `chimera_utilities` reuses `AlphabetKind`,
`AlphabetMapping`, and `AlphabetException`. It validates Unicode scalars,
parses the selected grammar, enforces an optional output budget used only by
deterministic resource tests, and returns an immutable
`AlphabetDecodeResult`. Decoder failures use stable alphabet codes with safe
fields, reasons, and optional scalar positions.

`AlphabetDecodeService` in `chimera_core` accepts text or immutable UTF-8
bytes, validates the adapter-level alphabet name, invokes the shared decoder,
and maps failures into redacted `ChimeraResult` values. Invalid UTF-8,
malformed input, resource exhaustion, and unexpected processing errors never
include source material.

CLI adds `chimera alphabet decode` with exactly one of `--input`, `--stdin`, or
`--file`, required `--alphabet`, optional transactional `--output`, and
`--json`. Human output includes decoded text and mapping reference; stable JSON
includes the decoded value, alphabet, complete mapping, and rules. Output files
contain only the decoded text.

GUI adds `/alphabet/decode` with text/file/clipboard input, alphabet selector,
Decode, Copy, and Save, a focusable result region, and exact mapping metadata.
Changing the alphabet invalidates prior output. Generation guards prevent late
service or adapter completions from restoring discarded source or results.

All labels and diagnostics are complete in English and Brazilian Portuguese.
Controls remain keyboard reachable, responsive at 200% text scale, at least 48
logical pixels where actionable, and expose result content, mapping, status,
and errors through assistive semantics on web and native targets.

## Verification and traceability

Unit fixtures cover every mapping entry, canonical separators, CR/LF, NATO case
folding, all valid Braille state transitions, empty input, malformed Unicode,
unknown and ambiguous sequences, exact scalar positions, round-trips from the
UC-40 encoder, output bounds, and immutable mapping metadata.

Service, CLI, widget, native, Playwright, and Safari tests cover all sources,
both locales, human/JSON output, transactional save/copy, AF-01, AF-02,
resource/processing failures, discard, stale completions, accessibility, and
offline operation. This traces FR-CA-06 through FR-CA-08, FR-PL-01 through
FR-PL-06, FR-PL-09 through FR-PL-11, BR-01 through BR-05, BR-15, BR-19, and
issue #42.

## Explicit non-goals

This use case does not add Morse punctuation or procedural signs, alternate
word separators, fuzzy spelling, automatic alphabet detection, contracted or
language-specific Braille, Unicode normalization, transliteration, network
lookups, history, or persistent operation data.
