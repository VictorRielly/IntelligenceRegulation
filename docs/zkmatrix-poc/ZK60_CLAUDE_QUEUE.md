# Claude — expanded ZK60 work queue

Victor requested a substantial queue, not just one small follow-up. There are
**ten substantive tasks (CL2–CL11)** below. These are ready/queued assignments
for Claude's own session, not claims that Claude or Codex workers executed them.
CL1 is delivered; preserve its existing history and branch. Round 4 is pushed
as `5657a8d`. Read the latest task board and actual branch tip before pickup.

## First priority and coordination

**Hold CL1 integration pending the concrete CL2/CL3/CL4 review findings.**
The read-only [integration review](ZK60_CL1_INTEGRATION_REVIEW.md) records the
source locations and limits. Round 6 reviewed committed tip `6e28b6f`:
CL2's strict off/monotonic twiddle fixes and CL3's late allocation retry are
present. **CL3 needs follow-ups** on uncounted `take_min`/raw allocations,
actual fallback numerical parity, and planner chunk rounding/reuse/lifetimes.
CL4 is being edited in Claude's checkout and is not yet accepted. Its final
gate must compare full hashes, check proof subprocess exit/verification and
require actual GPU execution. The detailed review is the pickup list; Codex
has not edited Claude's owned source. CL8/CL10 supporting work is committed
on Claude's branch, not merged or a private-block implementation.

Work in a separate checkout, record the base and claim a task in your own
report. One active writer may own `gpu/cuda.rs`/kernels at a time; use serial
commits for CL2→CL3→CL4→CL6→CL7 and keep tests/reports in disjoint scopes if
Claude uses parallel agents. CL5 instrumentation follows CL4; CL8 and CL10
analysis/tools can begin immediately. CL9 follows correctness gates. CL11
preflight can be prepared before the 5090 arrives. Do not wait idle for a GPU
when a ready design/test task is available.

Codex owns current `field.rs`, `attention.rs`, `layer.rs` verifier hardening,
receipt/codec, CLI, broader Python fixture repair, shared boards and integration.
Fable owns the independent actual joint-opening/mask-rank and model-identity
review. Claude continues GPU/PCS ownership; **memory planner ownership is
explicitly transferred to Claude for CL3**, including its dedicated unit tests.
Propose cross-owner APIs in the task report before editing. Shared task-board
updates go through the integrator; do not stage another agent's partial edits.

## Common acceptance and safety

- Preserve existing accepted transcript/RNG order and full SHA-256/length of
  frozen P0/P1 fixtures. New profiles require distinct domains and review.
- Compare CPU oracle leaves AND opened columns; include negative controls.
  Hardware gates must require actual device execution, not captured skip text.
- Use `flock /tmp/zk-heavy.lock`, two build/Rayon threads, separate CPU/GPU
  target directories. Jobs expected over five minutes detach with logs and
  exit markers. No full 8B GPU run on this laptop without a separate safety
  decision; a worker report cannot grant itself that authority.
- Existing CL1 single-layer seconds are diagnostics, not a p95 or 60/s result.
  Account for pool reservation and pending ownership, not just live scratch.
  Keep FFN-only, public-block and full generation claims separate.
- Fable's privacy audit remains a gate. Do not use sensitive inputs or certify
  P1/P3 privacy based on byte parity, uniformity tests or this optimization queue.
- Each task hands off changed files, exact base/commit, commands, exit codes,
  actual executed cases/device, full digests, memory bounds, timing scope and
  remaining limits. Keep each improvement separately reviewable and pushed.

CPU build/test baseline (from repository root):

```sh
flock /tmp/zk-heavy.lock env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 cargo test --release --offline --manifest-path hashline/Cargo.toml --all-targets -- --test-threads=2
```

GPU command template after explicit device preflight and CL4 gate implementation
(use the existing known-good CUDA environment, not guessed driver paths):

```sh
flock /tmp/zk-heavy.lock env HL_GPU=1 CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 CARGO_TARGET_DIR=hashline/target-gpu cargo test --release --offline --manifest-path hashline/Cargo.toml --features gpu-cuda --test zk60_gpu_commit -- --test-threads=1 --nocapture
```

Today that command alone is **not** a GPU-required guarantee; CL4 must add
fail-closed enforcement and execution counts. Do not report six tests as six
GPU cases without that evidence. See CL1's floor script for frozen commands,
then strengthen its checks to full SHA-256 and verified mode/coverage.

## Ordered tasks

### CL2 — Close deferred-opening correctness and reference-mode gaps

Priority 0; ready; depends on no new queue task.

Owns: `hashline/src/gpu/cuda.rs`, `hashline/src/gpu/mod.rs`, `hashline/tests/zk60_gpu_commit.rs`.

Work:

- Make HL_ZK_CHUNK=0/off strict: resident allocation failure must not enter the chunked path; preserve a visible error/reference outcome.
- Restore the NTT twiddle requirements of each deferred commitment before opening, or establish a tested monotonic sufficient cache.
- Add live large-commitment -> smaller-profile commitment -> original-opening coverage, multiple live commitments, alternating rates and repeated openings.

Acceptance:

- CPU-oracle leaves AND columns agree in every interleaving, including the plain-reencode negative control.
- Forced off cannot report CHUNKED after injected resident failure.
- Small CPU/GPU/forced-chunk frozen artifacts retain full SHA-256 and exact lengths; no transcript/RNG changes.

Limits: Source-inspected defects, not independently GPU-reproduced by Codex. Keep one GPU core writer.

### CL3 — Make allocation fallback complete and memory-bounded

Priority 0; queued; depends on CL2.

Owns: `hashline/src/gpu/cuda.rs`, `hashline/tests/zk60_gpu_commit.rs`, `scripts/hashline_memory_plan.py`, `tests/test_hashline_memory_plan.py`.

Work:

- Cover failures of every resident allocation, including the later d_enc take, with narrowly scoped deterministic failure injection.
- Account for partially successful resident attempts returned to the global pool, oversized take_min reuse, retained pads/powers, hashing scratch and deferred-opening state.
- Extend the resident-only memory planner with explicit resident/chunked/fallback modes and cold/warm-pool states; keep old resident rows unchanged.
- Count helper/zero-check overlap and pending states separately; reconcile the corrected ~13,492 MiB resident W component with the existing planner.

Acceptance:

- Injected failure at each allocation either retries successfully within its stated bound or returns a clear error without leaks, hangs or privacy downgrade.
- Tests distinguish live ownership from pool reservation and allocated capacity from requested scratch.
- Measured small-shape high-water marks are reconciled with conservative bounds; do not use a chunk-only count as a fallback or whole-prover bound.

Limits: Planner ownership explicitly transfers to Claude for this queue; Codex will not edit it concurrently. No destructive global pool draining while another owner still uses state.

### CL4 — Make GPU gates and phase accounting trustworthy

Priority 0; queued; depends on CL2, CL3.

Owns: `hashline/src/gpu/cuda.rs`, `hashline/tests/zk60_gpu_commit.rs`, `scripts/hashline_cl_gpu_gates.py`, `tests/test_hashline_cl_gpu_gates.py`.

Work:

- Remove double charging of secs_ntt between commit_zk_chunked and its caller; define exclusive NTT/hash/transfer/enclosing wall scopes.
- Add an explicitly GPU-required gate: missing feature/device or zero executed cases must fail that gate, not print a vacuous six-test success.
- Emit machine-readable actual case/execution/negative-control counts, device identity, modes and full artifact digests.
- Use process-isolated mode tests; do not mutate cached global GPU/folding settings concurrently.

Acceptance:

- GPU-required mode fails on unavailable GPU; ordinary CPU test suite remains runnable with clearly separate non-GPU status.
- Required hardware run proves nonzero actual cases and negative-control execution under HL_GPU=1.
- Attribution has no duplicate parent/child charging; enqueue/wait/transfer/device intervals are labelled and testable.
- Do not retroactively discard CL1's observed hardware log; correct the gate semantics for subsequent evidence.

Limits: Clock fixes are measurement corrections, not speedups. Do not change existing top-level benchmark eligibility semantics without Codex review.

### CL5 — Map the post-CL1 GPU bottlenecks

Priority 1; queued; depends on CL4.

Owns: `scripts/hashline_cl_profile.py`, `tests/test_hashline_cl_profile.py`, `docs/zkmatrix-poc/ZK60_CLAUDE_PROFILE.md`, `results/cl5_*`.

Work:

- Reuse existing timing/profile collectors rather than create an incompatible headline clock.
- At safe 125M shapes separate witness preparation, cold/warm W commitment, A/H, helper generation, sumchecks, openings, transfers, serialization and verification.
- Include CPU fallback counts and the actual shapes dispatched to GPU; distinguish P0/P1/P3 and warm public W cache from fresh private W.
- Rank the top three exclusive proof-ready costs and calculate bounded Amdahl opportunities without multiplying unrelated speedup factors.

Acceptance:

- Every row carries shape/device/privacy/cache/mode/coverage and command+exit evidence; unknown exclusive time is reported.
- Use small repeated diagnostic runs under lock; no headline p95 unless the machine is quiesced and the publication protocol is met.
- Deliver an actionable optimization order based on the new profile, not old lattice or FFN-only projections.

Limits: GPU execution waits for safe idle hardware; log-analysis/parser work can begin now.

### CL6 — Tune chunk scheduling against both time and memory

Priority 1; queued; depends on CL3, CL5.

Owns: `hashline/src/gpu/cuda.rs`, `hashline/tests/zk60_gpu_commit.rs`, `scripts/hashline_cl_chunk_sweep.py`, `tests/test_hashline_cl_chunk_sweep.py`, `results/cl6_*`.

Work:

- Sweep bounded chunk row choices using the corrected memory/fallback planner and explicit modes.
- If justified, implement a deterministic budget-based chunk selector with a retained fixed reference path.
- Cover ragged final chunks, rates/pads, small and wider rows, commit and re-encode opening cost, and cold/warm pool behavior.

Acceptance:

- All choices preserve leaves, opened columns, full proof hashes and RNG order.
- Selector refuses unsupported/overflowing budgets and never assumes nominal VRAM is free memory.
- Promote only a measured proof-ready or memory-headroom improvement; report regressions and do not hardcode a 5090 speed factor.

Limits: One active cuda.rs writer; no live large-model search on the laptop.

### CL7 — Remove a measured transfer or scratch bottleneck

Priority 1; queued; depends on CL5, CL6.

Owns: `hashline/src/gpu/cuda.rs`, `hashline/src/gpu/kernels.cu`, `hashline/tests/zk60_gpu_commit.rs`, `docs/zkmatrix-poc/ZK60_CLAUDE_RESIDENCY.md`, `results/cl7_*`.

Work:

- Choose one top measured GPU bottleneck, such as helper scratch/zero-check residency or repeated pad/power transfers.
- Build a separately switchable byte-preserving optimization; if using overlap/double buffering, explicitly model event completion, buffer ownership and cancellation/error cleanup.
- Compare the changed phase and end-to-end proof readiness with identical shape/mode/cache/seed; retain the reference path.

Acceptance:

- CPU/GPU parity includes adversarial ragged/interleaved cases and unchanged full frozen proofs.
- Allocation-lifetime and asynchronous cleanup tests accompany any memory ownership change.
- Measured improvement is attributed to the changed fraction; phase-only gains are not reported as full-pass gains.

Limits: Do not alter attention.rs/layer.rs/zk.rs caller semantics; propose any caller change to Codex before editing.

### CL8 — Design GPU support for actual pending private blocks

Priority 1; ready_design; depends on no new queue task.

Owns: `docs/zkmatrix-poc/ZK60_CLAUDE_PENDING_GPU.md`, `scripts/hashline_cl_pending_memory.py`, `tests/test_hashline_cl_pending_memory.py`.

Work:

- Read A03 pending ownership and the A01 executed schedule; enumerate simultaneously retained attention/FFN W/A/H and seam/functionals before the single final opening.
- Build a symbolic count/lifetime tool for one and two pending blocks including pool, pads, helpers, challenge-derived state, host copies and transfer staging.
- Propose GPU handles/finalization APIs with one-shot ownership and immutable commitment identity; identify exact caller interfaces needed by Codex.

Acceptance:

- Every counted buffer has an owner, birth/death event and units; unimplemented dimensions remain symbolic/explicitly unaccounted.
- Small counted examples reproduce existing component counts and detect double ownership/omitted overlap.
- No copied-plane equality or standalone S2 receipt is presented as provenance from real arithmetic.

Limits: Design/tooling can proceed without Fable; private protocol implementation and privacy claims require Fable's actual group/mask audit and Codex interface agreement.

### CL9 — Validate safe public-weight cache reuse across requests

Priority 2; queued; depends on CL2, CL4.

Owns: `hashline/src/gpu/`, `hashline/src/pcs.rs`, `hashline/tests/zk60_gpu_cache.rs`, `docs/zkmatrix-poc/ZK60_CLAUDE_CACHE.md`.

Work:

- Audit existing public W/gamma cache identity and lifecycle; add tests for changed roots, model/calibration parameters, device and interleaved requests.
- Measure cold versus warm P0/P1 weight work using the actual approved public metadata; propose narrow fixes only where tests find an issue.
- Document invalidation, device-state lifetime, capacity eviction and thread/process boundaries.

Acceptance:

- Stale/mismatched approvals cannot reuse an incompatible commitment; equivalent approved public state preserves full proof bytes.
- P3 cannot reuse private hiding commitments, masks or randomness across proofs through this cache.
- Distinguish existing performance behavior from newly implemented improvements; changes outside GPU/PCS require Codex handoff.

Limits: This is public-weight reuse, not a solution to P3 approved-model consistency or the singleton-mask privacy gate.

### CL10 — Measure proof-size and serialization costs before redesign

Priority 2; ready_analysis; depends on no new queue task.

Owns: `scripts/hashline_cl_artifact_profile.py`, `tests/test_hashline_cl_artifact_profile.py`, `docs/zkmatrix-poc/ZK60_CLAUDE_ARTIFACTS.md`.

Work:

- Inventory exact component sizes and serialization copies at supported small public fixtures using existing layouts/codecs and archived logs.
- Separate mathematical proof bytes, framing, repeated public metadata, output-buffer allocation and disk/network transfer assumptions.
- Rank byte-preserving serialization improvements and separately cost protocol-changing compression/PCS proposals against security, decode and verifier budgets.

Acceptance:

- Component totals reconcile exactly to the observed artifact; unknown legacy layouts are refused rather than guessed.
- No candidate compression is called compatible or private without its own codec/security gates.
- Provide a concrete handoff for Codex's codec/CLI owners; do not edit their current receipt modules.

Limits: No sensitive proof exports. Existing compact PCS is not an approved GPU/private substitute; changed security parameters require explicit review.

### CL11 — Prepare the 5090 qualification and measurement campaign

Priority 1; queued_prepare_only; depends on CL3, CL4.

Owns: `docs/zkmatrix-poc/ZK60_CLAUDE_5090.md`, `scripts/hashline_cl_5090_preflight.py`, `tests/test_hashline_cl_5090_preflight.py`.

Work:

- Create a fail-closed operator preflight: named device/driver/toolkit, available host/device memory, idle check, source/build identity, supported shape and planner margin.
- Reuse the existing benchmark collector; provide an ordered small CPU/GPU parity ladder before any wider run, then separate P1/P3 and cold/warm evidence.
- Require complete coverage/decoded verification/security gates before target-eligible claims; existing FFN-only tests stay labelled diagnostic.
- Prepare at least 20 warm-run/p50/p95 collection and generation/proof-ready/proof-lag clocks with explicit one-GPU inference/proving overlap.

Acceptance:

- Dry-run/unit tests reject missing device, unsupported capability/configuration, insufficient headroom, stale binary, unverified artifact and ineligible coverage.
- All heavy jobs use the shared lock and detached logs/markers when expected over five minutes.
- Hardware measurements run only after Victor has the card ready; no rental, purchase, driver installation or risky laptop 8B run is implied.

Limits: Hardware preparation is ready work; actual 5090 throughput is blocked on hardware availability and full supported proof relation.

Machine-readable counterpart: [zk60_claude_tasks.json](zk60_claude_tasks.json).
Codex integrates only reviewed handoffs; Fable's independent review is not
replaced by Claude's GPU work or Codex's parallel reviewers.
