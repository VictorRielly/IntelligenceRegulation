# Development proof validation

The fixed batch and automatic evidence audit passed on 2026-11-17T05:55:16.239221+00:00.
The original coordinator session was 40919 (exit 0); this
candidate's child batch and audit exited 0. Exact original-session evidence is
recorded in `ORIGINAL_SESSION.json`.

The result covers 6 honest cases, 29 unit tests, 208 calibrated-layout
reconstructions and 4 coherent forged-receipt cases. All cases use the
ordinary verifier. Receipt sizes observed: [2873101488] bytes. Maximum sampled
guarded process RSS, including compilation: 13.99 GiB. Timings are shared-host
functional diagnostics, not controlled benchmarks.

Source manifest: `ed25713d3b4bb88bfcb7ada5ad9e0ce3ff8b6966e498ce315664d8b89772e968`. Exact frame hashes, per-leaf evidence, predecessor
pins and the executable digest are in `RESULT.json`. Prior failed attempts and
their source snapshots remain retained. Raw receipts are not archived for
independent replay.

This is development evidence from the implementing lane. Synthetic cases do not
establish task quality. Independent soundness/privacy/formal review, project
acceptance and production adoption remain open; no profile is installed.
