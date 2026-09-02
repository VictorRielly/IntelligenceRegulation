# U-PERF3 lane WW — the 12x512 Stage-A reference on the laptop (round 11)

Status: rungs 0-4 done 2026-09-02. Machine: the WSL laptop (Core Ultra
9 185H, `ZK_THREADS=8`, RTX 4070 Laptop GPU 8.6 GB VRAM, 15 GB RAM),
`[WSL-BOX] [8T] [GPU] [NOISY-SHARED]` — lanes UU/VV built and benched
on the box all day. ONE binary per row set (the lane's final commit,
`--features gpu-cuda`), `ZK_GPU=1`, the 125M WSL export
(`M125_EXPORT_DIR`), `/usr/bin/time -v` for the peaks. Labels:
[MEASURED] unless marked [COUNTED] / [MODEL]. Every wall below is from
a named log under `results/uperf3_ww_*`.

This page is the row the round-10 ladder could not take on this box
(lane RR's rung 4, deferred: the Stage-A driver OOM-killed the 15 GB
box in both modes under GG's claim transport). It is in lane TT's form
(`U_PERF3_THROUGHPUT_MODEL.md` §2.1 / §4.1): the reference shape,
the prover clock, the sources.

## 1. The A/B at 12 layers x 512 tokens (the reference shape)

| leg | commit | prove | verify | total | bytes | claims | peak RSS | transcript identity | log |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| ORACLE = the built pass, standalone (`uperf-pc full-profile 12 512`) | 3.3-3.6 | **16.9-17.7** | 3.8-4.4 | 24.6-25.7 | 1,509,911 | 64 rows | **2,833 MiB** | EVAL-PROOF DIGEST 4c259008.. (unchanged by every commit of this lane) | r1_12x512_frozen_gpu, r1_frozen512_after_k9fix, r3_12x512_frozen_rep3 |
| ORACLE in the SAME process as Stage-A (`uperf-a pass 12 512 range`, the oracle leg) | 3.3 | **18.2-18.8** | 4.1-4.2 | 25.6-26.3 | 1,509,911 | 64 rows | (process 7,158 MiB, both legs) | k9 warm: the ixf module opens 5 x 4.06 GB, descents on the device | r1_12x512_ab_fixed_verbose, r3_12x512_range_ab_rep1 |
| STAGE-A RANGE (planes + device zc aggregate + the BATCHED transport = the round-11 default; the kept SiLU descents on k9) | 6.4-7.1 | **18.8-19.1** | 4.6-5.0 | 30.3-31.0 | **670,891** | 455 | **7,152 MiB** (nooracle) | statement ee87f414.. / transcript e0b3b985.. (== RR's leg C) | r2_12x512_range_nooracle_diet, r3_12x512_range_ab_rep1 |
| STAGE-A FULL (range's planes + the SiLU lookups on the kappa-4 partial-fraction helper, SS's V3 = ruling 2; the round-11 diet) | 6.2-7.3 | **74.5-82.9** | 10.4-14.6 | 91-105 | **900,003** | 427 + 14 | **7,156 MiB** | statement c6f1850a.. / transcript 8d1ef1a8.. | r2b_12x512_full_compact, r3_12x512_full_rep1/2 |

Outlier, recorded: `r3_12x512_range_ab_rep2` — the in-process oracle
leg's masked-GKR descents took 140.8 s (x20; 6.6 s in rep 1) with k9
live and no device error; its Stage-A leg was +20% too; no concurrent
process found in the sibling lanes' result timestamps; treated as a
NOISY-SHARED contamination (the three other in-process oracle runs
agree at 18.2-18.8 s).

The 2026-08-18 QUIET reference for the oracle is commit 2.5 / prove
15.5 / verify 1.7 (21.0 s wall, 6.7 GB before the round-6..9 diets)
[MEASURED, S1]; today's NOISY-SHARED standalone is 3.3 / 17.3 / 4.0
(26.1 s wall, 2.8 GB). Ratios below use the same-session pairs only.

## 2. The reading (for `U_PERF3_THROUGHPUT_MODEL.md` §2.3 (b))

1. **Stage A in range mode is at prove parity with the built pass at
   the reference shape on the GPU**: 18.8-19.1 vs 18.2-18.8 s in the
   same process (1.02-1.03x), vs 16.9-17.7 standalone (1.08-1.11x).
   Commit +3.1-3.5 s (the planes tensors: groups+planes 1.45 + witness
   1.62 + precommit act 2.37 s vs the oracle's 3.3 total), verify
   +0.5-0.8 s. TOTAL 30.3-31.0 vs 25.6-26.3 s = **1.15-1.18x** (the
   planes commit is the whole excess, as RR found at 12x128). Prover
   clock (commit + prove): 25.2-26.2 s vs 21.5-22.1 s in-process ->
   **1.1e9 vs 1.3e9 proven MAC/s** [COUNTED, 2.9e10 MACs; TT's QUIET
   anchor is 1.6e9 on the prover clock]. Book NO speed factor > 1.0
   for "Stage A + GPU" at 125M (RR's 12x128 reading holds at 12x512);
   book the bytes (**2.25x smaller**: 670,891 vs 1,509,911) and, at
   8B, the memory (the 120 GB descent term).
2. **Full mode costs 4.0-4.4x the prove wall at 125M** — the 12
   degree-18 lookup sumchecks (scalar K on the CPU, 44-47 s = the
   `other` bucket of the Stage-A phase) + the act-h group's commit and
   opening (the `tail`, 9.4-14 s) — for a proof 1.68x smaller than the
   oracle's (900,003 B) that routes EVERY lookup through the aggregate
   checks (no GKR descents at all: the 8B term Stage A exists for).
   Its memory is now range mode's: 7,156 vs 7,152 MiB.
3. The prove anatomy at 12x512, Stage-A range, from the `[UPERF3-RR]
   ATTRIBUTION` block (rep 1): claim-layer 2.39 | Stage-A phase 4.54
   (silu descents 2.26, zc tabs 0.29, zc prove 1.67 [264 rounds, 83.6
   G MACs on the device: rounds 0.77 s], claims transport 0.26) |
   openings 11.78 (weight 2.46, **act 9.32**) — the act opening is
   50% of the prove: the two-tier / weight-preprocessing lane's
   territory (the act group is 12.35M rings vs the oracle's 7.85M —
   GG's F1 finding, +57%).

## 3. Memory: the diet and what is left (rung 2)

The two 2026-09-02 OOMs (range 14.4 GiB, full 15.18 GB) were GG's
per-column claim transport's, not the shape's. With the batched
transport as the default (rung 0) and the driver diet (rung 2):

| `uperf-a pass 12 512 ..` | phase B (act-h commit) | phase C (Stage-A) | prover done | after the drops (current) | verifier hwm | **peak RSS** | log |
|---|---:|---:|---:|---:|---:|---:|---|
| range, GG's transport (2026-09-02, orchestrator) | — | killed | — | — | — | **> 14.4 GiB, OOM** | ledger |
| range, batched default, rung-1 binary | — | 6,985 | — | — | — | 7,152 MiB | r2_12x512_range_nooracle_predict |
| range, batched + the diet | — | 6,985 | 6,985 | 2,778 | 6,985 | **7,152 MiB** | r2_12x512_range_nooracle_diet |
| full, GG's transport (2026-09-02, orchestrator) | 8,317 | 12,179 | killed | — | — | **15.18 GB, OOM** | ledger |
| full, batched default, rung-1 binary | 6,989 | 6,989 | 9,540 | — | (peak) | 12,472 MiB | r2_12x512_full_predict |
| full, + SS's diet (i) one h_sum claim per pair, (ii) the prover's claims/nus/witness dropped before the verifier, GG's host transients dropped after the Stage-A phase | 6,988 | 6,988 | 7,547 | 2,999 | 7,547 | 7,728 MiB | r2_12x512_full_diet |
| full, + rung 2b: COMPACT act-h claim rows + ONE combined contrib per act-h tensor | 6,988 | 6,988 | **6,988** | 3,097 | 6,988 | **7,156 MiB** | r2b_12x512_full_compact |

What is left is the COMMIT-phase peak (6,985-6,989 MiB in both modes):
the planes' act group, 12.35M rings against the oracle's 7.85M, under
lane OO's commit memory law (the oracle peaks at 2,833 MiB at this
shape on the GPU) — the F1 commit-growth term, an engine item (MVP8B
W-1/W-3), not a driver term. GG's "nrw-88 zero-check transient ~5 GB"
sits below that peak now (phase C's high-water == phase B's): the zc
class tables are built on the host and uploaded per class, then freed.

At 12x128, full mode: 8,072 MiB (SS, GG's transport) -> 4,417
(batched) -> 3,161 (the diet) -> **2,884 MiB** (rung 2b); range 2,496.

## 4. The 8B full-mode memory row, re-estimated with the diet [MODEL]

Lane SS's V4 row (2026-09-02): pass peak ~78 GB at the lvl-0 class on
lane OO's ~72 GB range-form baseline, "~87 GB until the claim-kernel
follow-ups land"; the orchestrator's note made it a LOWER BOUND after
the 12x512 full-mode OOM. Two corrections from this lane's reading of
the code and the measurements:

- The claim-kernel term was COUNTED AT BLOCK SIZE (n_h rows per
  claim) but the rows were DENSE over the act-h tensor (gh_rows = the
  pair's columns x n_h): SS's own 12x128 verify-phase growth (+1.3 GB)
  is the dense size (24 x 163,840 x 128 B per side), not the 50 MB the
  block size gives. At 8B (32 columns over the two pairs, n_h =
  512 x 16384 / 16 = 524,288, gh_rows ~13.6M + 3.1M) the dense rows
  were 64 x ~1.7 GB = **~95 GB per side**, prover AND verifier copies
  alive together before diet (ii) — the pre-round-11 full mode at 8B
  was a ~260 GB object, not 87 [COUNTED from the row layout].
- With the diet the act-h claim memory at 8B is: 32 compact eq-rows
  x 524,288 x 128 B = 2.1 GB + the 2 pair ones-rows (16.7M x 128 B =
  2.1 GB) + the 2 combined dense rows (2.1 GB) = **~6.4 GB** on the
  prover's side, the verifier's ~4.3 GB not simultaneous [COUNTED
  from the rung-2b layout], and the engine sees 2 contribs instead of
  64 on the act-h group (`bg.kernel-rows` x contribs).

THE ROW: **8B x 512 full mode (kappa 4, the round-11 form) peaks at
~85 GB [MODEL]** = lane OO's ~72 GB range-form baseline (the weight
group's lvl-0 phase, unchanged by this lane) vs the act-h phase at
~78 GB (SS's V4: +4.3 GB store, the act-group rates) + ~6.4 GB of
claim rows + ~2.7 GB of per-column lookup transients (SS) — the act-h
phase is the peak, ~85 GB, under 128 GB with ~40 GB of margin. The
"lower bound" caveat is REPLACED by this figure: at the reference
shape the measured full-mode peak now EQUALS the range-form peak
(7,156 vs 7,152 MiB), so full mode's 8B excess over the range form is
the counted act-h terms above (~13 GB), not a measured growth law.
Open [MODEL, flagged]: the zc class tables are host-built even with
the device chain — at 8B the nrw-88 class alone is ~64 members x 8
planes x 2^23 x 4 B = ~17 GB of transient during its aggregate (below
the 72 GB lvl-0 peak, so not the peak; MVP8B §1.4's transient list
should carry it).

## 5. What was built (rungs 0-2b; all floors green at every commit)

- Rung 0 (26990ea): the BATCHED zc claim transport is the Stage-A
  default (ruling 3; `ZK_RR_ZC_CLAIMS=gg` = GG's per-column form,
  opt-in); `full` = the kappa-4 helper confirmed (ruling 2). Identity
  from here on: 12x64 statement 441ca5db.. / transcript c0b8236f..
  (431 claims), 12x128 dc3100e7.. / 1644b4e1.. (439), 12x512
  ee87f414.. / e0b3b985.. (455); the gg form prints 44528c6a.. /
  e5085602.. as before.
- Rung 1 (03c0a49): the cold-descent-kernels finding — a VRAM
  residency interaction (the zc aggregate held 3.31 GB past its phase;
  k9's budget fixed at init with 3.76 GB of idle slabs; the oracle
  leg's ixf module declined at "free 0.34 GB"; k9's own upload path
  then freed the tables it had just grown (`make_room` mid-loop) and
  wrote to ptr 0: CUDA_ERROR_INVALID_VALUE, k9 disabled, descents on
  the CPU 55-59 s). Fix: `zc_agg_release()` + `k9_trim_idle()` called
  by the driver after the Stage-A phase + the room made once before
  k9's ixf table grows. The in-process oracle now matches the
  standalone pass (18.2-18.8 vs 16.9-17.7 s, NOISY); the one-process
  A/B is valid on this box.
- Rung 2 (5d3ca82) + 2b (this commit): the driver diet — SS's (i)
  one h_sum claim per pair (the union LogUp identity; a full-mode
  transcript change: 12x512 8d1ef1a8.., 12x128 4b02815d.., 3x16
  6863f0d6..; statement digests and wire bytes unchanged; `full-s2`
  d47cd6d7.. untouched; the `ss-sum` tamper still rejects), (ii) the
  prover's claims/nus/witness dropped before the verifier, GG's host
  transients dropped after the Stage-A phase, and 2b's compact act-h
  rows + one combined contrib per act-h tensor (transcript-neutral:
  every full-mode digest unchanged). The RSS high-water lines print in
  every mode.

## 6. Open (for the ruling / the next round)

- The pair-level h_sum grounding (diet (i)) carries a soundness note
  written by this lane only (ledger, rung 2); it enters the full-mode
  freeze set with ruling 2's helper or not at all.
- k9's init-time VRAM budget is left as is; the driver's explicit
  trim at the phase boundary is the mitigation. A module that
  budgets against the live free VRAM inside k9 is the structural fix
  (a frozen-path device-planner change — a ruling item).
- Full mode's prove wall at 125M (4x the oracle's) is the scalar-K
  degree-18 lookup sumchecks (44-47 s for 12.6M elements at 8T,
  ~21 min at 8B on this box [SS's MODEL]); a device port of the
  partial-fraction round (the zc_agg pattern) is the lever if full
  mode is to be the shipped form.
