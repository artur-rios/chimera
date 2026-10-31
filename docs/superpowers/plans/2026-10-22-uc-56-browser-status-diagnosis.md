# UC-56 browser status assertion diagnosis

The WebKit job 119802113853 in run 39771670005 failed the project
scaffolding unsupported-platform assertion on all three attempts. Its strict
locator error lists two exact text matches: the transient
`flt-announcement-polite` live announcement and a rendered status `span`.
The downloaded log is `/tmp/chimera-m08-uc56-webkit-ci.log`.

The status uses `Semantics(liveRegion: true)` around
`SelectionArea(child: Text(...))`. Its persistent accessible representation is
an exactly named group. A global text locator can match both the announcement
and the rendered text, as this CI failure demonstrates. UC-53 previously
exposed the related failure where the announcement disappeared before a text
assertion observed it; UC-56 instead has a strict duplicate match.

Change only the assertion to select the group by its complete accessible name.
Keep the real textbox fill, pointer button click, offline state, exact message,
and existing assertion timeout. No application behavior changes.

## Evidence and limits

- The original case passed unchanged in Chromium, Firefox, and WebKit locally
  (three cases, 27.3 seconds), so the CI collision is timing dependent. Evidence:
  `/tmp/chimera-m08-uc56-status-unchanged-all-browsers.log` and its separate
  trace directory.
- A preliminary live-announcement control did not establish an additional red
  result: its old-locator variant timed out while preparing the short-lived
  announcement, before reaching that assertion. The group variant passed.
  Preserve `/tmp/chimera-m08-uc56-status-control.log` without claiming a
  controlled old-locator failure.
- An additional synthetic collision replay finished before cancellation. It
  is not used as evidence for the fix; the actual CI duplicate-match failure
  supplies the direct red result.
- Final verification passed the original fixed case once in each engine
  (three cases, 34.9 seconds), serially under the shared heavy-test lock, with
  the container restricted to CPUs 0-3. Results are recorded in
  `/tmp/chimera-m08-uc56-status-fixed-all-browsers.log` with separate traces.

The read-only batch audit is recorded outside the repository in
`/tmp/chimera-m08-browser-status-audit.md`. UC-47 and UC-53 already use exact
named groups for these dynamic statuses. The UC-49 through UC-52 unsupported
banner assertions observe static text. UC-48, UC-54, and UC-55 have no existing
Playwright result assertion of this kind. No other branch is changed here.
