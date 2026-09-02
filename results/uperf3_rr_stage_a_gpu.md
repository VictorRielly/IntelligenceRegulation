# U-PERF3 lane RR — Stage A's aggregate checks on the device: THE MEASURED FACTOR

Status: rungs 0-3 + 5 done 2026-09-02 (rung 4, the 12x512 A/B, is
orchestrator-run — the command is in `PROGRESS_UPERF3.md`, "Agent RR
status"). Machine: the WSL laptop (Core Ultra 9 185H, `ZK_THREADS=8`,
RTX 4070 Laptop GPU, 15 GB), `[NOISY-SHARED]` — lanes QQ/SS built and
benched concurrently; every wall below is the better of two
back-to-back reps unless a range is given. Binary: one
`--features gpu-cuda` build (commit "U-PERF3 RR: R3"), the oracle and
the Stage-A leg proved in ONE process (`uperf-a pass <layers> <t>
range`, `M125_EXPORT_DIR` = the 125M WSL export). Labels: [MEASURED]
unless marked.

This page REPLACES the board's unsourced "Stage-A aggregate GPU port +
fold fusion 1.2-1.5x" line (TASK_BOARD 2026-08-30) with measurements.

## 1. The three numbers (12 layers x 128 tokens, ZK_GPU=1, 8T)

| leg (same process, same binary) | commit | prove | verify | total | bytes | claims served |
|---|---:|---:|---:|---:|---:|---:|
| ORACLE = the built pass (descents on k9) | 1.5 | 7.5 | 2.0 | 11.0 | 1,372,775 | (64 rows) |
| Stage-A, aggregate on the CPU (round-9 code = lane GG's form) | 3.6 | 17.6 - 19.4 | 4.3 | 25.5 - 27.3 | 637,691 | 997 |
| Stage-A, aggregate on the DEVICE (rung 2) | 3.6 | 13.4 - 13.5 | 3.9 | 20.9 - 21.0 | 637,691 | 997 |
| Stage-A, device aggregate + BATCHED claim transport (rung 3, opt-in `ZK_RR_ZC_CLAIMS=batched`) | 3.1 | 7.5 - 7.6 | 2.0 | 12.6 - 12.7 | 637,691 | 439 |

Process peak RSS (`/usr/bin/time -v`, covers BOTH legs): 7.5 GB for
the first three rows, **3.1 GB** for the batched row (the ~700 rank-1
claim rows of the GG transport were the peak).

12x64, same conditions: oracle 1.3 / 5.7 / 1.8; Stage-A CPU-aggregate
3.2 / 12.7 / 2.9; device aggregate 2.6 / 8.7 / 2.6; device + batched
2.5 / 5.75 / 1.5 (peak 2.6 GB).

## 2. The factor, stated three ways

1. **The aggregate prover itself** (`zc_agg_prove`, 12 aggregates, 240
   rounds, 20.9 G MACs at 12x128): 5.0-5.9 s on 8 CPU threads -> 0.58 s
   with the device chain (**8.6-10x**); of the 0.58 s the device spends
   0.25 (rounds) + 0.02 (folds) + ~0.2 (uploads) and the host the tail
   rounds + the claim stacking. VRAM held: 0.83 GB at 12x128.
2. **The Stage-A prove wall, GG's transport unchanged**: 17.6-19.4 s ->
   13.4-13.5 s (**1.31-1.44x**) — this is the number the board's
   "1.2-1.5x" guessed at; it is now [MEASURED], and it is NOT enough:
   Stage-A prove stays 1.36-1.40x the oracle's, because after the port
   the critical path is the act-group OPENING (7.7 s vs the weight
   group's 2.3 s on a group 1.14x smaller in rings), whose per-CONTRIB
   phases (`bg.kernel-rows` 3.58 vs 1.11 s, `ep.psi0-factored` 3.74 vs
   0.87, `bg.kernel-phi` 0.89 vs 0.14 — Stage-A | oracle, prof table)
   scale with the ~700 planes contribs GG's transport serves.
3. **With the batched transport** (the m x w per-column plane claims of a
   class recombined along the instance axis into w claims — the same
   recombination `zc_agg_verify` performs; the served values and their
   absorption are unchanged, the opening's claim structure and hence the
   nu count change; a Stage-A transcript VARIANT, selector-only, opt-in,
   posted for the ruling): 13.4 -> 7.5-7.6 s (another 1.78x); Stage-A
   prove == oracle prove (1.00-1.01x), verify == (1.00x), total 1.14x
   (the +1.6 s is the planes commit: groups+planes 0.9 + witness 0.5 +
   precommit act 0.77 vs 0.4-ish). Cumulative on the Stage-A prove wall
   vs the round-9 code: **2.3-2.6x**.

READING FOR THE THROUGHPUT MODEL (lane TT): Stage A on the GPU does NOT
make the 125M pass faster than the built pass — at parity on prove and
verify, +1.6 s on commit. Its wins are the proof bytes (2.15x smaller)
and memory (peak 3.1 GB vs 7.5 GB at 12x128 in the batched form; at 8B
the descents it replaces are the 120 GB term). Do not book a speed
factor > 1.0 for "Stage A + GPU" against the built pass at 125M; book
the memory and bytes. The prove wall's anatomy with Stage A + device +
batched at 12x128 [MEASURED]: claim layer 0.90 | Stage-A phase 1.29
(silu descents 0.57, zc 0.58, tabs 0.07, claims 0.06) | openings 5.3
(weight 2.25, act 3.1) — the OPENING is 70% of the prove: the two-tier /
weight-preprocessing lane (QQ) owns the remainder.

## 3. What was built (all bit-identical; the floors held at every commit)

- `zkmatrix-rs/src/ring/gpu/kernels_zc.cu` + `gpu/zc_agg.rs`: the
  aggregate zero-check's round loop on the device (E_4 arithmetic
  op-for-op; node-sum kernels with grid.y = node and one u64 atomic per
  (node, constraint, coordinate); out-of-place folds with a rotating
  scratch; the pair eq built from the two half tables; the columns
  stacked on upload; pinned stream-ordered staging). Hooked from
  `zc_range::zc_agg_prove_masked` in the ixf pattern (open / round /
  fold / handover; host rebuild on a device error). Knobs: `ZK_GPU_ZC=0`
  (A/B), `ZK_GPU_ZC_MIN_PAIRS` (default 4096).
- `uperf-a pass` driver: per-phase attribution timers, per-class zc
  lines, the prof table (Stage-A | oracle), the `STAGE-A DIGEST` identity
  line (statement digest | prover transcript state | verifier transcript
  state), the parallel class tables / planes build, and the opt-in
  batched transport (`gg_zc_claims_batched`, `gg_zc_claims_sel`).
- Identity evidence: agg-battery 136 legs, digest 46234986.. with the
  device forced on every aggregate to the last round; 12x64 / 12x128
  pass digests identical with and without ZK_GPU=1 (441ca5db.. /
  44528c6a..; dc3100e7.. / e5085602..); the batched variant identical
  CPU vs GPU (c0b8236f.. at 12x64, 1644b4e1.. at 12x128); GG's tamper
  battery (masked honest + 4 tampers) green under both transports with
  the device forced on.
- Two device races found and fixed (stale pad lanes at a small-n
  handover; pageable-upload DMA vs a non-null stream).

## 4. Open (for the ruling / the next round)

- The batched transport is a transcript change of the Stage-A path: adopt
  it as the Stage-A default (the served per-column values could then be
  dropped from the wire too: m x (w+1) -> w + m E-elements per class), or
  keep GG's form. Its soundness reading: the sumcheck's final identity
  consumes only the recombined T_k(x*), which the batched claim opens
  against the committed planes tensor at the full point (r_col, r_inst);
  the per-member rem claims are unchanged.
- The commit-phase excess (+1.6 s at 12x128: the planes tensors) is the
  remaining Stage-A cost above the oracle at 125M; at 8B it is the F1
  finding's commit growth (+58% act rings), not this lane's.
- The 12x512 A/B (rung 4) is orchestrator-run; expect the GG-transport
  legs to sit near the 15 GB ceiling (7.5 GB at 12x128, 4x the rows) and
  the batched leg to fit.
