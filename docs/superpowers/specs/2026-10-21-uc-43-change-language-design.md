# UC-43 Change Language Design

## Scope

Chimera's interactive GUI lets the developer choose English or Brazilian
Portuguese. The choice takes effect immediately, is stored through the shared
preference gateway, and is restored on a later launch. English remains the
default and safety fallback.

## State and persistence

`LanguagePreferenceController` owns the active locale, save status, startup
restore, and serialized preference writes. It accepts only `en` and `pt-BR`.
Missing preferences use the configured startup locale (English in production),
while invalid stored values or incomplete catalogs fall back to English and
emit a sanitized structured localization diagnostic. Storage failures keep the
session selection active and expose a localized not-saved status.

Theme and language continue to share the existing `PreferenceGateway`; only
the approved `theme` and `language` keys can be written. Serializing writes
ensures rapid selections cannot leave an older locale in durable storage.

## GUI integration

The app owns one language controller beside the theme controller. Router
builders read the controller's current locale and refresh when it changes, so
the home page and utility routes use one consistent catalog without restarting
or losing the current path. A language panel follows the appearance panel and
uses an accessible two-option segmented control with localized save feedback.

## Verification

Controller tests cover defaults, both canonical values, invalid storage,
incomplete catalogs, unavailable storage, immediate application, write
ordering, and disposal. Widget and native integration tests cover both language
flows, route localization, restart restoration, session-only failures, narrow
large-text layout, and offline operation. Browser smoke coverage exercises the
selector in Chromium, Firefox, WebKit, and Safari.
