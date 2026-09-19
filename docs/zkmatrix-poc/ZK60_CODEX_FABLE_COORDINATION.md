# Codex ↔ Fable active loop — 2026-09-18

Victor explicitly asked the two live loops to collaborate toward the workable
private MVP and the five-second target. This is the current handoff, not a
claim that either target has been reached. Fable can acknowledge and report
its chosen branch/files in `ZK60_FABLE_LANE_HANDOFF.md`; Codex owns this file.

## Codex lane: complete functional receipt and integration

Codex owns `private-block-kernel/`, `private-model-kernel/`, `zkvm-block/`,
`zkvm-model/`, the maintained demo/tool runners, their tests, and integration
evidence. Opus 5 is adapting the runner in its isolated worktree to explicit
block/token profiles and independently supplied verifier image pins.

- Complete block: 785-byte Groth16 receipt verifies; all eight rejection
  controls pass. The maintained Python verifier also accepts the saved receipt.
  Thank you for independently verifying and preserving the public bundle.
- Full Python suite: **962 tests, 60 skipped, pass**. Original aggregate
  marker preserves the missing-default-fixture failure; the corrected native
  freeze passes using `M125_EXPORT_DIR=results/m125_ffn_export_wsl`.
- Token workspace: **24 Rust tests pass**, and Rust/Python framing vectors
  agree. Codex and Fable independently caught the launcher's `--examples`
  mistake. Corrected `token_build_v2.py` builds `--bins`; it does not repeat
  the passing tests. Detached PID 289296; `token-build-v2.done` is its marker.
  `token_prove_v2.py` (PID 289381) waits for that successful execution gate,
  then proves, wraps and checks rejection controls. Both use the shared lock.
  Records live in `/tmp/zk60-loop-20260917/`; do not launch duplicates.
- Independent source review found that inherited `RISC0_PPROF_OUT` can write
  secret-dependent profiles. All four root host/wrapper CLIs now refuse all
  `RISC0_*` and `BONSAI_*` runtime switches. The runner already scrubs those
  prefixes. The guest computation was unchanged. The token review is
  `ZK60_TOKEN_MODEL_SOURCE_REVIEW.md`.

## Fable request: implement the custom attention path

The zkVM computation is a functional intermediate, so its CPU proof duration
cannot close the five-second gap. The next useful parallel delivery is the
**native custom private-attention prover/verifier**, using your A1–A4
construction and the actual repaired FFN conventions. Please take this in an
isolated worktree/branch, record ownership before editing, and hand back a
reviewable implementation with saved-proof verification and negative controls.

Proposed Fable file lane: new `hashline/src/private_attention*`, its examples
and tests; the minimum module export in `hashline/src/lib.rs`; and narrowly
identified shared attention helpers if required. Codex is not editing those
files. Record any wider ownership request in the handoff before changing it.
Keep existing profiles and frozen proof bytes unchanged. Read-only references:
the current repaired FFN, fixed kernel/oracle, and your attention schedule.

Acceptance for this engineering delivery: the full tiny attention relation
(norm, QKV, RoPE, causal scores, softmax, PV, projection, residual) is actually
verified, with explicit private endpoint bindings and the declared masked
channels; malformed and inconsistent witnesses/receipts are refused. Separate
the native implementation result from any whole-proof privacy acceptance.
D8/D11 and the forced-challenge counterexample in
`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md` remain open; do not reduce the
allowed prior history or declare it solved by the consuming API.

For the speed target, attach operation/byte counts and a phase breakdown on a
small correctness run if available. Public 8B FFN timing is not a complete
private-model timing. Shared-box timings are diagnostic; no five-second or
quiesced p95 claim follows from them. Larger timed runs share `/tmp/zk-heavy.lock`.

## Integration and rulings

Codex will review Fable's attention delivery while Fable reviews the new
token receipt profile and source pins. D3/D4 remain accepted as recorded.
D7 is still pending; the synthetic models are test fixtures, not approved
trained models. No pending ruling blocks independent implementation work.
Keep `MVP_STATUS.md` current and retain original failed run markers alongside
their corrections. Do not publish inner receipts, salts, plaintext outputs,
activation traces, witness files or private prover logs.
