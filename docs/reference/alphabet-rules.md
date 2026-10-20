# Representation alphabet rules

Chimera's alphabet operations are local, ephemeral, and strict. Every operation
uses one immutable mapping descriptor containing a stable ID, edition, source
URLs, ordered symbol table, and structural rules. Static source URLs identify the
published mapping; Chimera never fetches them while encoding or decoding.

All three alphabets accept ASCII letters, digits, ASCII space, and CR/LF line
breaks. Empty input is valid. Tabs, punctuation, accented letters, emoji, and all
other Unicode scalars are unsupported. A typed failure reports only the
zero-based Unicode-scalar position, never the rejected symbol or partial output.

## International Morse code

- Mapping ID: `itu-r-m.1677-1`
- Edition: `10/2009`
- Source: [ITU-R Recommendation M.1677-1](https://www.itu.int/rec/R-REC-M.1677-1-200910-I/en)

Letters use the international A-Z dot/dash groups and are case-insensitive.
Digits use the recommendation's figure groups. Adjacent source symbols become
tokens separated by one ASCII space; each source space becomes a `/` token. CR
and LF scalars are preserved without extra separators. Chimera intentionally
does not include punctuation or procedural signs in this baseline.

Decoding accepts only the exact published dot/dash tokens and `/`. Tokens on a
line must be separated by exactly one ASCII space, with no leading or trailing
separator. Empty lines are valid, and decoded letters are uppercase.

## ICAO/NATO radiotelephony spelling alphabet

- Mapping ID: `icao-radiotelephony-spelling-alphabet`
- Edition: `1956`
- Source: [ICAO Annex 10 spelling-alphabet history and official forms](https://www.icao.int/sites/default/files/postalhistory/annex_10_aeronautical_telecommunications.htm)

Letters are case-insensitive and use the official code words, including `Alfa`
and `Juliett`. Digits use the ICAO radiotelephony forms `Zero`, `Wun`, `Too`,
`Tree`, `Fower`, `Fife`, `Six`, `Seven`, `Ait`, and `Niner`. Token and whitespace
rules match the Morse representation.

Decoding matches the published words with ASCII-only case folding. It does not
apply Unicode case conversion, fuzzy spelling, aliases, or pronunciation-based
matching. Decoded letters are uppercase.

## Unified English Braille

- Mapping ID: `ueb-uncontracted-unicode`
- Edition: `third-edition-2024`
- Sources: [Rules of Unified English Braille, Third Edition 2024](https://iceb.org/wp-content/uploads/2025/10/Rules-of-Unified-English-Braille-2024.pdf) and [Unicode Braille Patterns](https://www.unicode.org/charts/PDF/U2800.pdf)

Chimera emits uncontracted six-dot UEB as Unicode Braille Pattern characters.
Lowercase letters use their ordinary cells. Each uppercase letter has a dot-six
capital prefix. Each contiguous digit run begins with the dots-3456 numeric
prefix and uses the `a` through `j` cells for `1` through `0`. A lowercase `a`
through `j` immediately following a digit run in the same word has the dots-56
grade-1 symbol prefix; other letters or a capital prefix already terminate
numeric mode. ASCII spaces and CR/LF line breaks are preserved.

Decoding accepts only the cells and indicators emitted by this encoder. A
capital indicator must be followed immediately by a letter cell. A numeric
indicator must be followed by an `a` through `j` cell; those cells remain
digits until a space, line break, capital indicator, grade-1 sequence, or
`k` through `z` cell ends numeric mode. The grade-1 indicator is valid only in
numeric mode and must be followed by an `a` through `j` cell. Orphaned,
repeated, misplaced, and contradictory indicators are rejected.

The complete ordered tables are exposed by every successful application result
and stable JSON response. UC-41 uses these same definitions for strict decoding.
