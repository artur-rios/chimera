# UC-53 persistent browser status assertion

Chromium CI failed three attempts because `getByText` could not find the exact
unsupported-target explanation after Create annotated tag. That workflow did
not upload browser traces; its available diagnostic artifact contains Safari
files only. The exact original CI pointer-event ordering cannot be inspected.

The unchanged case passed in all three local engines, but its Chromium trace
shows the permanent result as a group whose accessible name is the explanation.
The text locator instead matches Flutter's offscreen live announcement.
Flutter's `semantics/accessibility.dart` clears that announcement after 300 ms.
This gives the old assertion only a transient observation window.

A controlled Chromium comparison retained the pointer click and offline mode,
waited for the exact named result group, then waited for the announcement to
clear. Both variants recorded one matching group and empty announcements.
The original text locator failed with the same five-second element-not-found
error as CI; the exact named group remained visible and passed. This proves
the locator can fail despite successful activation and a persistent result.

Assert the persistent group's exact accessible name. Keep the button click,
offline transition, explanation, visibility assertion, and timeouts unchanged.
No SDK, service, page, or broader activation changes are needed.

Evidence is preserved in `/tmp/chimera-m08-uc53-tag-status-control` and its log;
unchanged three-engine traces are in
`/tmp/chimera-m08-uc53-tag-unchanged-all-browsers`. The CI artifact metadata and
download are preserved separately under `/tmp/chimera-m08-uc53-tag-ci-*`.
