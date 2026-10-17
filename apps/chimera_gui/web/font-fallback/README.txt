Chimera reserves this same-origin directory for Flutter font fallback.

The full Noto Color Emoji v2.051 font is bundled in the Flutter assets and loaded
before the app starts. Latin UI text uses Flutter's bundled Roboto font.

Scripts outside those fonts may display a missing glyph offline. Their underlying
Unicode text is preserved. Flutter may request an unavailable font from this
directory, but it must never contact an external font service. Static hosts must
return 404 for missing files here, rather than rewrite them to index.html or proxy
them to Google Fonts. Additional script support requires explicitly bundling and
licensing suitable fonts; this directory is not a mirror of Google's font CDN.
