// Public Cron fixture diagnostics only. Never changes focus, values, or events.
function installCronDiagnostics() {
  const records = [];
  let dropped = 0;
  let sequence = 0;
  let stopped = false;
  const ids = new WeakMap();
  const listeners = new WeakMap();
  const pendingFrames = new Set();
  const eventTypes = ['focus', 'blur', 'pointerdown', 'pointerup', 'click',
    'keydown', 'keyup', 'beforeinput', 'input', 'change'];
  const isEditor = node => node instanceof HTMLInputElement || node instanceof HTMLTextAreaElement;
  const describe = node => {
    if (!(node instanceof Element)) return null;
    if (!ids.has(node)) ids.set(node, ++sequence);
    const registrations = listeners.get(node) ?? [];
    return {
      id: ids.get(node), tag: node.tagName, label: node.getAttribute('aria-label'),
      role: node.getAttribute('role'), text: isEditor(node) ? null : node.textContent?.slice(0, 100),
      value: isEditor(node) ? node.value : null,
      selection: isEditor(node) ? [node.selectionStart, node.selectionEnd] : null,
      connected: node.isConnected, attributes: Object.fromEntries([...node.attributes].map(a => [a.name, a.value])),
      inputHandlers: registrations.filter(r => r.type === 'input').length,
      keydownHandlers: registrations.filter(r => r.type === 'keydown').length,
    };
  };
  const record = data => {
    if (stopped) return;
    if (records.length >= 2000) { dropped++; return; }
    records.push({ at: performance.now(), hasFocus: document.hasFocus(), visibility: document.visibilityState, ...data });
  };
  const originalAdd = EventTarget.prototype.addEventListener;
  const originalRemove = EventTarget.prototype.removeEventListener;
  const captureOf = options => typeof options === 'boolean' ? options : !!options?.capture;
  const tracked = type => type === 'input' || type === 'keydown';
  function add(type, callback, options) {
    const result = originalAdd.call(this, type, callback, options);
    if (isEditor(this) && tracked(type)) {
      const registrations = listeners.get(this) ?? [];
      const capture = captureOf(options);
      if (!registrations.some(r => r.type === type && r.callback === callback && r.capture === capture)) {
        registrations.push({ type, callback, capture });
        listeners.set(this, registrations);
      }
      record({ kind: 'listener-added', type, target: describe(this) });
    }
    return result;
  }
  function remove(type, callback, options) {
    const result = originalRemove.call(this, type, callback, options);
    if (isEditor(this) && tracked(type)) {
      const capture = captureOf(options);
      listeners.set(this, (listeners.get(this) ?? []).filter(r =>
        !(r.type === type && r.callback === callback && r.capture === capture)));
      record({ kind: 'listener-removed', type, target: describe(this) });
    }
    return result;
  }
  EventTarget.prototype.addEventListener = add;
  EventTarget.prototype.removeEventListener = remove;
  const observe = event => {
    if (!location.hash.includes('/cron/parse')) return;
    record({ kind: 'event', type: event.type, timeStamp: event.timeStamp,
      trusted: event.isTrusted, key: event.key ?? null, inputType: event.inputType ?? null,
      defaultPrevented: event.defaultPrevented, target: describe(event.target),
      active: describe(document.activeElement) });
    if (event.type === 'focus') {
      const target = event.target;
      const request = requestAnimationFrame(frameTime => {
        pendingFrames.delete(request);
        record({ kind: 'frame-after-focus', frameTime, target: describe(target),
          active: describe(document.activeElement) });
      });
      pendingFrames.add(request);
    }
  };
  for (const type of eventTypes) originalAdd.call(document, type, observe, { capture: true, passive: true });
  window.__chimeraCronDiagnostics = {
    snapshot: () => ({ records: records.slice(), dropped, hasFocus: document.hasFocus(),
      visibility: document.visibilityState, active: describe(document.activeElement),
      inputs: [...document.querySelectorAll('input[aria-label], textarea[aria-label]')].map(describe) }),
    stop: () => {
      stopped = true;
      delete window.__chimeraCronDiagnostics;
      for (const request of pendingFrames) cancelAnimationFrame(request);
      pendingFrames.clear();
      for (const type of eventTypes) originalRemove.call(document, type, observe, true);
      if (EventTarget.prototype.addEventListener === add) EventTarget.prototype.addEventListener = originalAdd;
      if (EventTarget.prototype.removeEventListener === remove) EventTarget.prototype.removeEventListener = originalRemove;
    },
  };
}
