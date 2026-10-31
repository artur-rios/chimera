# UC-52 Bump .NET Project Version Plan

User approved implementation/testing without intermediate gates. Work is isolated
on `feature/uc-52-bump-dotnet-version` from develop. Human review/merge is required.

1. Write failing pure editor tests for numeric versions/reset rules, XML source
   preservation, insertion, malformed/ambiguous documents and UTF-8/UTF-16.
2. Implement parser-validated source-span editing in utilities. Keep core free of
   filesystem imports and expose a reusable version reader for UC-53.
3. Write failing core/native transaction tests. Implement nonrecursive discovery,
   exclusive verified backups, staged replacement, complete reread verification,
   rollback and retained recovery paths. Preserve observed concurrent source edits.
4. Commit reusable foundation after focused verification so UC-53 can depend on it.
5. Write failing CLI/widget tests, add independent runner dispatch and desktop
   route, mode fields, localized reports and explicit unsupported web state.
6. Add EN/PT catalog parity, UC-52 requirements, rules, source traceability and
   coverage. Run focused tests/analyzer/boundaries/format; coordinator runs full
   repository, native and browser validation serially.
7. Commit adapters/docs and report SHAs/evidence. Do not push, open or merge a PR
   before coordinator verification. Windows filesystem execution awaits CI.
