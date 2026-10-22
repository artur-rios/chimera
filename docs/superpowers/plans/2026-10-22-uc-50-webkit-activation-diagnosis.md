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

Use the existing keyboard activation helper for this case's file action.
Preserve every assertion and timeout. The encoded alphabet case continues
to exercise the file action using a real pointer click. Keep the fault
injection outside the permanent suite because it depends on engine details.

Original evidence remains under the UC-50 `tests/web/test-results` directory.
Separate diagnostic evidence is in `/tmp/chimera-uc50-alphabet-webkit-focused-1`
and `/tmp/chimera-uc50-alphabet-controlled-fast-restore`, with corresponding
`.log` files. The unchanged isolated case passed once before this change;
the controlled comparison then produced one expected pointer failure and
one keyboard success. No full suite retry was used for diagnosis.
