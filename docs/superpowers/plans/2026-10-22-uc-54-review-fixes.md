# UC-54 Validation Review Fixes

Independent review identified accepted inputs that could produce a repository
whose package or C# namespace was invalid. The shared parser now rejects them
before calling the transactional writer; its request and renderer interfaces
are unchanged so UC-55 can share the fix.

## NuGet package ID grammar

The authoritative [NuGet PackageIdValidator source](https://source.dot.net/NuGet.Packaging/PackageCreation/Utility/PackageIdValidator.cs.html)
uses `^\w+([.-]\w+)*$` plus the package length limit. The
[NU1017 reference](https://learn.microsoft.com/en-us/nuget/reference/errors-and-warnings/nu1017)
describes the grouped-separator requirement. Chimera retains its approved
portable ASCII character set and 100-character limit, while requiring
nonempty word groups between dot or hyphen separators. Underscores remain
valid at the start/end of groups, including an ID made of one underscore.

The installed .NET 10.0.113 SDK's `NuGet.Packaging.PackageIdValidator` confirmed
that `.`, `-`, `Example..Library`, and `Example.-Library` are invalid, while
`_`, `123`, `Example_`, and `_Example.Library_Pack-1` are valid. Tests preserve
those valid forms and cover leading/trailing/consecutive/mixed separators and
the 100/101-character boundary.

## C# special keyword tokens

Roslyn's [SyntaxKind source](https://raw.githubusercontent.com/dotnet/roslyn/main/src/Compilers/CSharp/Portable/Syntax/SyntaxKind.cs)
identifies `__arglist`, `__makeref`, `__reftype`, and `__refvalue` as keyword
tokens. Chimera now rejects those tokens as any ProjectName namespace segment,
in addition to its existing reserved keyword rules. It does not rewrite names.

## Evidence

- RED: the new utility grammar, special-keyword, and native no-output regressions
  failed against the reviewed implementation.
- GREEN: 27 focused utility/core/native tests pass, including native no-output
  assertions for invalid IDs and all four tokens in both fields and JSON modes.
- The new `packable-edge-parameters.json` fixture was consumed by a temporary
  copy of the existing build acceptance harness. Cached-feed .NET 10 restore,
  Release build (zero warnings/errors), one xUnit test, and pack succeeded with
  the exact ID `_Example.Library_Pack-1`.
- Focused analyzer: no issues found. Formatting: three files, zero changes.
  `git diff --check`: clean.
- No full suite, browser tests, or native GUI run was started here. Root owns
  those verification runs. Windows execution remains pending CI.
