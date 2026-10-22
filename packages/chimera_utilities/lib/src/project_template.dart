import 'dart:convert';

import 'package:crypto/crypto.dart';

final class TemplateBundle {
  TemplateBundle({
    required this.version,
    required Map<String, String> files,
    required Map<String, String> digests,
  }) : files = Map.unmodifiable(files),
       digests = Map.unmodifiable(digests);
  final String version;
  final Map<String, String> files;
  final Map<String, String> digests;
  bool get isValid =>
      version.isNotEmpty &&
      files.isNotEmpty &&
      files.length == digests.length &&
      files.entries.every((entry) {
        final parts = entry.key.split('/');
        return entry.key.isNotEmpty &&
            !entry.key.contains('\\') &&
            !entry.key.contains(':') &&
            !RegExp(r'[\x00-\x1f]').hasMatch(entry.key) &&
            parts.every(
              (part) =>
                  part.isNotEmpty &&
                  part != '.' &&
                  part != '..' &&
                  part.toLowerCase() != '.git' &&
                  part != '.chimera-scaffold-owner',
            ) &&
            sha256.convert(utf8.encode(entry.value)).toString() ==
                digests[entry.key];
      });
}

// Snapshot of artur-rios/project-template. Keep upstream attribution/license
// in the generated tree; no template download is needed at runtime.
final projectTemplate = TemplateBundle(
  version: 'b4921f53c3fe1c304953ee5a6c4cbef3f0e57635',
  files: {
    ".editorconfig": r'''''',
    ".gitignore": r'''''',
    ".wakatime-project": r'''''',
    "LICENSE": r'''Artur Rios Attribution License

Copyright (c) 2025-2026 Artur Rios (https://artur-rios.tech)

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to view,
use, copy, fork, modify, extend, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

1. Attribution. Any copy, fork, derivative work, or product that uses the
   Software, in whole or in substantial part, must give clear and visible
   credit to the original author, Artur Rios, including a link to at least one
   of the following:

     - https://artur-rios.tech
     - https://github.com/artur-rios

   The credit must appear in a reasonable place for the medium, such as the
   project's README, documentation, "About" or credits section, or the header
   of the distributed source files.

2. Notice. This license notice shall be included in all copies or substantial
   portions of the Software.

No other restrictions apply. The Software is free and open source.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHOR OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''',
    "README.md": r'''# Project Template

A generic template to be used as a starter for any project.

## Folder Structure

```txt
.
├─ LICENSE
├─ README.md
├─ src/
└─ tests/
```

- `src/`: Application/source code for the project.
- `tests/`: Test suites and fixtures.
- `LICENSE`: Project license (Artur Rios Attribution License).
- `README.md`: Project overview and usage notes.

## Legal Details

This project is licensed under the [Artur Rios Attribution License](./LICENSE). It is free and open source: you may view, use, fork, modify, and extend it, provided you credit the author, Artur Rios, with a link to [artur-rios.tech](https://artur-rios.tech) or [github.com/artur-rios](https://github.com/artur-rios).
''',
    "src/.gitkeep": r'''''',
    "tests/.gitkeep": r'''''',
  },
  digests: {
    ".editorconfig":
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    ".gitignore":
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    ".wakatime-project":
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "LICENSE":
        "1258724ae83c2a6e56af450e5608aef09a1b89480fed33eda7c922d61f0291a1",
    "README.md":
        "a383d0daf9139a864a38b8e8b057268880dd67ca09004db5bed1bdf5bf45b8c3",
    "src/.gitkeep":
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "tests/.gitkeep":
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  },
);
