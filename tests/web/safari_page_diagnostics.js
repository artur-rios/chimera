// Read-only evidence for native Safari failures; no focus, scroll or DOM changes.
function captureSafariPageDiagnostics() {
  const describe = element => ({
    tag: element.tagName,
    role: element.getAttribute('role'),
    label: element.getAttribute('aria-label'),
    rect: element.getBoundingClientRect().toJSON(),
  });
  return {
    ...(window.__chimeraCronDiagnostics ? {
      cronInteraction: window.__chimeraCronDiagnostics.snapshot(),
    } : {}),
    url: location.href,
    userAgent: navigator.userAgent,
    viewport: { width: innerWidth, height: innerHeight, devicePixelRatio },
    activeElement: document.activeElement ? describe(document.activeElement) : null,
    inputs: [...document.querySelectorAll('input, textarea')].map(element => ({
      ...describe(element), value: element.value, disabled: element.disabled,
    })),
    innerText: document.body.innerText,
    textContent: document.body.textContent,
    semantics: [...document.querySelectorAll('[aria-label], [role]')].map(describe),
    scrollContainers: [...document.querySelectorAll('*')]
      .filter(element => element.scrollHeight > element.clientHeight + 1)
      .map(element => ({
        ...describe(element), scrollTop: element.scrollTop,
        clientHeight: element.clientHeight, scrollHeight: element.scrollHeight,
      })),
    fonts: { status: document.fonts.status, faces: [...document.fonts].map(font => ({
      family: font.family, status: font.status,
    })) },
    resources: performance.getEntriesByType('resource').map(entry => entry.name),
    html: document.documentElement.outerHTML,
  };
}
