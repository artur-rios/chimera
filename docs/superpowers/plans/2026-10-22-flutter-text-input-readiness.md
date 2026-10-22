# Flutter browser text input readiness

The UC-47 full run at `e028d6a` passed 593 browser cases and failed the existing
Lorem words case after its second count entry. The DOM assertion accepted `3`,
but the final canvas screenshot still showed count `2` and the old result.
The UC-50 full run at `f503b45` failed the existing Adler32 text case: the DOM
had received `abc`, but the canvas remained empty and the result was `00000001`,
the checksum of empty input. UC-49 previously showed the same separation for
SHA256 text. These are input-delivery observations, not incorrect algorithm
results for the input held by Flutter.

Flutter 3.47.7's web SDK explains why DOM focus alone is insufficient. In
`engine/semantics/text_field.dart`, the DOM focus handler requests a framework
semantics focus action. `SemanticsTextEditingStrategy.enable` initially stores
callbacks; a subsequent focused semantics update calls `activate`, which calls
`DefaultTextEditingStrategy.enable` and installs the actual input handler.
Blur removes those subscriptions. The full-run traces do not record listener
registration, so the precise activation ordering in those failures remains an
inference supported by the observed DOM/canvas divergence.

An isolated probe against the existing compiled UC-47 and UC-50 applications
observed listener installation and removal without altering them. All four
uncontrolled old/new cases passed in isolation; this was not a spontaneous
reproduction. A controlled probe then held the real input, keydown and selection
listener registrations at the activation boundary, leaving the compiled
application and its processing unchanged. The old entry path produced DOM `3`
with the prior Lorem result and DOM `abc` with the empty Adler32 result. The
new helper waited while the actual input handler was absent, then passed both
cases after explicit barrier release. The input events from both Playwright
fill and keyboard entry were trusted; trust alone is not the readiness signal.

The shared test-only observer passes original listener arguments and return
values through unchanged and tracks input callback/capture registrations on
editable nodes in a WeakMap. It is installed before navigation. The helper
waits for DOM focus and a registered input handler, then uses keyboard selection,
replacement and entry, checks the exact value, presses Tab, and checks the
value again. It neither writes Flutter state nor dispatches synthetic input.
Its contract follows the SDK's non-once input subscription; it does not claim
to inventory arbitrary browser listeners or once/AbortSignal subscriptions.
The current SDK omits listener options. An options object with a capture getter
would be read again by the observer; a future delegated or `oninput`-based SDK
would need a different readiness observation.

Lorem, checksum and hash specs share this helper. Their exact result, mapping,
copy, download bytes, source invalidation, failure and offline assertions stay
in place. No sleeps, test retries or timeout increases were added. The fault
injection stays outside the permanent suite because it models SDK internals.

Diagnostic sources, logs and traces are preserved under
`/tmp/chimera-field-activation-probe` and
`/tmp/chimera-field-activation-final`. The original full-run traces remain in
the UC-47 and UC-50 `tests/web/test-results` directories. Focused cross-browser
validation is reported separately from the full suite.
