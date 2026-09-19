# Codex ↔ Fable active loop — 2026-09-18

## CURRENT — Codex pickup, 2026-09-19

**Capture implementation now active:** Codex is editing only the native
attention/block module declarations, their `protocol.rs` / `argument.rs`, a
shared test-only observer and its native-profile ingestion tests. `zk.rs`
remains available to Fable's staging lane. The observer records accepted
verifier inputs only, including definition draws and every masked slot;
no production capture switch or prover-state export is being added.

The native observer and ingestion gate now pass trial replay of two attention
and two complete-block receipts, with 49 native unit tests and 13 Python
controls. `ZK60_NATIVE_CAPTURE.md` describes the format and exact replay
gate. Final source-pinned artifacts are being retained next. Please review
the observer/slot-to-PCS/M aliases and then own the joint-view analysis;
the older FFN CLI parsers are shape-pinned, so a native adapter is required.
The generic CFS field/evaluation routines already run unchanged on all slots.
No D8/D11 closure or empty-history assumption is made.

Codex also read `ZK60_PRIVATE_FFN_COST_PROBE.md`. The public-endpoint repaired
mask timing probe is useful as an explicitly separate cost diagnostic. After
the staging port, please propose the narrow shape-general entry pair in
`zk.rs` from that memo, in its own reviewable commit with legacy byte gates.
Keep the tiny private-IO entry points pinned. Codex can take the bounded
runner/CPU ladder after integration; no model-width GPU run is authorized
by this handoff, and the current heavy/GPU window remains held.

**Reply to Fable's 10:33/10:39 asks:** the integration is committed as
`f1df3ba`. Yes, take the narrow `zk.rs` staging-pool/int8-fold port in an
isolated worktree; Codex is not editing `zk.rs` for the capture writer.
Keep the legacy frozen-byte gates and repaired private-IO verification
separate; no transcript, mask schedule, endpoint or privacy-policy changes
are part of that lane. Codex integrates the reviewed handoff. The `fsp-l9`
small-shape GPU lane has priority under the shared heavy lock; Codex has no
GPU job queued. Hold the three-arm 8B measurement until the kernel changes
are integrated and the current memory/idle preflight is reviewed; no timing
window is reserved yet. Codex is correcting the headline from the retained
58.40-second log. Capture writers remain Codex's next native-code work;
Fable retains GPU-preserving composition, D12 chaining and D8/D11.

Acknowledged Fable's 10:30 handoff and proposed split. Codex has integrated
the attention delivery from `ea81815` and the reviewed complete-block delivery
at `98a5db9`. Fable retains the two planning documents,
the GPU-preserving construction and D12 chaining design, and D8/D11 work.
Codex will not duplicate those drafts. No GPU job has been launched.

Attention integration includes exact U8 inverse reuse (47,104 lookups reuse
256 table inverses), explicit verifier-side tamper assertions, the R-2 comment
corrections and finer phase clocks. All 17 attention Rust tests, native freeze,
and 22 cross-version fresh-process verifications (66 corruption controls)
pass. Ten alternating warm CPU diagnostics per binary give 50.5 / 49.0 ms;
this noisy difference is not an established speedup. The full Python suite
passes (1,098 tests, 61 skipped); the two known portability issues are corrected.
Evidence is under
`results/zk60_attention_integration_20260919/`.

The old temporary jobs are absent after the restart; none has been counted
as live or blindly restarted. Existing hardening integration edits are
preserved. The bounded headless Fable review found no blocking attention
verifier defect and confirmed integrating the overnight block. Its stale
block-comment findings are corrected; its PCS draw-order pin remains a
follow-up. Both combined profiles pass 47 unit, eight integration and two
ownership doc tests; the block inventory passes 29 tests. A new 2,816,472-byte
block receipt proves in 0.062 s and verifies in 0.020 s on the shared CPU;
the archived lane receipt verifies too, with all corruption controls rejecting.
These are tiny diagnostics, not a privacy/model-scale speed claim. Attention
fixture scales now match `(0, 0)`. See `ZK60_ATTENTION_INTEGRATION_20260919.md`.
Codex next advances captures and the remaining integration work.

Victor explicitly asked the two live loops to collaborate toward the workable
private MVP and the five-second target. This is the current handoff, not a
claim that either target has been reached. Fable can acknowledge and report
its chosen branch/files in `ZK60_FABLE_LANE_HANDOFF.md`; Codex owns this file.

## Codex lane: complete functional receipt and integration

Codex owns `private-block-kernel/`, `private-model-kernel/`, `zkvm-block/`,
`zkvm-model/`, the maintained demo/tool runners, their tests, and integration
evidence. Opus 5's block/token runner and native-tool pin helper are integrated
and tested. A new Opus measurement task is listed below.

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

**Dispatch update:** the headless Claude Fable 5.1 implementation lane now
has worktree `/tmp/wt-zk60-attention-fable-20260918`, branch
`zk60-private-attention-fable-20260918` at checkpoint `db021ba`. It is the
sole writer for the attention Rust files below. The interactive Fable loop
is requested to review that delivery's construction and speed accounting,
and the root token receipt, so two writers do not duplicate the same patch.
Task/log/marker: `/tmp/zk60-loop-20260917/fable-attention-task.txt`,
`fable-attention.log`, `fable-attention.done`. No heavy proof is delegated;
Codex owns the shared heavy queue and integration.

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

Opus 5's current worktree is `/tmp/wt-zk60-private-profile-opus-20260918`,
branch `zk60-private-profile-opus-20260918` at `db021ba`. It owns only
`zk_ffn_fresh_io.rs`, a new `zk60_private_ffn_profile.rs` example, narrowly
related IO tests and its new diagnostic guide. It exposes existing phase
durations on explicit request without changing transcript/proof bytes or
default behavior. Fable's attention writer should keep those files read-only.
Task/log/marker are `opus-private-profile-task.txt`, `opus-private-profile.log`,
`opus-private-profile.done` in the loop scratch directory. Parent runs actual
proof measurements and separate-process verification after review.

The reviewed memory-bounded ceremony checker is queued as PID 318776,
`verify_ceremony.py`, behind successful `ceremony-prepare.done` (preparation
PID 297871 waits on the shared lock). `ceremony-check.done` and
`ceremony/check-1/result.json` are the checker's result markers. Six small
controls passed, including strict Node return values, memory-budget refusal,
import side effects and interruption markers. Neither queueing nor verified
downloads establishes ceremony verification. Token work retains priority.

Interactive Fable's hardening branch `zk60-zkvm-hardening` at `12341e6` is
received and under review. Codex owns its integration; a separate Codex
reviewer checks host/wrapper changes while Codex checks runner/cycle handling.
The live token proof's binaries and guest source stay fixed during that review.

Codex will review Fable's attention delivery while Fable reviews the new
token receipt profile and source pins. D3/D4 remain accepted as recorded.
D7 is still pending; the synthetic models are test fixtures, not approved
trained models. No pending ruling blocks independent implementation work.
Keep `MVP_STATUS.md` current and retain original failed run markers alongside
their corrections. Do not publish inner receipts, salts, plaintext outputs,
activation traces, witness files or private prover logs.
