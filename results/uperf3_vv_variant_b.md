# U-PERF3 lane VV — Variant B of the two-tier opening: the record (2026-09-02)

Status: LANE COMPLETE. Variant B (tier 1 of the two-tier opening
committed and folded over the int8 VALUE rings instead of the digit
rings; lane QQ's rung-1 count) was built as a measured spike behind
the `uperf-t count-b | b | repeat-b` selectors and measured against
the original reopen bar: per-proof weight-side opening at the real
12x512 weight group >= 5x faster than the built GPU opening, claims
bit-identical. Ledger: PROGRESS_UPERF3.md "Agent VV status — round
11" (rungs 0-5 with commands, logs and commit hashes). Labels:
[MEASURED] = a run on the named box; [COUNTED] = arithmetic on
measured pieces; [MODEL] = an estimate with stated assumptions. Every
wall here is [WSL-BOX] [8T] [GPU: RTX 4070 Laptop] [NOISY-SHARED]
(three lanes building on the box).

## 1. The verdict at the bar

**NOT MET — 1.77x [MEASURED].** At the real 12x512 weight group
(3,538,944 digit rings = 442,368 int8 value rings, 36 tensors, every
tensor in the value form at e_v = 8), with the per-model part held
warm and n = 5 proofs: Variant B per-proof min 1.24 s / median 1.29 s
vs the built `bg_prove_group` min 2.20 s / median 2.23 s in the same
run (2.31x if the built path's own per-model-class precommit, 0.67 s,
is charged to it). Lane QQ's design of record (R1), re-run in the
same session: 2.14 s / 2.30 s vs 2.11 s / 2.13 s = 0.98x. Claims:
the b_row images byte-identical to the built `GroupEvalProof.b_rows`
in every proof; the Variant-B wire digest 02708a51.. identical across
the 5 proofs. Logs: results/uperf3_vv_repeat_b_realw_8t_gpu.log,
results/uperf3_vv_qq_repeat_realw_8t_gpu_rerun.log,
results/uperf3_vv_b_bench_realw_8t_gpu.log.

Where the 1.24 s goes [MEASURED]: the recursion prove 0.39-0.52 s
(the frozen `bg_prove_group` machinery on the 202,752-ring tier-2
proxy — 1.9-2.6 us/ring, the small regime lane QQ named), the value
fold GEMM 0.24-0.38 s (36 device GEMMs of 1 x 128-192 columns x len
64-96 — launch/pack-bound: 8x fewer rings than the record's fold,
~1.5-2x less wall), the v-pass 0.27-0.35 s (P on the CPU pool
0.11-0.14 + the i8 GEMM 0.12-0.20), rows-from-v 0.08, the pooled
challenge draw 0.08, absorbs 0.06. The bar allows 0.44 s per proof;
the recursion alone is at or above it.

## 2. What was established on the way

1. **The gates hold** [COUNTED, `uperf-t count-b`,
   results/uperf3_vv_count_b.log]: the row-group exact-digit gate at
   (width_v, e_v = 8) has +3.45 / +1.74 / +1.42 bits of headroom at
   12x512 / 8B / 30B (QQ's numbers reproduced exactly), the folded-w
   gate +2.05 / +1.35 / +1.28 (greener than the record's +1.05 /
   +0.08 / +0.02: 8x fewer folded rings beat the 2^7 larger fold
   bound), the tier-2 gate unchanged. Finding F0: the value form does
   not extend to act-class tensors (the 2^22 synthetic's td, values
   to 2730, e_v 13: -1.76 bits), so the form is chosen per tensor by
   a public rule (value iff the gate is green, else the record's
   digit form).
2. **Soundness** (ledger rung 1): the tier-1 binding over value rings
   is AGGREGATION_PARAMS_DESIGN.md §3.2-3.4's exact-digit fold-norm
   law + the 58.8 extraction slack at base e_v = 8 — a new PARAMETER
   row (and a class-table row {int8-value: e0 8, l0 1}), not a new
   lemma; the MSIS instance has 8x fewer columns at the same kappa
   and beta_top. What IS new is a PROTOCOL OBLIGATION: the int8 range
   fact of the value tier is not given by the fold norm (a relaxed L2
   bound) and must live in a per-model certificate (the digit planes'
   alphabet facts + the F-N2 recomposition RingClaims + a SECOND
   opening of the value-tier commitment — an E-O2-BB ruling) or a
   per-proof 256-row range-table lookup. Neither is built (FF's spike
   did not build the record's range facts either).
3. **Bit identity** [MEASURED]: DIFF 1-3 vs the built opening at 2^20
   and 2^22 (CPU) and 2^20 (GPU); the v plane and b_rows byte-
   identical to R1's; the value fold as one GEMM == the combine-class
   fold; 7 reject legs incl. a lying VALUE ring (re-committed,
   honestly refolded, fold-binding and U rebind pass) -> consistency.
4. **Two attribution corrections to QQ's per-proof clock**
   [MEASURED]: (a) ~0.3-0.5 s of it was the per-contrib H_m
   reconstruction — differential bookkeeping, not protocol; (b) the
   fold's "host tail" 0.38 s was the serial quinary CHALLENGE DRAW
   (3,072 rings at ~120 us each, proportional to G_all), not the
   absorb; the real tail is 0.01 s. Both are out of the Variant-B
   clock (the draw pooled: 0.08 s, value-identical).
5. **The device rows at the synthetic shapes** [MEASURED, GPU 8T]:
   Variant-B core 1.78 / 2.51 s vs bg_prove_group 2.00 / 3.46 s at
   2^22 / 2^23 = 1.12x / 1.38x (R1: 0.85x / 0.93x).

## 3. The measured constants (12x512 weight group, GPU 8T NOISY)

| constant | value | source |
|---|---:|---|
| K1' per-model (layouts + tier-1 u over value rings + U) | 2.14 s (4.8 us / value ring — launch-bound at width_v 128-192) | repeat-b; QQ's record 2.43 s same session |
| K2 v GEMM, i8 operand, short K | 4.5-7.5 G D-MAC/s (0.12-0.20 s / 9.06e8); C1 74 G/s at len ~1800 [MODEL] | unchanged from QQ |
| K3 P precompute (CPU pool) | 1.3-1.6 G MAC/s (0.11-0.14 s / 1.76e8) | unchanged |
| K4' fold-as-GEMM over VALUE rings | 0.54-0.86 us / value ring (0.24-0.38 s / 442,368) — launch-bound; the record's K4 119 ns / digit ring is the C1-regime bound | repeat-b |
| K5' fold tail (bound check + poly_from_small + absorb) | 1.9 us / folded ring (0.01 s / 5,376) | repeat-b (QQ's 8.8 us was the draw) |
| K6 recursion prove, small regime | 1.9-2.6 us / ring (0.39-0.52 s / 202,752); C5 0.62 at 11.4M | repeat-b |
| K7 rows-from-v | 1.1-1.25 G MAC/s | unchanged |
| K8 the built bg_prove_group on the device | 0.62 us / digit ring (2.20 s / 3,538,944) | this session (QQ 0.59) |
| K9 QQ's "residual" | RESOLVED: h_ms bookkeeping (0.3-0.5 s) + the serial draw (0.37 s) | b diff / repeat-b |
| K10 challenge draw | 120 us / ring serial; 23-29 us / ring pooled at 8T | repeat-b |

## 4. The projection for lane TT (per-proof weight side; [MODEL] = the constants above x the counted sizes; ranges = the C1..launch-bound GEMM classes x the C5..small-regime recursion)

| shape | per-MODEL (once) | v GEMM + P + rows | fold GEMM + tail | draw (pooled) | recursion (proxy u digits) | absorbs | **per-proof TOTAL** | built opening | ratio |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 12x512 W [MEASURED] | 2.14 s | 0.27-0.35 + 0.08 | 0.24-0.38 + 0.01 | 0.08 | 0.39-0.52 | 0.06 | **1.24 s (min) / 1.29 (median)** | 2.20 / 2.23 s | **1.77x** |
| 8B W (352.3M digit rings = 44.0M value rings; G_all 23,552; n2 2.07M) | ~30 s | 1.2-12 + 4.4 + 0.7 | 5.2-24 + 0.3 | 0.6-0.7 | 1.3-5.4 | ~0.5 | **14-48 s** | ~210-218 s | **4.4-15x** |
| 30B W (ASSUMED 64x5120x25600; 1.57G digit rings; G_all 66,560; n2 8.05M) | ~130 s | 5.4-54 + 14 + 2.0 | 23-106 + 1.1 | 1.5-1.9 | 5.0-21 | ~1.4 | **54-201 s** | ~930-975 s | **4.6-18x** |
| (the record, QQ rung 5, for contrast) 8B W | 233 s | same | 42 + 13 | (in K5) | 1.3-3.5 | — | 62-75 s | ~210 s | 2.8-3.4x |

Reading: the 12x512 measurement lands at the LOW end of the count's
[MODEL] range for that shape (1.8-2.5x, rung 0) because the two
GEMM-class terms (the value fold, the tier-1 commit) are launch-bound
at width_v 128-192 and the recursion is in its small regime. At 8B
and 30B the rows straddle the bar (4.4-15x, 4.6-18x): Variant B
removes most of the fold, which was 73% of the record's 8B clock, but
whether the fold GEMM runs at the C1 class (119 ns/ring) or stays
launch-bound (0.54 us/ring) at 8B widths is exactly what no
measurement on this box can settle — the 8B shape does not fit 15 GB.
The lattice-line band in U_PERF3_THROUGHPUT_MODEL.md §2.4/§4 (0.5-3
tokens/s at 30B prefill on one H100) does NOT move on this result:
the 12x512 bar is not cleared, and the 8B/30B rows are [MODEL] on
measured constants whose regime changes with the shape.

## 5. Not measured (honesty)

The act-side opening (the value form does not apply to act-class
tensors: F0); the verifier (2.15 s at the weight group; the
consistency check is 36 tensors x 16 x width_v ring products — the R2
recursed serving was never built); the bytes (45.7 MB spike-clear vs
180 KB built — the clear u/v planes); the per-model weight certificate
(the int8 range fact of the value tier; ledger rung 1 item (5)); a
quiet box; a desktop board or an H100; a fused / batched fold kernel
that would take the 36 small GEMMs to one launch (the other way to
remove K4' at 12x512 — not built, and it does not touch the
recursion floor).

## 6. Ruling items for Victor (none frozen; the spike is selector-gated)

1. The class-table row {int8-value: min -128, max 127, e0 8, l0 1}
   (UAGB1-1a semantics) if Variant B is ever adopted.
2. The per-model weight certificate: a second opening of the
   value-tier commitment (E-O2-BB) or the per-proof 256-row lookup.
3. The pooled challenge draw (`tt_draw_cs_par`) as a prover-side
   form — value-identical to the frozen serial draw; the verifier's
   replay is unchanged.
