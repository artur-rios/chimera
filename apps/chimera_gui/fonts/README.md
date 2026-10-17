# Bundled emoji font

`Noto-COLRv1.ttf` is the unmodified full Noto Color Emoji font from Google's
Noto Emoji release **v2.051** (Unicode Emoji 17.0). It uses TrueType outlines
with COLRv1 color glyphs, rendered by Flutter's CanvasKit on the web. At
4,991,984 bytes (4.76 MiB), it includes the release's complete emoji repertoire,
including sequences and flags; it is not a subset for a test fixture.

- Upstream: <https://github.com/googlefonts/noto-emoji>
- Release commit: `8998f5dd683424a73e2314a8c1f1e359c19e8742`
- Source: <https://raw.githubusercontent.com/googlefonts/noto-emoji/8998f5dd683424a73e2314a8c1f1e359c19e8742/fonts/Noto-COLRv1.ttf>
- Upstream Git blob: `4d42b0d8a8530bac3f05ee281893028b3fd16662`
- SHA-256: `0ae57fe58645638523ba35f388d93739d292539a9acb84df5700c81b1e1a28d2`
- License: SIL Open Font License 1.1, redistributed verbatim as `OFL.txt`.
- Embedded copyright: Copyright 2022 Google Inc.
- Embedded version: `Version 2.051;GOOG;noto-emoji:20250818:e92753bfa55fd449e427d4d325f9c8c40408c74e`.
- License source: <https://raw.githubusercontent.com/googlefonts/noto-emoji/8998f5dd683424a73e2314a8c1f1e359c19e8742/fonts/LICENSE>
- License Git blob: `d952d62c065f3f35fb83a173496e90b21525aef3`
- License SHA-256: `6a73f9541c2de74158c0e7cf6b0a58ef774f5a780bf191f2d7ec9cc53efe2bf2`

Flutter's font manifest loads the font at startup. The app theme selects it as
a fallback only on web; native platforms retain their system font selection.
Roboto precedes emoji in the web fallback list so unavailable platform or
monospace font names retain the existing Latin, digit, and spacing metrics.
The font, attribution, and license are normal checked-in build inputs and ship
in the application assets. No build-time download or developer cache is needed.

The custom web bootstrap also sets `fontFallbackBaseUrl` to the app's
same-origin `font-fallback/` directory. A plain release build must still use
`--no-web-resources-cdn` to keep CanvasKit and Roboto local. Rare scripts outside
the bundled fonts can display missing glyphs, but their input remains intact and
cannot cause external font requests. This is not universal Unicode font coverage.
Static hosting must return 404 for missing files in `font-fallback/`.

To update, choose an immutable official release commit, verify the font and
license against GitHub's Git blob identities, update the hashes above, and run
the compiled font and GZIP browser tests in all supported browsers. Inspect the
attached emoji screenshots as well as the zero-network and nonzero-glyph checks.
