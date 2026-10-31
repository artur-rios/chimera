# UC-52 Bump .NET Project Version Design

Implements issue #101, FR-DW-06 and BR-DW-06. Sources: PowerShell `bump.ps1`
(7cd0a4867dbbd0301ddb5e6a207fbb0b29c56998), Python `bump.py`
(c7255b386ca49a40cbafde7c6e4edd29b25fdebf). Both discover only immediate `.csproj`
children of `./src`, or an explicit selected directory/file. Numeric M.m.p and
major/minor/patch lower-component reset semantics match the sources, including
numeric components with leading zeros. Increment arithmetic uses BigInt.

The pure utilities editor parses XML and uses event source offsets for minimal
splices, avoiding document reserialization. Existing Version attributes,
namespace prefixes, comments and CDATA remain; only the text changes. Insertion
uses the first PropertyGroup, after PackageId when present; missing/self-closing
groups/root are safely expanded. Direct Version elements in multiple groups,
complex nested content, DTDs and malformed documents are rejected before backup.
Explicit versions can repair a nonnumeric existing value; increments cannot.
Encoding support is strict UTF-8, optional BOM, and UTF-16 LE/BE with or without
BOM. Encoding declarations must match. Other encodings fail without modification.
Source bytes outside the edited span round-trip exactly, including CRLF/Unicode.

Core owns discovery/read/backup/replace/verify/restore orchestration behind a
native filesystem gateway. Native selection rejects links/junction aliases and
returns canonical project paths; Windows case aliases use platform path equality.
Exclusive sibling backup files are flushed and byte-verified before mutation.
A flushed sibling stage is checked against the expected original before rename;
source conflicts preserve newer source content and retain the original backup.
Reread verification checks the entire byte sequence and target Version. Any
transaction failure attempts rollback, retains the backup, and returns its path
plus whether restoration succeeded. Failed rollback never destroys the backup.
Backup cleanup denial after verified success produces a retained-backup warning.
No automatic retry, persistent approval, SDK call, network access or web fallback.

CLI: `dotnet bump (--version=M.m.p|--major|--minor|--patch)` with optional
`--project=<file-or-directory>` and `--json`. Strict option parsing rejects mixed,
duplicate and unknown modes. Desktop uses the same service and shows field/mode
selection, old/new versions, candidate paths and backup recovery status. All
messages are English/Brazilian Portuguese. Web has no filesystem action.

Filesystem operations use normal native path APIs, sibling staging and byte
comparisons; they do not claim locking against an adversarial concurrent writer
between OS syscalls. Observed source conflicts fail conservatively.
