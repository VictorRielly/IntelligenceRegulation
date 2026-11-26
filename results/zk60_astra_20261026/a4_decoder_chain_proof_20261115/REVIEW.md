# Development proof validation

The fixed batch and automatic evidence audit passed on 2026-11-17T05:54:00.596797+00:00.
The original coordinator session was 40919 (exit 0); this
candidate's child batch and audit exited 0. Exact original-session evidence is
recorded in `ORIGINAL_SESSION.json`.

The result covers 3 honest cases, 28 unit tests, 208 calibrated-layout
reconstructions and 2 coherent forged-receipt cases. All cases use the
ordinary verifier. Receipt sizes observed: [1012142768] bytes. Maximum sampled
guarded process RSS, including compilation: 12.45 GiB. Timings are shared-host
functional diagnostics, not controlled benchmarks.

Source manifest: `f2ed314699bf1194996c22e7fdc4170b41f1b81820674375403446a6a05b133b`. Exact frame hashes, per-leaf evidence, predecessor
pins and the executable digest are in `RESULT.json`. Prior failed attempts and
their source snapshots remain retained. Raw receipts are not archived for
independent replay.

This is development evidence from the implementing lane. Synthetic cases do not
establish task quality. Independent soundness/privacy/formal review, project
acceptance and production adoption remain open; no profile is installed.
