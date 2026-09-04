# The layer.rs plane -> Fp conversion — lane AL, round 15 (lever L2b)

Status: RUNG 0 (the plan and the baseline). WSL box (Core Ultra 9 185H,
8 threads, 15 GB) + RTX 4070 Laptop GPU (8.19 GB, sm_89). Every number
labelled [MEASURED] was run on THIS tree; numbers labelled [AJ] are lane
AJ's, quoted as the target and NOT re-derived.

## 0. The item, and why it is a lane

Lane AJ (`results/hashline_hostwall_gpu.md`) built and gated every host
item the 60 tok/s plan named and the 8B pass moved 88.90 -> 86.00 s
(1.034x). Its §7 says exactly why: **the single largest host item in the
pass was never in AJ's ownership.** `prove_layer_v3` in layer.rs builds
`w_data` (1.4 GB at the Mistral shape) and `a_data` (0.46 GB) element by
element with `Fp::from_i64` before any device code sees them, and folds
the two matmul terms over `w_data` on the host. AJ's close:

* **38.7 s of the 86.00 s prove is host time inside the prove clock, and
  essentially all of it is in layer.rs** [AJ]:
  * the conversion **and the two allocations**: ~29 s over 32 layers,
  * the host matmul folds: **8.1 s measured directly**.
* Ceiling if both go away: **~1.82x on the prove** [AJ].
* The device half already exists and is on the live path: AJ's `k_widen`
  reconstructs field elements from packed signed integers on the device,
  and the narrow upload is ON by default (59,861 -> 9,328 MB uploaded).

## 1. What is actually possible, given the ownership

`gpu/*` is READ-ONLY for this lane and `Pooled::take` (the only way to
get a device buffer) is private to `gpu/cuda.rs`. So the device commit
entry this lane can call is `dev_commit(params, data: &[Fp], ntt)` —
**a contiguous `&[Fp]` of the whole matrix is unavoidable.** The int8
planes cannot be handed to the device without a new `gpu/*` entry point,
which belongs to whoever owns that file next.

That leaves three levers, all inside `layer.rs` + `pcs.rs`:

1. **Kill the ALLOCATION, not just the conversion** (the coordinator's
   point 1). `vec![Fp::ZERO; lay.w_len]` is a fresh 1.4 GB mmap every
   layer: 344k first-touch page faults, then `munmap` at the drop, then
   the same again next layer. A microbenchmark of exactly this shape on
   this box (`176,160,768` u64, 8 threads, fill from an i8 plane)
   [MEASURED, 2026-09-04, QUIET]:

   | form | fill s |
   |---|---:|
   | fresh `vec![0u64; N]` each round | 0.1376 / 0.0973 / 0.0912 |
   | one buffer reused | 0.0908 / **0.0414** / **0.0411** |

   Reuse is **2.2-3.3x** on the fill in isolation and removes the
   allocation entirely; under the real pass (RSS ~4 GB, 9 GB of page
   cache, reclaim pressure) the fault side is expected to cost more than
   it does idle, which is the gap between this 0.14 s and AJ's 0.92 s.
2. **The two host matmul folds read `w_data` (1.4 GB of Fp) when the
   same numbers are 176 MB of int8.** `fold_cols_base` over a `w_data`
   block equals a strided `fold_cols_i8` over the source plane, exactly
   (the field arithmetic is modular and exact, so re-ordering and
   skipping zeros cannot move a bit). 8x less memory traffic.
3. **The pre-sumcheck `fold_cols_i8` over the whole plane duplicates the
   block folds.** `wgk[k] = sum_j lam_f[j/fb].mul(eq_rj[j%fb]) * v` is
   `sum_b lam_f[b] * (block-b fold)[k]`; both passes read the same
   58.7 M int8 elements. Fusing them is one pass instead of two and is
   exact by associativity of the field multiplication.

## 2. The rungs

* **RUNG 0** — instrumentation (`HL_CONV_VERBOSE=1`) that charges the
  alloc, the fill, the commit call, the device counters inside it, and
  the two fold phases separately, plus the baseline on this tree. No
  behaviour change. (This document.)
* **RUNG 1** — the conversion: a reusable host staging buffer for
  `w_data` and `a_data`, so that no layer after the first allocates.
* **RUNG 2** — the folds: the block folds from the int8 planes, the
  pre-sumcheck plane fold fused into them, and `w_data` released as soon
  as the commitment holds it.
* **RUNG 3** — the twelve byte gates on both binaries
  (`results/hashline_convert_floors.sh`, copied in invocation from
  `scripts/floors_round13_merge.sh` and AJ's floors script), then the
  32x512 8B pass BEFORE and AFTER in one session with a fresh `--wcache`
  directory in each arm.

## 3. THE ACCEPTANCE

Byte-preserving, absolutely: v2 `50cf7bdfd6b5b182..` 66,844,928 B; v3
`5f368db6240e0614..` 70,758,084 B; zk-v2 `021485e4f80ec695..`
87,228,528 B; zk-v3 `40eb54795e023c77..` 87,697,008 B, on BOTH binaries;
the one-Mistral-layer proof `179ec2fb8f99d0d6..` 38,688,700 B; the 8B
proof `dc980e81..0085b2dd`, 1,234,936,956 B. A speedup that moves any
digest is a bug.

Note that the 12-layer gates are themselves the test of rung 1: a reused
buffer that is not fully overwritten would leak the previous layer's
weights into the commitment and move the digest on layer 1 of 12.
