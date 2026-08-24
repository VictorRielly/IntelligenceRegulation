# U-PERF3 — Per-channel power-of-two rebalancing of Mistral-7B-v0.1 (the smooth experiment)

Agent U, orchestrator-launched 2026-08-24, WSL box. Follow-up to the T12
calibration finding (PROGRESS_UPERF3.md; baseline record
`results/m8b_int8_calibration_wsl.json`): Mistral-7B-v0.1 fails
TARGET_CONTRACT §2 int8 calibration as written — 14,531 held-out
range-fact violations, int8-chain val loss 10.02 vs bf16 ref 1.84,
weights-only int8 nearly lossless (+0.08 nats) — because a few emergent
activation channels carry 3-6000x the bulk range.

Experiment: SmoothQuant-class per-channel POWER-OF-TWO rebalancing folded
into adjacent weights (exact function-equality rewrites of the fp32
network), then the SAME calibration + verdict machinery re-run on the same
seed/windows (seed 1337, 8 cal + 8 val x 512, the module's own Sections
1-4 code). Script: `scripts/m8b_smooth_experiment.py`; per-round records:
`results/m8b_smooth_experiment_wsl_r{1,2,3,4}.json`; canonical record:
`results/m8b_smooth_experiment_wsl.json` (body = r2, the best fold-policy
verdict, plus the r1-measured exactness/anchor and a rounds index).

## 0. The answer

**Formality: PARTIALLY RESCUED — violations drop 14,531 -> 3 (99.98%),
not to 0. Quality: NOT RESCUED — the int8 chain stays destroyed (+8.45
nats at best fold policy; ref 1.84) in every configuration tried.**
All numbers [MEASURED WSL-BOX, seed 1337, 8+8 x 512] unless labeled.

- The folds are exactly what they claim: the transformed fp32 forward is
  BIT-IDENTICAL to the reference at the full 32-layer stack (scales to
  2^14), and the plain weights-only anchor reproduces to 0.0e+00.
- Best fold policies: r2 (alpha=0.5) leaves 4 violations, r3 (capped)
  leaves 3 — all in l31's h class (plus 2 X clips in r2). One more l31
  margin bit would plausibly reach 0 [PROJECTED, not measured].
- The margins-only control (r4, no fold) proves the fold is load-bearing
  for formality: without compaction the h+3 margin needed to clean h
  moves the failure to z — 357,168 z violations, 25x MORE than baseline.
  The int8 budget behaves like a waterbed: squeeze one class, another
  bulges.
- Chain loss: baseline +8.18, r1 +9.07, r2 +8.45, r3 +8.70, r4 +7.86
  nats. Every configuration is model-destroying garbage (val loss
  9.7-10.9 vs ref 1.84); the ordering among them is not decision-
  relevant. Weights-only stays near-lossless only when the fold is
  gentle or absent (plain +0.079, r3 folded +1.07; r1's full migration
  +8.97 — the outlier range simply relocates into per-tensor w_down).
- Conclusion for the ruling: this transform family (exact, statement-
  form-preserving) fixes the RANGE-FACT problem but cannot fix QUALITY,
  because the residual dynamic range is pinned by things no exact fold
  reaches: the unfoldable silu(g) outlier factor (per-tensor eA/eGate),
  the z-spike channels (per-tensor eZ), l31's 14-bit u range, and the
  h floor-noise that any margin amplifies through w_down. Quality needs
  a statement-level widening (Section 3).

## 1. The transform and the policy as run

Exact-fold identities (all scales powers of two; scaling an fp32 value by
2^k is exact, so the transformed fp32 forward is BIT-IDENTICAL to the
reference — measured, Section 2 first row):

- X-side, per d-channel j, s_j = 2^se_j >= 1:
  `mlp_norm'[j] = mlp_norm[j]/s_j; w_gate'[:,j] = w_gate[:,j]*s_j;
  w_up'[:,j] = w_up[:,j]*s_j` — the FFN input becomes X_j/s_j, the
  gate/up pre-activations are unchanged.
- u/h-side, per f-channel k, t_k = 2^te_k >= 1:
  `w_up'[k,:] = w_up[k,:]/t_k; w_down'[:,k] = w_down[:,k]*t_k` —
  u'_k = u_k/t_k, h'_k = h_k/t_k, z unchanged.
- g-side: NO exact fold exists (SiLU is nonlinear). Residual tail risk is
  a calibration MARGIN policy: per activation class, the calibrated
  exponent gets +m bits of headroom (+1 = double the range, one bit of
  resolution paid).

The proof statement is unchanged in FORM: it binds the transformed
weights; the transform is documented preprocessing in the model identity
(the h-outlier factor factors as (u-side, foldable) x (silu(g)-side,
unfoldable) — the policy's split/cap knobs manage the unfoldable part).

Scale choice (calibration windows only, then frozen): s_j =
2^round(log2(a_j / r)) clamped >= 1, a_j the per-channel absmax, r the
tensor's p999; t_k analogous with a per-channel split between the u-side
need and the full h-side need (`--split-alpha`), plus optional exponent
caps. Four configurations were run to the full verdict:

| round | policy | margins x/g/u/h/z |
|---|---|---|
| r1 | alpha=1.0 (t purely from h absmax — the brief's start policy), uncapped | 1/1/1/1/1 |
| r2 | alpha=0.5 (unfoldable silu(g) factor split evenly), uncapped | 1/1/1/2/1 |
| r3 | alpha=1.0, s_cap 2^2, t_cap 2^3 (the gentle fold: weight growth bounded to <= 3 bits) | 2/1/1/3/1 |
| r4 | CONTROL: margins only, NO fold (s_cap = t_cap = 0, every scale 1) | 0/1/1/3/1 |

## 2. Results [MEASURED WSL-BOX, seed 1337, 8+8 x 512, Mistral-7B-v0.1]

Exactness and anchors (r1 pass):

- Transformed fp32 ref loss 1.8410969986 = plain ref BIT-IDENTICAL
  (full 32-layer stack, scales up to 2^14).
- Plain weights-only anchor 1.919830 reproduces the baseline record to
  0.0e+00.

The verdict table (held-out range-fact violations of 4096 positions x 5
facts; loss deltas in nats vs ref 1.8411):

| run | violations (X/g/u/h/z) | chain loss | delta | weights-only (folded W) |
|---|---|---|---|---|
| baseline (T12, no transform, no margins) | 14,531 (0/5166/626/8733/6) | 10.0184 | +8.18 | +0.079 (plain) |
| r1 alpha=1.0 | 5,088 (0/0/0/5088/0) | 10.9078 | +9.07 | +8.97 |
| r2 alpha=0.5 | 4 (2/0/0/2/0) | 10.2865 | +8.45 | +6.22 |
| r3 gentle capped | 3 (0/0/0/3/0) | 10.5385 | +8.70 | +1.07 |
| r4 margins-only control | 357,174 (0/0/6/0/357,168) | 9.6968 | +7.86 | +0.079 (= plain, no fold — sanity) |

s/t histograms (channels at scale 2^e, all 32 layers; d-side 131,072,
f-side 458,752 channels):

- s (all rounds; capped at 2^2 in r3): 2^0 129,356 / 2^1 1,528 /
  2^2 172 / 2^3 16 — the X side is mild.
- t, r1 (alpha=1.0): 2^0 264,349 / 2^1 139,079 / 2^2 43,595 / 2^3 9,714 /
  2^4 1,929 / 2^5 57 / 2^6.. 2^10 27 / 2^13, 2^14 one each (the layer-1
  mega channel: h absmax 1353 vs tensor p999 0.073).
- t, r2 (alpha=0.5): 2^0 346,723 / 2^1 100,388 / 2^2 10,869 / 2^3 746 /
  2^4+ 26.
- t, r3 (capped at 2^3): 2^0 264,349 / 2^1 139,079 / 2^2 43,595 /
  2^3 11,729.

What each round shows:

1. **r1 — full migration ruins the weights.** All g/u/z/X violations
   vanish at +1 margin; h drops to 5,088. But the migrated range makes
   the folded w_down unquantizable per-tensor: eWd rises 2-14 bits (l1
   -8 -> +6, l0 -10 -> -1, l9/l14/l17/l19/l30 -9 -> -2..-4), w_down
   relRMS error hits 0.8-0.93 at a third of the layers, and
   weights-only-on-folded-W alone is +8.97 nats. 143 massed h channels
   (119 at l31) fold below u' resolution and their contributions vanish
   (the down-accumulator at smoke layer 1 was identically zero).
2. **r2 — the split saves the channels, not the weights.** Violations
   collapse to 4 (X_clip 2 at l3, h 2 at l31); the zeroed-channel
   diagnostic is clean. But eWd still rises up to 10 bits (l1 +2) and
   weights-only folded is +6.22; l30 relFFNerr reaches 16.8. Chain
   +8.45.
3. **r3 — the gentle fold contains the weights but the loss stays.**
   With t capped at 2^3 the folded eWd stays within 3 bits of baseline
   everywhere (worst -5, was -8) and weights-only folded is +1.07. X/g/u/z
   are clean; 3 h violations remain, all at l31 (the incorrigible layer:
   its up tensor spans 79.7 absmax next to massed channels needing
   0.005-resolution — beyond int8's 7 bits of per-tensor dynamic range,
   fold or no fold). But the chain is +8.70 — WORSE than the baseline's
   +8.18: the 1-3 margin bits eat mid-layer resolution (l26-28 relFFNerr
   1.6-1.9 vs baseline 0.8-1.1) and the outlier layers keep their
   irreducible coarse eA/eH/eZ (l1 relFFNerr 17.4, l30 9.0).
4. **r4 — the control: margins without the fold move the bulge.** h goes
   clean at +3 margin bits at EVERY layer (even l31 — its uncompacted eH
   is so coarse the range fact is nearly a tautology there), but the 8x
   coarser h floor-step injects noise ~2^eH/2 through the down matmul
   (error ~ step/2 * sqrt(f) * rms(w_down)), relFFNerr hits 5-34 at
   every layer, and 357,168 z-range violations appear (l24 alone
   352,381) as the noisy z spills past its calibrated range. Chain
   +7.86 — nominally the best of all runs, and still garbage: broadband
   noise turns out marginally less damaging than the baseline's clipping
   of the mega channels. Bonus finding: with t = 1 the zeroed-channel
   diagnostic shows the BASELINE chain itself already drops 4,147 massed
   h channels at l1 below the u quantization step — baseline l1
   relFFNerr 8.0 was never just a range problem.

## 3. What remains for the spec ruling

**The g-class margin cost, measured.** The g class cleaned at +1 margin
bit in every run (5,166 -> 0) — the cheap end of the policy. But margins
are NOT free in general: each h bit doubles the floor-step noise the down
matmul amplifies (r4's mechanism), each z bit halves the FFN output
resolution. Margin bits work only where compaction has first made the
range cheap — the fold and the margins are a package, not alternatives.

**The SiLU members the transformed model needs** (identical across
r1-r4 — eGate/eA are fold-invariant and all runs used margin-g 1):
9 members, NONE in the frozen family {(-3,-3),(-4,-4)}: (-2,-4),
(0,-1), (-3,-5), (-4,-5), (-3,-4), (-2,-3), (-1,-3), (0,-2), (0,-3);
digests in the JSONs. The W-6 freeze ruling should wait for the spec
decision — the list depends on the adopted margins (baseline margin-0
gives a different 7-member list).

**What is irreducible within this family** (per-tensor int8 activations
+ per-tensor int8 weights, exact pow2 folds, margins):

- The silu(g) outlier factor cannot fold (SiLU is nonlinear): l1's gate
  spans 38.3 absmax vs 0.6 bulk, so eA = -1 leaves bulk activations ~1
  quantization level, whatever h does.
- The z spikes cannot fold (z feeds the residual; scaling it changes the
  function): l1 z absmax 379.7 vs p999 0.21 pins eZ at +2-3 — bulk z is
  unrepresentable. Same at l30 (161.0), l9/l14/l17/l19 (4.8-14.2).
- l31's u spans 79.7 absmax next to massed channels needing ~0.005
  resolution — ~14 bits of per-tensor dynamic range against int8's 7.
- Compacting h relocates outlier range into w_down (r1: eWd +2..+14
  bits, weights-only +8.97); capping the relocation (r3) caps the damage
  (+1.07) but forfeits the h-resolution win.

**The options this measures out** (for Victor's (a)/(b)/(c) fork in
PROGRESS_UPERF3.md T12 item 5):

1. Adopt fold + margins as a §2 addendum (option a) alone: buys formal
   provability (3-4 violations, plausibly 0 with an l31 bit) of a
   +8.45-nat model — provable garbage. Not sufficient by itself.
2. Option (b), the statement-level widening, now has a measured shape:
   the single highest-leverage change is PER-COLUMN weight scales for
   w_down (`m125.floor_requant` already accepts per-column shift
   vectors; the m125 study ran a per-channel weight variant) — that
   absorbs the ENTIRE t-fold without touching per-tensor activation
   classes, deleting r1's migration damage at zero activation cost.
   Second: a wider (int16-class) a/h/z at the ~6 outlier layers, which
   is where every remaining irreducible lives. The fold family then
   carries the rest of the layers at int8.
3. Option (c) (bounded-violation/clipped statement) stays non-viable:
   every measured configuration is +7.9 to +9.1 nats.
4. 125M vs 7B: the 125M rung calibrated clean because it sits below the
   outlier emergence scale (~6.7B in the LLM.int8() literature
   [EXTERNAL]); this is a property of the model class, not of the T12
   pipeline.

**Costs of this experiment's runs** [MEASURED WSL-BOX]: stats pass ~8
min; verdict passes 33-48 min each (r1 2875 s, r2 1995 s, r3 1999 s,
r4 2149 s); peak RSS 4.65 GB (< the 8 GB discipline bound). Timing on
this box is load-polluted per the ledger's standing rule — walls are
indicative only.

