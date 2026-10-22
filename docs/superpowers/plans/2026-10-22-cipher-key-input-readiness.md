# Cipher key input readiness

The UC-55 full run at `c06ce8d` passed 593 browser cases and failed the existing
Chromium cipher encoding case at the exact `K3Y` key-value assertion. Atbash
encoding and copying had already succeeded. The key's DOM focus completed,
then `fill('K3Y')` completed, but the value was empty throughout the following
five-second assertion. No cipher validation or encryption had run for that key.

The trace shows `autocomplete="off"` before the key fill and `autocomplete="on"`
plus `autocapitalize="off"` after it. Those attributes are applied by Flutter's
active text input configuration. Flutter 3.47.7's semantics focus handler first
requests framework focus; a later semantics update activates the editor,
attaches its input handlers and restores its last editing state. Late activation
restoring the empty controller is consistent with the observed transition.
The original trace does not record listener registration or prove the exact
ordering of that restoration and the input event.

Use the already reviewed input-readiness observer and helper for the encoding
case's key entry and the decoding case's two key entries. Install the observer
before navigation in those two cases only. Keep main text pointer entry, menu
and action controls, exact values/results, invalid-key checks, offline checks
and timeouts unchanged. The existing real failure supplies the RED evidence;
no synthetic timing replay, sleeps, retries or timeout increases are added.

The original log is `/tmp/chimera-m08-uc55-full.log`; its trace remains under
UC-55 `tests/web/test-results`. Focused encode/decode validation passed all six
cases across Chromium, Firefox and WebKit in 1.2 minutes, using one worker under
the shared heavy-test lock on CPUs 4–7. Its evidence is
`/tmp/chimera-uc55-cipher-key-readiness/all-browsers.log`.
