import { expect } from '@playwright/test';

// DOM focus precedes Flutter's semantics update that attaches its input handler.
// Observe that boundary without changing listener arguments, callbacks or return
// values. Flutter installs a non-once input listener and removes it on blur.
export async function observeFlutterTextInput(page) {
  await page.addInitScript(() => {
    if (window.__chimeraFlutterTextInputReady) return;
    const listeners = new WeakMap();
    const add = EventTarget.prototype.addEventListener;
    const remove = EventTarget.prototype.removeEventListener;
    const editable = target => target instanceof HTMLInputElement
      || target instanceof HTMLTextAreaElement;
    const capture = options => typeof options === 'boolean'
      ? options : Boolean(options?.capture);

    EventTarget.prototype.addEventListener = function(type, listener, options) {
      const result = add.apply(this, arguments);
      if (type === 'input' && listener && editable(this)) {
        let registered = listeners.get(this);
        if (!registered) listeners.set(this, registered = new Map());
        let captures = registered.get(listener);
        if (!captures) registered.set(listener, captures = new Set());
        captures.add(capture(options));
      }
      return result;
    };
    EventTarget.prototype.removeEventListener = function(type, listener, options) {
      const result = remove.apply(this, arguments);
      if (type === 'input' && listener && editable(this)) {
        const registered = listeners.get(this);
        const captures = registered?.get(listener);
        captures?.delete(capture(options));
        if (captures?.size === 0) registered.delete(listener);
      }
      return result;
    };
    window.__chimeraFlutterTextInputReady = node => node.isConnected
      && document.activeElement === node && Boolean(listeners.get(node)?.size);
  });
}

export async function fillFlutterTextInput(editor, value) {
  await expect(editor).toBeVisible();
  await expect(editor).toBeEnabled();
  await editor.focus();
  await expect(editor).toBeFocused();
  await expect.poll(() => editor.evaluate(node =>
    window.__chimeraFlutterTextInputReady(node))).toBe(true);
  await editor.press('Control+A');
  await editor.press('Backspace');
  await editor.pressSequentially(value);
  await expect(editor).toHaveValue(value);
  await editor.press('Tab');
  await expect(editor).toHaveValue(value);
}
