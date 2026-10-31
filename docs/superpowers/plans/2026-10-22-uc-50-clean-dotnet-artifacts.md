# UC-50 Clean .NET Build Artifacts Plan

User approved implementation and testing without intermediate gates; human review
and merge remain required. Branch: `feature/uc-50-clean-dotnet-artifacts`.

1. Write failing real temporary-tree tests for discovery, confirmation, safe
   deletion, zero results, invalid roots, locked artifacts, escaping links and
   changed directories. Include Windows/Linux path contracts and real Windows
   junction fixtures.
2. Implement pure core orchestration and the injected native filesystem gateway.
   Revalidate canonical scope and ancestors at deletion; avoid recursive deletion.
3. Write failing CLI tests, add independent `dotnet clean` dispatch, strict option
   parsing, exact scope output, explicit interactive confirmation and `--yes`.
4. Write failing widget tests; implement desktop preview/dialog, invalidate stale
   selection and expose an unsupported web state through conditional imports.
5. Complete EN/PT catalog entries, UC-50 requirements, rules, traceability and
   coverage. Run focused tests, analysis, boundary and formatting checks. Root
   coordinator runs the full suite; report Windows/hostile-race limitations.
6. Commit the complete independent change for root review; do not push, open or
   merge a pull request until the coordinator verifies the result.
