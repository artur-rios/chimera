# UC-40 Encode with Alphabet Design

## Intent and scope

Encode ephemeral local text with one of the approved representation alphabets:
International Morse code, the ICAO/NATO radiotelephony spelling alphabet, or
uncontracted Unified English Braille (UEB). One shared Dart implementation serves
the CLI, desktop, and browser adapters. Input and output are never logged, stored
as history, or transmitted; adapters discard source and result state after use,
replacement, failure, or disposal.

Empty text is valid. Every other input scalar must belong to the selected
alphabet's documented symbol set. Unknown alphabets, malformed Unicode, or an
unsupported symbol return a typed validation failure without partial output. A
symbol failure includes only its zero-based Unicode-scalar position, never the
symbol or surrounding text.

## Published mappings and text rules

Each successful result includes the encoded value plus an immutable mapping
descriptor containing a stable ID, edition, source URLs, ordered symbol table,
and structural rules. The same descriptor is exposed in GUI output, human CLI
output, and stable JSON. Static source URLs are reference metadata only and are
never fetched during an operation.

- **Morse (`morse`)** uses ITU-R Recommendation M.1677-1 (10/2009). ASCII
  letters are case-insensitive and map to their international dot/dash groups.
  Digits `0` through `9` use the recommendation's figure groups.
- **NATO (`nato`)** uses the ICAO International Radiotelephony Spelling
  Alphabet implemented in 1956. ASCII letters are case-insensitive and use the
  official `Alfa` and `Juliett` spellings. Digits use the documented
  radiotelephony words `Zero`, `Wun`, `Too`, `Tree`, `Fower`, `Fife`, `Six`,
  `Seven`, `Ait`, and `Niner`.
- **Braille (`braille`)** uses uncontracted UEB, Third Edition 2024, rendered as
  Unicode Braille Patterns. Lowercase ASCII letters use their six-dot cells;
  each uppercase letter has the dot-six capital prefix. A contiguous digit run
  has one dots-3456 numeric prefix and uses the `a` through `j` cells for `1`
  through `0`. A following lowercase `a` through `j` in the same word receives
  the dots-56 grade-1 symbol prefix so decoding remains unambiguous; other
  letter cells or a capital prefix already terminate numeric mode.

ASCII space and CR/LF line breaks are supported by every alphabet. Morse and
NATO emit one `/` token for each space, separate adjacent source symbols with
one ASCII space, and preserve line-break scalars without adding phantom tokens.
Braille preserves ASCII spaces and line breaks. Tabs, punctuation, accented
letters, emoji, and all other scalars are rejected at their scalar position.
Morse and NATO intentionally do not preserve letter case; Braille does.

The normative references recorded in the mapping descriptors are:

- `https://www.itu.int/rec/R-REC-M.1677-1-200910-I/en`
- `https://www.icao.int/sites/default/files/postalhistory/annex_10_aeronautical_telecommunications.htm`
- `https://iceb.org/wp-content/uploads/2025/10/Rules-of-Unified-English-Braille-2024.pdf`
- `https://www.unicode.org/charts/PDF/U2800.pdf`

## Shared layers and failures

`AlphabetCodec` definitions in `chimera_utilities` own alphabet selection,
versioned mapping metadata, and redacted failures. `AlphabetEncoder` validates
Unicode scalars, applies the selected pure mapping, enforces an optional output
budget used only by deterministic resource tests, and returns an immutable
`AlphabetEncodeResult`.

`AlphabetEncodeService` in `chimera_core` maps text or immutable UTF-8 bytes into
the utility request and returns a `ChimeraResult`. Invalid UTF-8, unknown
alphabets, unsupported symbols, resource exhaustion, and unexpected processing
failures are mapped to stable codes and localized message keys without input or
output data.

CLI adds `chimera alphabet encode` with exactly one of `--input`, `--stdin`, or
`--file`, a required `--alphabet`, optional transactional `--output`, and
`--json`. Human output includes both the encoded value and mapping reference;
JSON additionally includes the complete ordered mapping and rules. Output files
contain only the encoded value while stdout confirms the save and identifies the
mapping.

GUI adds `/alphabet/encode` with text/file/clipboard input, an alphabet selector,
Encode, Copy, and Save actions, a result region, and an accessible mapping region.
Changing the alphabet invalidates prior output. Source values are cleared as soon
as the immutable request is constructed, and generation guards prevent stale
async completions from restoring discarded data.

All labels and diagnostics are complete in English and Brazilian Portuguese.
Controls remain keyboard reachable, responsive at 200% text scale, at least 48
logical pixels where actionable, and expose result, mapping, status, and error
semantics for assistive technology.

## Verification and traceability

Standard-derived fixtures cover every letter, every digit, separators, line
breaks, case behavior, numeric runs, Braille ambiguity guards, empty input,
malformed Unicode, unsupported BMP and supplementary scalars, scalar positions,
and bounded output. Mapping tests assert stable IDs, editions, sources, tables,
rules, immutability, and representative official known answers.

Service, CLI, widget, native, Playwright, and Safari tests cover all sources,
both locales, human/JSON output, transactional save/copy, invalid options,
input/output access failures, resource/processing failures, discard, stale
completions, accessibility, and offline operation. This traces FR-CA-05,
FR-CA-07 through FR-CA-08, FR-PL-01 through FR-PL-06, FR-PL-09 through
FR-PL-11, BR-01 through BR-05, BR-15, BR-19, and issue #41.

## Explicit non-goals

This use case does not add contracted Braille, language-specific Braille beyond
UEB, Morse punctuation or procedural signs, custom mappings, transliteration,
automatic alphabet detection, sound generation, network lookups, history, or
persistent operation data. Strict decoding is delivered separately by UC-41.
