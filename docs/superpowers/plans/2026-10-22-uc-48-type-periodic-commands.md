# UC-48 Type Periodic Commands Implementation Plan

> Execute inline, following test-driven development. The user approved the M08 batch without intermediate approval gates. Human review and merge remain mandatory.

**Goal:** Safely type sequential fixed echo commands into Chimera's own Windows console until stopped.

**Architecture:** A pure-Dart shared service owns interval normalization, timing, cancellation, typed results, and redacted diagnostics. An injectable terminal boundary is unsupported by default. The native adapter runs a fixed PowerShell/Win32 helper that launches and attaches only to its own cmd process, captures its console input handle, and checks live process, console membership, console window, and foreground immediately before each scoped input write. No global SendKeys. A kill-on-close job contains the child. Desktop and CLI use the same service.

**Tech Stack:** Existing Dart/Flutter packages; Windows PowerShell and Win32, no new libraries.

**Spec:** GitHub issue #97; pinned cli-utils 3f0c9a9a95ba9ef9d424377b10c94ca340feb0ff commands/ktype.ps1.

## Constraints and decisions

- Interval defaults to 20 for missing, nonnumeric, nonpositive, or outside signed 32-bit integer input, matching the source's integer parse.
- Wait 1 second after launch, activate, wait 15 seconds, then wait the effective interval before first echo. Subsequent commands wait the interval.
- Foreground loss, exit, launch failure, activation failure, input failure, or cleanup failure stops the operation; failures expose fixed codes only.
- Linux and web return a typed unsupported result without launching anything.
- Cancellation interrupts timers; adapter calls are bounded and cleanup is awaited. Closing the GUI page cancels its operation.
- No arbitrary user text becomes a command or script.

## Tasks

- [x] Write deterministic service tests for intervals, exact delay order, suffixes, cancellation at each delay, failures, and cleanup; observe failure, then implement.
- [x] Test adapter protocol and unsupported target behavior; implement the Windows owned-console adapter with bounded replies and cleanup.
- [x] Write CLI tests and widget tests for unsupported result and start/stop lifecycle; wire command, route, home action, and EN/PT messages.
- [x] Extend UC-48 requirements, business rules, source traceability and README backlog.
- [x] Run focused tests and analysis; root runs the entire batch suite. Review diff, ledger evidence, commit; no push/PR until root verification.

## Review focus

Foreground changes cannot redirect a scoped console handle. Modern terminal hosts with no activatable owned console fail closed. Cancellation before launch does no work. Concurrent start attempts never share a child. Protocol errors and host errors reveal no paths, text, or raw exceptions.
