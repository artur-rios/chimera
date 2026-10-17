# UC-07 Format SQL Design

## Scope

UC-07 formats SQL locally for PostgreSQL, MySQL, SQL Server, and SQLite through
the shared library, CLI, browser, and desktop interfaces. Inputs and results are
ephemeral and never leave the device.

## Decisions

- Implement a project-owned, bounded SQL tokenizer and formatter in
  `chimera_utilities`, as required by the technology stack.
- Require one of four stable dialect identifiers: `postgresql`, `mysql`,
  `sqlserver`, or `sqlite`.
- Expose 2- or 4-space indentation and `upper`, `lower`, or `preserve` case for
  recognized structural and common DDL keywords. Preserve identifiers,
  literals, comments, and parameter lexemes.
- Recognize common SQL statement structure without rewriting semantics. Major
  clauses begin on new lines; nested parentheses indent deterministically;
  commas split select lists, value lists, assignments, and ordering/grouping
  lists at their current nesting level.
- Apply dialect-aware lexical rules for quoted identifiers, parameters,
  comments, PostgreSQL dollar-quoted strings, and SQL Server bracketed names.
- Reject empty input, unsupported dialect/options, unterminated literals or
  comments, unbalanced parentheses, and unsupported leading statements with a
  typed code, offset, and source-redacted reason.
- Enforce source, token, nesting-depth, and output limits while tokenizing and
  emitting. A failure never returns partial formatted SQL.
- Map typed failures in `chimera_core`; keep CLI and GUI responsible for local
  file/clipboard access, localization, and presentation only.

## Interfaces

- CLI: `chimera sql format`, with `--input`/stdin/`--file`, `--dialect`,
  `--indent`, `--keyword-case`, `--output`, and `--json`.
- GUI: `/sql/format`, with typed/pasted, clipboard, or local-file SQL; dialect,
  indentation, and keyword-case controls; accessible preview, copy, and save.
- Stable JSON output reports formatted SQL and the selected options.

## Failure contract

- Invalid SQL, dialect, or options: validation failure (exit 64), with offset
  and a source-redacted reason where the SQL structure is invalid.
- Input, clipboard, or output access failure: access failure (exit 74), without
  echoing the SQL or formatted result.
- Source, token, depth, or output budget exceeded: resource failure (exit 75),
  without a partial result.

## Verification

Tests cover all four dialects, keyword-case and indentation options, literals,
comments, quoted identifiers, parameters, nested queries, invalid structure,
resource budgets, CLI input/output modes, clipboard and local-file flows,
English and Brazilian Portuguese, accessibility, responsive GUI behavior,
native integration, compiled Chromium/Firefox/WebKit, and native Safari smoke.
