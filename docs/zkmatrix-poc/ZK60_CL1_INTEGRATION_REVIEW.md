# CL1 integration review — hold pending follow-ups

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
