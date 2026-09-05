# CL1 integration review — hold pending follow-ups

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
