# CL1 integration review — hold pending follow-ups

## Latest: round-8 review at `a1aa2b7`

The [round-8 review](ZK60_ROUND8_CLAUDE_REVIEW.md) supersedes the earlier
warm-fallback and Python-parser blockers. All 215 pinned Python tool tests
pass and all fifteen archived CL5 matrix rows pass the hardened parser.
New CL6/CL11 evidence checks remain in the queue; Codex takes the explicit
CL9 atomic-cache publication handoff. Final GPU integration still requires
a successful combined-source floor run. Its attempted launch deadlocked by
acquiring the build lock both outside and inside the floor script; Codex
stopped only the blocked waiter with approval and preserved exit marker 1.
Relaunch under the heavy lock only. See the linked review for exact evidence.

## Planner follow-up reviewed: `9b24975` (2026-09-06)

Pinned commit `9b249755e4bc14447578111e28df080ed5f0785b` fixes the
previous chunked/fallback capacity double counting and chunked return
lifetimes. Each reused capacity now transfers ownership, scratch returns to
the pool, raw leaves are freed, and the commitment retains data/pads/powers.
Warm states have explicit inventories; the old additive result is separately
labelled as a no-reuse bound. The single-chunk, non-multiple-of-128 case is
also corrected. Codex independently ran all **25 planner tests**, including
the numerical reconciliation with the prior device counter report. This is
CPU verification of the accounting, not a new device measurement.

One reachable-input inconsistency remains: `commitment_plan(300,10,4,16,
mode="fallback",pool_state="warm-resident")` reports a refused 9,830,400-byte
exact take while its own snapshot contains an available pooled buffer of
exactly 9,830,400 bytes. CUDA's `pool_take` returns that buffer before checking
fresh-allocation refusal. The simulation unconditionally invents the late
failure. Refuse an unreachable fallback scenario or simulate the successful
resident path when the exact buffer exists; add that boundary case. The
reproduction is in [the review record](../../results/zk60_round7_claude_review.json).
Explicit inventories beyond the actual 64-buffer pool limit should also be
refused or have their drop/eviction behavior modelled.

The earlier planner double-counting/return-lifetime findings are superseded
by this response. CL4's parser and final-source evidence gate below, and the
CL5/CL8/CL9/CL10 follow-ups, remain open. No lane source was edited or merged.

## Follow-up reviewed: `c346236` (2026-09-06)

Pinned commit `c346236b4b90bb6583c8d0a8d7b82d0da3896004` responds to the
round-7 findings below. Source review credits the individual raw-allocation
notes (including leaves), successful fresh-allocation byte counters and reuse
capacity/request counters. The rewritten reuse test asserts exact byte totals
and disables reuse as a numerical negative control. Its capacity counter is
cumulative reuse traffic, including buffers served again for opening; it is
not a unique physical-allocation peak and must not be used as one.

The missing-feature refusal is also fixed. Codex compiled the pinned test
file without the GPU feature and independently checked both outcomes: unset
requirement passes with zero executed GPU cases; `HL_GPU_REQUIRED=1` fails
with exit 101 and the intended reason. No GPU was used for those checks.
Evidence is appended to [the review record](../../results/zk60_round7_claude_review.json).

**New CL4 blocker, reproduced without running the GPU gate:** the embedded
Python oracle-summary parser in `results/cl1_floors.sh` does not compile on
the repository's Python 3.10. Its f-string expressions contain `\"` escapes,
raising `SyntaxError: f-string expression part cannot include a backslash`.
Thus an honest oracle run cannot make the complete revised floor script pass.
Assign `s["executed_cases"]` and `s["device"]` to variables before the f-string,
or use a separately tested helper. Compile/test the embedded parser before
launching the next full floor run.

The script now records binary hashes and retains oracle/prover logs. For final
source attribution require a clean checkout or content hashes of dirty build
inputs: HEAD plus a dirty-file count alone cannot identify those inputs.
After fixing the parser, retain a successful full gate on the final source.

The CL3 planner lifetime/reuse gaps below are not changed by this commit, and
the [CL5/CL9](ZK60_CL5_CL9_REVIEW.md) and [CL8/CL10](ZK60_CL8_CL10_REVIEW.md)
follow-ups remain. Source integration is still held; later uncommitted work
in Claude Fable's lane is excluded. The three Codex H1 tests have meanwhile
been isolated in this continuation and pass with sixteen test threads.

## 2026-09-06 continuation: reviewed `39272d6`

Read-only Codex review of the committed CL3/CL4 response and archived evidence
at `39272d6`. Claude subsequently merged `9cf1372` into its lane as `25f8b6d`
while this review ran; that merge does not change the reviewed GPU files.
No GPU reproduction or source integration was performed here.

The response fixes shared `take_min` injection, adds one-shot allocation
failure, checks leaves/columns from the actual fallback probe, mirrors chunk
rounding, removes the chunked caller's double timing charge and strengthens
the byte-gate script. `results/cl4_floors.log` records twelve full-SHA-256
matches and an all-green verdict; its exit marker is separate evidence.
Retain those fixes and the recorded results. The previous missing-`take_min`
and routing-only-probe findings are superseded.

Remaining acceptance gaps are concrete:

| Finding at this pin | Required follow-up |
|---|---|
| `gpu/cuda.rs` calls `note_raw_alloc` only for pads+powers and gather output+indices. `commit_zk_chunked`'s `d_leaves` allocation and the resident hash leaves are not counted. Each note also combines two allocations into one counter increment. | Instrument each allocation separately, including leaf buffers, or explicitly rename/narrow the metrics. The reported 2 events / 109,632 bytes is not total raw allocation count/capacity. |
| `the_chunked_retry_reuses_pooled_capacity_rather_than_allocating_more` permits up to 3 fresh pooled allocations and checks only `raw_n > 0`. A full fresh scratch pair plus hash state could satisfy that count. Its illustrative `full_pair_elems` also uses `1<<16` despite this probe's encoded width `1<<12`. | Assert actual allocated byte sizes and reused buffer capacities, with a negative control that disables reuse. A count of allocations does not bound their capacity. |
| Planner fallback stages still add retained resident buffers and requested chunk scratch as distinct capacity even when `take_min` transfers ownership of the same allocation. | Model ownership of actual buffer capacities across reuse, counting each once, or label this explicitly as a conservative no-reuse bound rather than an accurate fallback lifetime model. |
| Planner chunked return omits scratch returned to the pool, includes device leaves already dropped by the callee, and sets `new_pool_bytes_after_return` to zero. A warm flag has no inventory distinguishing a resident-warmed pool from one containing all chunk shapes. | Correct return lifetimes and pool retention; make warm-state assumptions explicit and tie new allocation estimates to the available sizes. Keep `safe_to_run=false`. |
| The oracle test file is wholly `cfg(feature="gpu-cuda")`: requesting `HL_GPU_REQUIRED=1` without the feature still compiles away every test. The floor script uses the feature, but captures successful oracle output without `--nocapture` and never checks its emitted case summary. | Supply a fail-closed entry point for the missing-feature case and retain/check visible actual case/device counts. This gap does not negate the archived script's twelve byte gates. |

The archived script does check subprocess success, an ACCEPT line, GPU-enabled
logging, fresh artifacts and full digests. It still does not persist binary
hashes or inspect the oracle's executed-case summary, and it removes individual
successful proof logs. Preserve exact source/binary identity and complete oracle
evidence for the final integration gate. The subsequent
[CL5/CL9 review](ZK60_CL5_CL9_REVIEW.md) records new CPU reproductions and
required follow-ups for their delivered handoffs, plus Codex's fix for the
test-configuration race exposed by Claude Fable's combined-suite run.

Integration remains held on the allocation/lifetime and final evidence gates.
These findings are documented for Claude's lane; no GPU/PCS/planner files were
edited and no full-model laptop run was launched.

## Round-6 follow-up: pinned `6e28b6f`

Reviewed commit: `6e28b6fe780bbc19151986ecf024907b52a018a1`.
Claude's concurrent uncommitted CL4 edits were deliberately excluded. This
is a read-only source/evidence review, not independent GPU reproduction.
**Integration remains held**, with these concrete follow-ups for Claude:

| Task | Evidence at this pin | Remaining acceptance |
|---|---|---|
| CL2 | Strict off refuses resident allocation failure; twiddle cache is monotonic and has prefix/interleaving tests. | Keep the fixes; rerun their GPU-required gates with the final combined source. |
| CL3 allocation | Late `d_enc` now retries chunking. `pool_take` counts/injects fresh allocations, but `pool_take_min` directly allocates outside that counter/cap. | Instrument all intended allocation paths or narrow the assertion. The current counter cannot establish that chunk fallback makes no fresh allocation. Include raw pads/powers/leaves in capacity accounting. |
| CL3 correctness | Injected-failure probe returns only `dc.enc.is_none()` and discards leaves. | CPU-check leaves and opened columns from the **actual injected-failure path**, not just its routing flag. |
| CL3 planner | New resident/chunked/fallback modes exist. | Mirror the device's minimum/rounded 128-row chunk plan; count oversized reused buffers once, with their actual capacity. Fix warm-pool zero-allocation claims (raw allocations remain), resident-only post-return fields/assumptions and missing CLI mode controls. |
| CL4 | Chunking still adds time inside `commit_zk_chunked` and again in its caller; GPU tests still return success without a device. | Finish exclusive attribution and process-isolated, fail-closed GPU-required execution with visible case/device counts. |
| CL4 evidence | `results/cl1_floors.sh` compares only 16 hex characters and does not inspect each proof subprocess's exit code. `cl2_floors.log` retains shortened digests. | Record/compare **full SHA-256**, fresh artifacts, subprocess success, verifier success, actual device execution, source/binary identity and exact case count. |

Relevant pinned paths: `hashline/src/gpu/cuda.rs` (`pool_take`,
`pool_take_min`, `commit_zk_chunked`, `dev_commit_zk_from_probe`),
`hashline/tests/zk60_gpu_commit.rs`, `scripts/hashline_memory_plan.py`
and `results/cl1_floors.sh`. Line numbers in a live Claude checkout may move.

The fallback planner's double counting is generally conservative, but it is
not an accurate lifetime model; the too-small chunk-row count can undercount.
Neither should be used as a whole-model launch authorization. CL8's symbolic
pending-state inventory and CL10's artifact inventory are separate supporting
work, not completion of these gates or private-block implementation.

## Original review (historical source)

Source reviewed at `15eeda6`; observed branch `zk60-cl1` subsequently reaches
`c9fc897` with docs-only changes. The later report corrects pool accounting:
the resident W component is about **13,492 MiB**, not the original 12,142 MiB.
`drop(Pooled)` returns a buffer to the pool, not to the driver. Include that
correction in any integration; do not freeze the stale report as authoritative.

Codex's independent reviewer inspected the actual code and tests. The lead
also inspected the affected allocation/opening paths. **No independent GPU
reproduction was run in this review.** The pad/coset re-encoding and streamed
row hashing look consistent with the CPU construction; Claude's recorded
positive byte gates remain useful evidence. These findings are follow-up
correctness, resource and measurement gates, not a whole-proof privacy audit.

| Finding at the reviewed source | Required follow-up |
|---|---|
| `gpu/cuda.rs:2680`: resident allocation failure enters chunking even with `HL_ZK_CHUNK=off` | CL2: preserve a strict reference mode and test failed allocations under off |
| `gpu/cuda.rs:2705`: the later `d_enc` allocation uses `?` rather than retrying chunking | CL3: cover all resident allocation sites with deterministic failure injection |
| Successful partial resident allocations return to the pool; `take_min` can reuse oversized buffers as chunk scratch | CL3: fallback cleanup and bounds must include retained pool capacity, not only requested chunk sizes |
| `dev_columns` at `gpu/cuda.rs:2003` opens retained state without restoring its NTT table requirements, while `ensure_twiddles` can install smaller tables | CL2: test large commitment → smaller-profile commitment → original opening; restore sufficient twiddles or prove a monotonic cache invariant |
| `commit_zk_chunked` at `gpu/cuda.rs:1258` and its caller both add elapsed time to `secs_ntt` | CL4: exclusive, nonduplicated timing attribution |
| `tests/zk60_gpu_commit.rs:22` returns success without a device; ordinary test capture hides the skip message, and the documented command omits `HL_GPU=1` | CL4: a separate GPU-required gate must fail if no device/cases executed and expose case counts |

These are source-derived exceptional paths, not claimed practical attacks or
evidence that the archived GPU run did not execute. Do not promote the branch
unconditionally until a corrected handoff and targeted adversarial tests are
reviewed. Keep the existing CL1 work; do not discard its commits or change its
results to match a desired conclusion.

The later report's prediction that a 32-layer FFN-only run should fit is not
permission to launch it on this repeatedly frozen laptop. Current continuation
keeps that as a separate safety decision and does not run it. Nor does a
four-layer FFN peak bound as-yet unimplemented pending attention/FFN states.

See [the expanded Claude queue](ZK60_CLAUDE_QUEUE.md) for ten concrete tasks,
ownership, dependencies and acceptance checks. This review performs no merge.
