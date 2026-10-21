# UC-43 Change Language Implementation Plan

1. Add failing controller and catalog tests for canonical, invalid, unavailable,
   incomplete, and out-of-order language preferences.
2. Implement the language preference controller and sanitized localization
   diagnostics using the shared preference gateway.
3. Add failing widget and native integration tests for live switching,
   localized routes, persistence, offline behavior, failures, and accessibility.
4. Wire the controller through the app and router, then add localized language
   controls and messages.
5. Extend browser and Safari smoke coverage and accessibility evidence.
6. Format, analyze, run focused and full suites, obtain fresh review, and take
   the issue through Testing, pull request, CI, merge, and Done.
