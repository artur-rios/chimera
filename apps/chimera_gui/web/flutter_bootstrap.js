{{flutter_js}}
{{flutter_build_config}}

const serviceWorkerVersion = {{flutter_service_worker_version}};

_flutter.loader.load({
  // Flutter substitutes null for --pwa-strategy=none. Omit the settings entirely
  // in that mode, including when the browser has an older worker registration.
  ...(serviceWorkerVersion === null
    ? {}
    : { serviceWorkerSettings: { serviceWorkerVersion } }),
  config: {
    // Keep missing-script fallback on this origin, including subpath hosting.
    // Common emoji are bundled and loaded by Flutter's FontManifest at startup.
    fontFallbackBaseUrl: new URL('font-fallback/', document.baseURI).href,
  },
});
