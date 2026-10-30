# Research handoff: DeepProve gap study, 2026-10-30

From the coordinator's focused study, written 2026-10-30 20:45 UTC. It answers
the AGENDA's standing question of 2026-10-30. **No measured proving
improvement**: this is analysis only. No build, proof or production change was
made.

Read `results/zk60_deepprove_gap_20261030/GAP_ANALYSIS.md`. Its arithmetic is in
`gap_calc.py` and `gap_calc.out` in the same folder.

## What it finds

**Per unit of work, DeepProve is behind us on CPU.**

| Run | Proven multiply-adds per second |
|---|---:|
| DeepProve README: Gemma-3-1B T512, 24-core EPYC, public IO [CLAIMED] | 3.3–4.6e8 |
| Ours: Shieldstral-3B T128, 8 threads, hidden IO [MEASURED] | 8.6e8 |

- The "100×" is DeepProve's distributed figure: 1,855 tokens/min, with node
  count and model unknown, because the ePrint PDF returned 403.
- zkLLM's 40× per multiply-add is fully explained by A100 hardware times our
  measured CPU-to-GPU port ratio. The residual is ×0.9.
- Attestable's claimed 1,900× leaves ×20 after hardware. That residual is the
  speed plan's GPU-resident roofline work.
- Hiding is 12.1% of block walls at TinyLlama T128 [MEASURED phase rows], and
  about 5% at 8B T512 [MODEL].

**DeepProve's transferable value is committing less.** These techniques lower
the 5090 kernel efficiency that 50 positions/s needs, from about 34% to 17–23%
[MODEL on INFERRED]. They do not replace the GPU work.

| Rank | Technique | Expected effect |
|---|---|---|
| 2 | Masked LogUp-GKR in place of the committed H | ×1.37–1.57 on the roofline |
| 3 | Wider limbs (one range table at the row width) | ×1.05–1.3 |
| 4 | Derived instead of committed linear planes | ×1.05–1.12 |

Rank 1 is the whole prover on the GPU (Sol, speed plan L2–L5); rank 5 is
bounded-slack softmax, which is ruling-gated.

## Top experiment for the explorer: LogUp-GKR against committed helpers

**What to build.** A standalone Goldilocks/Fp2 LogUp-GKR prover and verifier
for byte lookups:
- leaves (1, α − v) with v in [0, 256);
- layers streamed, never the whole tree;
- the first-layer pair table, i.e. the 65,536 public values of (α−a)(α−b)
  once α is drawn.

**What to measure** at 2^20, 2^22 and 2^24 lookups:
- ns per lookup;
- field multiplications per lookup;
- bytes touched per lookup;
- peak memory.

**Limits.** CPU only, ≤ 1 GiB, light guard.

**Baseline.** Today's helper path on the same lookups, priced by the speed-plan
law at about 54 ns per lookup on 16 threads [COUNTED]:

| Component | ns per lookup |
|---|---:|
| Helper commit | ~23 |
| Inverse | 10.8 |
| Helper tables' share of the zero-checks | ~20 |

On a GPU the helper path costs about 170 B of commitment traffic per lookup
(speed plan L5).

**Kill it if** GKR costs at least 0.7× the helper path per lookup on the CPU
**and** at least the same counted bytes per lookup.

**Also deliver** a one-page zero-knowledge design note for Claude and the
security owner. It should cover:
- root blinding (a candidate, unreviewed: two cancelling random leaves, so that
  q_root is uniform and p_root stays 0);
- hiding of the layer claims (Libra-style masks or our M-row CFS machinery);
- the new leaf claim sites on the committed limb planes.

This builds on `handoffs/20260926-logup-fraction-tree.md`. Keep its root
disclosure and tree residency negatives: this experiment is the masked,
streamed form that those negatives call for. It is not the naive port.

## Cheap companion: a count, no proof

Extend `results/zk60_speed_plan_20261017/layout.py`. Recount A/H planes, U8
lookups and zero-check element-terms at:
- 8B T512 with n = 2^15 and limb width w = 15;
- Shieldstral T128 with n = 2^14 and w = 14;
- w = 16 with n = 2^16.

At w = log_cols the condition `log(Tab) == log_cols` (`layout.rs:141-170`)
holds exactly. The security owner still re-reads P-3.

**Kill it if** committed elements fall by less than 10% at w = log_cols.

## Not to duplicate

These are owned elsewhere:

| Item | Owner |
|---|---|
| S4 split-width (R14) | Sol |
| S5 public-prefix reuse | Sol, with a privacy design |
| S6 verifier weight commitment | Sol |
| L7–L9 | speed plan |
| DD (D30) | admitted |
| 5090 bandwidth run | Sol, `results/zk60_gpu_zerocheck_20261017/NEXT.md` |

## Obligations for any of these

- every mask, pad, proximity pair, RNG draw and refusal stays unchanged until a
  ruling says otherwise;
- one opening per commitment (D12);
- a new profile string (D17);
- the joint-view and NL-1 gates rerun on new captures.

None of these is a privacy acceptance.
