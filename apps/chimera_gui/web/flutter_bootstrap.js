{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    // Keep missing-script fallback on this origin, including subpath hosting.
    // Common emoji are bundled and loaded by Flutter's FontManifest at startup.
    fontFallbackBaseUrl: new URL('font-fallback/', document.baseURI).href,
  },
});
