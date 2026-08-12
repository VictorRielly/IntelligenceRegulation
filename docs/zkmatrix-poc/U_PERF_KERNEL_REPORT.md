# U-K9 Kernel Report (B-D3) — measured, and what the measurement does NOT license

Status: written 2026-08-12 by the orchestrator, completing lane PA's
B-D3 deliverable after the lane agent terminated early (usage limit,
not a technical failure). Lane PA's code (B-D1/B-D2) and its
uk9-bench instrumentation are its own work, verified and merged at
b09c080; this report is the missing measured write-up, produced from
runs on the merged tree. It answers the brief PROGRESS.md B-D3
opened as `U_K9_KERNEL_REPORT.md` (renamed to the U-PERF lane's
filename; that item may be ticked against this file).

All numbers [MAC-BOX, non-reference — Apple silicon, NOT the
contract's WSL2 Intel reference box], single-threaded (1T), quiesced
unless flagged. The yardstick is `ring_matmul uk9-bench <log2_n>
<mode>`, which replicates lookup-bench's workload exactly (same
seeds, same shape); `lookup-bench` itself was left untouched as the
historical yardstick.

## 1. The rate (B-D1)

At N = 2^18 = 262,144 int8 SiLU lookups, one instance:

| mode | prover lookup total | rate | vs scalar | incl. verify |
|---|---:|---:|---:|---:|
| scalar (the oracle) | 2.350 s | 8,965 ns/el | 1.00x | 9,286 ns/el |
| bulk | 0.599 s | 2,284 ns/el | **3.93x** | 2,399 ns/el |
| stream | 0.582 s | 2,221 ns/el | **4.04x** | 2,348 ns/el |

Rate is scale-stable (mode stream): 2^20 = 2,154 ns/el, 2^22 =
2,161 ns/el.

**The differential floor is MET.** The root+transcript digest is
`979e4d82b4db7f6d` for scalar, bulk, stream AND the shipped default
at 2^18 — bit-identical transcripts, so this is a pure rate change,
not a semantic one. `freeze-check` passes with every pre-existing
digest unmoved; the digit, ixf-fold, agg-matmul and m125 batteries
are green at this HEAD, as is the full suite (80/80).

Primitive attribution (`uk9-bench <n> prims`), per K-mult:

| primitive layer | ns/K-mult | factor |
|---|---:|---:|
| scalar baseline | ~230 | 1.00x |
| packed eager (SoA, `%` discipline) | 148.4 | 1.55x (layout/lanes) |
| packed lazy (the shipped kernel) | 103.2 | 1.44x (reduction discipline) |
| | | **2.23x total on the primitive** |

The primitive's 2.23x versus the workload's 4.04x: the remainder is
allocation and layout at the layer level (in-place packed fold,
in-place eq doubling, streamed leaves), which is where B-D1's
non-primitive half and B-D2's construction change land.

## 2. Memory (B-D2)

Peak RSS, mode stream, measured with `/usr/bin/time -l`:

| N | peak RSS | recorded pre-U-K9 figure |
|---|---:|---|
| 2^20 | **0.64 GiB** | ~1.5 GiB (PROGRESS.md "Key facts") |
| 2^22 | **2.54 GiB** | (CLI cap; not separately recorded) |

The 2^20 point is ~2.3x below the figure the U-K8/U-K9 ledger
recorded for the same shape — the streamed-leaf construction is
doing what H-03 asked of it. Two honesty notes: (a) the historical
1.5 GiB was measured on the 15 GB WSL2 box under a different
allocator and is a cross-machine comparison, so treat the ratio as
indicative, not as a certified 2.3x; (b) the ledger's "2^23 ~ 12 GiB
does not fit" wall is NOT re-measured here — this box has 256 GB, so
re-measuring it would prove nothing about the deployment box. The
deployment-wall arithmetic stands as recorded.

KElem stays `Vec<u64>` (not the inline `[u64;16]` B-D2 sketched):
`ring_matmul` binds `...to_vec()` at call sites, so an inline KElem
is not source-compatible; the SoA win is delivered where it pays, in
the layer tables. Recorded as a deviation from the original B-D2
wording, not a gap.

## 3. What this does NOT license (finding PA-F1)

**The 4.04x does not reach the 125M rig.** Measured on the merged
tree, layer 0 of the m125 pass at T = 512, against lane BJ's
post-BF-F3 baseline:

| phase | BJ baseline (pre-PA) | this HEAD (post-PA) |
|---|---:|---:|
| prove | 250.4 s | 250.7 s |
| ... lkp (masked descents) | 35.1 s | **35.2 s** |
| ... waves | 199.5 s | 199.8 s |
| wall (incl. 12-layer chain load) | 330.7 s | 328 s |
| data cms / pins | 16,551 / 904 | 16,551 / 904 |

An A/B build at 323aa59 (the merge point immediately before PA)
measured the same 328 s wall — PA is **exactly neutral** on this
workload. (An earlier orchestrator reading of "regression" came from
comparing wall against BJ's prove-phase number; the A/B settled it.)

Why the win does not transfer: uk9-bench replicates lookup-bench's
workload, whose K-arithmetic evidently enters through different call
sites than the rig's masked descents. BF-F3 had already halved that
phase (69.9 -> 35.1 s) by cutting tree work rather than K-mult rate,
and what remains there is not K-mult-bound in the way the bench is.

**Consequences, binding on any future claim:**
1. No end-to-end speed claim may cite the 4.04x. The honest sentence
   is "4.04x on the lookup-core microbenchmark, 0% on the 125M layer
   prove."
2. The ladder's kernel-grade line (0.5-1 us/el [MODEL],
   RING_MULT_BOTTLENECK.md) is approached but not met: 2.2 us/el is
   still 2-4x above it, and the remaining axes — SIMD width beyond
   what NEON autovectorization gives, and multithreading — are
   untouched and unclaimed here. The AVX2 arm is x86-only and dead
   code on this box.
3. The prize is elsewhere: at the 125M layer, descents are 14% of
   prove and **waves are 80% (199.8 s)**. U-PERF lane PC owns the
   wave path and reached only its profiling skeleton; that share,
   not the kernel, is the next round's target. Finding the rig's
   actual descent call sites and converting them is a real but
   second-order follow-up.

## 4. Status of the B-D items

- **B-D1** (lane-packed bulk slot arithmetic + lazy reduction in the
  hot loops): LANDED and measured above; differential green.
- **B-D2** (memory refactor, streamed layers, RSS at 2^20/2^22):
  LANDED with the KElem deviation recorded; RSS table above.
- **B-D3** (this report): LANDED. PROGRESS.md's three U-K9 boxes may
  be ticked against b09c080 + this file, with PA-F1 carried forward
  so the tranche is not remembered as an end-to-end win.
