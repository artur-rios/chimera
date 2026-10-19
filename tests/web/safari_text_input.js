// Install before enabling semantics so autofocus connections are observed too.
// Keep this lightweight observer for the document lifetime, independently of
// optional diagnostic observers installed above it.
function installSafariTextInputReadiness() {
  let readiness = window.__chimeraTextInputReadiness;
  if (!readiness) {
    const listeners = new WeakMap();
    const originalAdd = EventTarget.prototype.addEventListener;
    const originalRemove = EventTarget.prototype.removeEventListener;
    const captureOf = options => typeof options === 'boolean' ? options : !!options?.capture;
    const isEditor = node => node instanceof HTMLInputElement || node instanceof HTMLTextAreaElement;
    EventTarget.prototype.addEventListener = function(type, callback, options) {
      const result = originalAdd.call(this, type, callback, options);
      if (isEditor(this) && type === 'input') {
        const registrations = listeners.get(this) ?? [];
        const capture = captureOf(options);
        if (!registrations.some(r => r.callback === callback && r.capture === capture)) {
          registrations.push({ callback, capture });
        }
        listeners.set(this, registrations);
      }
      return result;
    };
    EventTarget.prototype.removeEventListener = function(type, callback, options) {
      const result = originalRemove.call(this, type, callback, options);
      if (isEditor(this) && type === 'input') {
        const capture = captureOf(options);
        listeners.set(this, (listeners.get(this) ?? []).filter(r =>
          !(r.callback === callback && r.capture === capture)));
      }
      return result;
    };
    readiness = window.__chimeraTextInputReadiness = { listeners };
  }
  return readiness;
}

function prepareSafariTextInput(label) {
  const readiness = window.__chimeraTextInputReadiness;
  if (!readiness) throw new Error('Install input readiness before enabling semantics');
  const input = [...document.querySelectorAll('input[aria-label], textarea[aria-label]')]
    .find(element => element.getAttribute('aria-label') === label);
  if (!input || input.disabled) return false;
  if (document.activeElement !== input) input.focus();
  return document.activeElement === input && (readiness.listeners.get(input)?.length ?? 0) > 0;
}
