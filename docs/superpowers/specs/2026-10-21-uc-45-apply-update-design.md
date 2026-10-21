# UC-45 Apply Update Design

## Intent

Implement GitHub issue #46 so installed Windows and Linux desktop/CLI builds can
download, verify, and invoke installation of a compatible update only after the
user explicitly accepts it. Every failure remains a typed update failure, removes
staging data, and leaves the installed application as the usable version.

## Scope

- Add a shared update-apply orchestration service behind injected staging,
  download, checksum, and installer boundaries.
- Add bounded native HTTP download, temporary-directory, streamed SHA-256, and
  Windows/Linux installer adapters. Windows transfers the verified per-user
  Inno installer to a detached PowerShell helper that waits for the current
  process to exit, runs Setup, and removes the owned staging root, avoiding a
  process waiting for an installer that must replace it. Its immediate result is
  explicitly `scheduled`; an application-scoped named mutex prevents duplicate
  handoffs and Inno's silent UI surfaces post-exit installation failures. The
  Linux adapter performs a non-mutating `dpkg --no-act` preflight before
  elevation and installs Chimera's script-free package with trigger processing
  deferred; this keeps failures inside dpkg's documented backup-and-rollback
  unpack transaction instead of introducing a second application-owned package
  database transaction.
- Add `chimera update apply --yes` with deterministic human/JSON output.
- Extend the native GUI update page with an explicit confirmation step and apply
  state; the web interface continues to expose no update capability.
- Do not update portable packages in place, persist approval, auto-approve,
  execute installers in tests, or perform live downloads in tests.

## Architecture

`chimera_core` owns `UpdateApplyService` and its typed request/result. The request
contains the already selected six-field `ReleaseMetadata` plus a boolean approval.
The service rejects an unapproved request before any staging or network boundary,
rejects portable packages because safe in-place replacement cannot be guaranteed,
creates an isolated artifact destination, downloads directly to that path,
verifies its published SHA-256 digest, and invokes the installer only after
successful verification. Direct installs always attempt staging cleanup. A
successful Windows handoff explicitly transfers cleanup ownership to its helper
so core does not race it by deleting the verified installer before launch.

The service maps each boundary failure or exception to a safe
`FailureKind.update` code. Boundary diagnostics are not forwarded because paths,
HTTP bodies, or process output can contain local or remote details. Cleanup
failure is reported explicitly after any staged attempt and retains the safe
prior failure code when another boundary failed first.

`chimera_platform` implements the boundaries. Temporary storage uses a uniquely
created system directory. HTTP download uses an abortable request, HTTPS GitHub
host validation, a timeout, a declared/streamed 512 MiB limit, and a file sink so
artifacts are never buffered in memory. SHA-256 verification streams the staged
file. Installer commands are fixed by the target platform: Windows starts a
detached, hidden helper with fixed script and arguments; after the parent exits,
the helper invokes the published Inno Setup executable with unattended/no-restart
flags and cleans staging. Linux invokes
an unprivileged `dpkg --no-act --install` preflight followed by
`pkexec dpkg --no-triggers --install` so elevation is explicit, dependency and
conflict failures are caught before mutation, and package unpack uses dpkg's
native backups. Chimera Debian packages contain no maintainer scripts, so
configuration adds no fallible application-specific mutation. A dismissed or
unavailable authorization prompt has its own actionable typed failure. Command
arguments are passed as an argument list, never through a shell.

## Approval and selection

The CLI and GUI repeat UC-44 discovery in the same invocation and pass the exact
selected metadata to the apply service. `chimera update apply` requires `--yes`;
without it, the command returns an approval-required result before constructing
or calling any download/install boundary. The GUI shows a confirmation dialog
containing version, package type, and checksum. Approval is ephemeral and is
cleared after every attempt.

Only installer metadata is applyable. Portable releases remain downloadable from
GitHub but are outside guided self-update because replacing an executing archive
cannot meet FR-UP-08. Compatibility and strict metadata validation remain owned by
the UC-44 shared check service.

## Interface behavior

CLI success output reports the installed version requested, applied version, and
whether restart is required; JSON keys are stable and status distinguishes
`scheduled` from `applied`. Failures use existing typed
JSON/human diagnostics and exit-code mapping. The native GUI disables check/apply
actions while work is running, clears stale status, asks for confirmation, and
announces success or failure through its live region. All copy is available in
English and Brazilian Portuguese.

## Failure mapping

- Missing approval: `update-approval-required`; no staging, download, checksum,
  or installer call.
- Portable package: `unsupported-update-package`; no side effects.
- Staging/download failure: `update-download-failed`; cleanup is attempted.
- Checksum mismatch/read failure: `update-checksum-failed`; installer is never
  called and cleanup is attempted.
- Installer preflight, launch, or nonzero exit: `update-install-failed`; cleanup
  is attempted and the installed application remains the selected working
  version according to the platform installer contract.
- Linux elevation dismissal/unavailability: `update-elevation-denied`, with
  localized guidance to approve the system prompt and retry.
- Cleanup failure after any staged attempt: `update-cleanup-failed`, retaining a
  safe prior failure code when applicable.

## Testing and verification

Core tests use recording fakes to prove approval gates every side effect, checksum
precedes installation, failures short-circuit correctly, and cleanup runs exactly
once on every staged path. Platform tests use injected HTTP/process/file
boundaries and never invoke a real network or installer. CLI and widget tests cover
confirmation, success, all failure states, JSON, both locales, accessible status,
and web absence. Formatting, fatal-info analysis, dependency boundaries, focused
tests, and the full relevant suite are required before review.

