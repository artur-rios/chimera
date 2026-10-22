# UC-49 design and implementation plan

Approved scope: issue #98 and FR-DW-03; user authorized implementation and tests
without intermediate approval gates. Human review and merge remain required.

Core defines a pure request/result service plus injectable process, discovery,
and cancellation contracts. Platform resolves local files and invokes argument
arrays. CLI and desktop adapt the same service. The web route is present with
an explicit unsupported message. No additional dependency is introduced.

Linux starts each command in its own `setsid` process group and cancellation
kills the group; Windows launches the child suspended via a fixed PowerShell/C# helper, assigns
it to a kill-on-close job, and then resumes it. Child arguments arrive as JSON
and use Windows argv quoting; no actor input is interpreted as shell code.
Closing the job also terminates descendants after their original parent exits. Diagnostics are capped per
process and workflow at 65,536 characters, URLs and common credential fields are redacted,
and oversized unterminated lines are discarded before emission. No command line
or external diagnostic is sent to the application logging sink.

Implementation sequence:

1. Specify default/explicit configuration, discovery, dependency, failure, and
   cancellation contracts in focused tests.
2. Add reusable native process and discovery adapters, including controlled
   subprocess tests for real exit codes, output bounds, redaction, and trees.
3. Add CLI parsing/JSON/status handling and localized desktop form/cancel flow.
4. Extend UC-49 requirements and business rules; verify focused tests/analyzer,
   real temporary solution build, and affected GUI widgets.

Progress: shared service, native adapters, CLI and desktop adapters, EN/PT-BR
messages, focused tests, and UC-49 specifications implemented. Final validation
results are recorded in the pull request; no human merge or issue closure is
authorized by this plan.

Verified locally: 15 focused Dart tests (including real .NET 10 Debug/Release
build and intentional compiler failure), 2 GUI widget tests. Dedicated CI
executes process-tree and real-build contracts on Windows and Linux. Windows
execution and full repository checks remain required before human merge.

Review follow-up: contain Windows children in a job object to cover cancellation
after the original parent exits; add a descendant-survival regression contract.
