# UC-50 existing WebKit alphabet file activation

The full run at `f97a891` passed 593 browser cases and failed the existing
`GivenAlphabetSources_WhenDecodedAndRejected_ThenMappingAndFlowStayOffline`
case while waiting for its file chooser. Decoding, the Morse mapping, and
copying `SOS 2` had already passed. The failure was not a decoding mismatch.

The original trace records a successful pointer action on the semantic
`Load UTF-8 file` button, followed by no file-input creation or chooser event.
Screenshots show the Flutter canvas still scrolled to the result controls
while the semantic button has been scrolled into view. The copied notice and
its layout change appear during this next action; in the passing isolated
trace they appear before it. The clipboard test marker therefore precedes
Flutter's completed rendering in the failing run.

Flutter's semantic scrolling is asynchronous. In pointer mode the engine
temporarily suppresses browser scroll gestures, and a subsequent semantics
update can restore the framework scroll offset. A lost pointer activation
during that update is the supported explanation. The original trace does
not record DOM pointer-event targets, so its precise down/up ordering remains
an inference rather than a directly observed fact. This differs from the
earlier UC-49 SHA256 case, which lost text delivery before editor activation.

A temporary isolated probe retained the complete decoded/file/mapping/copy/
invalid-source/offline assertions and replayed the pending offset restoration:

- Pointer down targeted the file button; restoring the previous offset moved
  that node offscreen; pointer up targeted the textarea. No file input or
  chooser opened, reproducing the original timeout.
- The existing focus-and-Enter helper opened a real file input with active
  browser user activation and passed the complete flow under the same setup.
- Negative controls with only the DOM/canvas mismatch, or with restoration
  after browser gesture mode resumed, passed. Timing and offset restoration
  together produced the failure.

Use the existing keyboard activation helper for both alphabet cases' post-copy
file actions. Preserve every assertion and timeout. Real pointer file loading
remains covered by the URL, HTML, hash, checksum, GZIP, certificate, and QR
cases. Keep the fault injection outside the permanent suite because it depends
on engine details.

The decoded investigation used the original full-run `tests/web/test-results`
evidence. Separate diagnostic evidence is in `/tmp/chimera-uc50-alphabet-webkit-focused-1`
and `/tmp/chimera-uc50-alphabet-controlled-fast-restore`, with corresponding
`.log` files. The unchanged isolated case passed once before this change;
the controlled comparison then produced one expected pointer failure and
one keyboard success. No full suite retry was used for diagnosis.

## Encoded alphabet follow-up

The subsequent full run at `f503b45` passed the decoded case but exposed the
same chooser timeout in the encoded alphabet case after its copied-text
marker. Its trace shows Copy's old layout at 550485 ms, the new copied notice
and layout during the Load action at 550817 ms, and no file-input creation.
The canvas remains scrolled to the mapping/result controls while the semantic
Load button is the pointer target near the top. As before, the exact original
pointer-event ordering is inferred; the rendering mismatch is directly visible.

An isolated encoded-flow probe replayed the pending offset restoration and
retained all encoding/file/mapping/copy/invalid-source/offline assertions.
Pointer activation failed at the chooser wait; the existing keyboard helper
passed the complete flow. Evidence is in
`/tmp/chimera-uc50-encoded-controlled` and its corresponding `.log`; the original
failure trace/context are preserved in `/tmp/chimera-m08-uc50-encoded-original`.

The activation audit found the immediate post-copy marker plus long mapping
panel only in these two alphabet cases. Other real chooser cases load their
first source, or the QR second-source case waits for a completed download cycle.
The URL/HTML post-result malformed-file flows intentionally suppress the native
picker and inject file bytes. No shared helper or unrelated activation changes
are needed for the observed failure.

Both original alphabet cases passed across Chromium, Firefox, and WebKit with
one worker: six passes in 1.6 minutes, preserving the 30-second case deadlines.
The first three-worker attempt recorded four deadline failures at startup,
Copy, or file selection while host CPU pressure was high; Chromium passed.
Both runs are retained separately in
`/tmp/chimera-uc50-alphabet-both-keyboard-{serial,all-browsers}` and their logs.
