# UC-42 Change Theme Design

## Intent and scope

Let a developer choose the light or dark appearance in Chimera's shared
Flutter interface. The selected theme is applied immediately to the current
browser or desktop session and persisted locally under the already-approved
`PreferenceKey.theme` key. A later launch restores that exact selection.

Theme preference data is local interface state. It contains no utility input,
output, or history and is never transmitted. The CLI is outside this use case
because it has no interactive visual theme.

## Theme contract

The only canonical stored values are the lowercase strings `light` and
`dark`. A missing value means light. Any other value is ignored and startup
continues in light mode without rewriting storage. This deterministic fallback
implements AF-02 and avoids turning corrupt or future-version data into a
startup failure.

Selection is optimistic: Chimera updates the active `ThemeMode` before
awaiting persistence. A successful write reports that the chosen theme was
saved. A failed or unavailable write keeps the selected theme for the current
session and reports, in the active locale, that it was not saved. A failed
startup read also keeps the light default and reports that preferences are
unavailable for persistence.

Concurrent or delayed reads and writes are generation guarded. A late startup
read cannot replace a user's newer selection, and an older failed write cannot
replace the status of a newer successful choice.

## Architecture and interface

`SharedPreferencesPreferenceGateway` is the sole concrete adapter for the
existing `PreferenceGateway` contract. It maps `PreferenceKey.storageKey` to
`shared_preferences`, catches platform/plugin errors, and returns typed,
redacted access failures. The enum boundary guarantees that only the approved
`theme` and `language` keys can be addressed.

`ThemePreferenceController` owns restoration, selection, persistence status,
and stale-completion guards. It exposes immutable observable state to both the
top-level `MaterialApp.router` and a reusable home-page theme selector. The app
defines explicit light and dark `ThemeData` from the same seed color and uses
the controller's mode as `themeMode`.

The selector is available on the home page in English and Brazilian
Portuguese, is keyboard reachable, exposes at least 48 logical-pixel targets,
and announces saved or session-only status as a live region. It remains usable
at narrow widths and 200 percent text scale.

## Verification and traceability

Controller and adapter tests cover missing, light, dark, invalid, read-failure,
write-failure, delayed, stale, and disposal paths plus exact permitted storage
keys. Widget tests cover both locales, immediate brightness changes, persisted
restart restoration, invalid fallback, localized session-only status,
keyboard/accessibility behavior, and large text. Native and browser journeys
exercise selection and restoration without network access.

This traces UC-42, FR-PL-07, BR-06, and issue #43.

## Explicit non-goals

This use case does not add system-theme following, custom palettes, theme
scheduling, cross-device synchronization, remote storage, CLI colors, or
language persistence (UC-43).
