# UC-50 Clean .NET Build Artifacts Design

Approved implementation scope: issue #99, FR-DW-04, BR-DW-04. Source behavior comes
from PowerShell `clean.ps1` (7cd0a4867dbbd0301ddb5e6a207fbb0b29c56998) and Python
`clean.py` (c7255b386ca49a40cbafde7c6e4edd29b25fdebf). Their default source scope and
exact artifact selection are retained; silent deletion failures are corrected.

Core owns an injected filesystem gateway, immutable one-use preview and report,
confirmation gate and per-artifact failure continuation. Native discovery emits
topmost artifact directories so nested artifacts are deleted once. Both adapters
use this service. CLI is `dotnet clean --root=<directory> [--yes]`; desktop has a
preview and explicit dialog; web has an unsupported message and no native import.
All displayed messages have English and Brazilian Portuguese catalog entries.

Reject traversal, linked roots and ancestors, junctions, volume roots, nonfolders,
case aliases and canonical paths differing from lexical paths. Ignore directory
links during discovery; refuse entire artifact trees containing links. Capture
root/artifact metadata at preview and conservatively reject changed directories.
Preflight each artifact tree; before every entry deletion recheck all ancestors
and exact canonical containment. Never use recursive deletion. New entries cause
nonempty-directory failure and retention rather than undisclosed scope expansion.
Do not count a directory until its absence is verified. Partial reports list each
retained topmost artifact, including a partially removed tree.

Dart filesystem APIs are path based: these checks close observable preview and
between-entry swaps, but do not provide atomic directory-handle operations against
a hostile process swapping ancestors between OS syscalls. Metadata snapshots are
conservative change detection, not filesystem identity. Cleanup assumes the
selected workspace is not concurrently controlled by an adversarial process;
stronger hostile-filesystem isolation requires platform-specific handle APIs.

AF-01 returns typed validation with no deletion for invalid roots; unsafe artifact
paths are retained. AF-02 is a successful zero no-op. AF-03 continues over remaining
approved paths and reports partial failure. Declined confirmation deletes nothing.
No persistence, SDK invocation, network request, or web filesystem fallback exists.
