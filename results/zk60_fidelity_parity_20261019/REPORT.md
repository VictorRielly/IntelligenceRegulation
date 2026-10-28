# Fidelity lane — final report (2026-10-26)

Saved by the coordinator from the fidelity lane's hand-back text (the lane's
harness could not write report files). Native build spec:
`results/zk60_fidelity_parity_20261019/S2_BUILD_SPEC.json` (self-contained:
windows, multiplier bits per site, F_P, SiLU tables, norm width, h width,
calibration rules, costs, fidelity numbers, open items). Ledger: `PROGRESS.md`.
Nothing of this lane is running.

## Summary

- **8B: the chosen stack is "LOW + h int24".** It is DD-compatible and passes
  the amended D32 bar (perplexity at most 1.02, LAMBADA at least 98%, zero
  refusals):
  - perplexity ratio 1.0108 on FineWeb and 1.0094 on WikiText, 0 of 96
    sequences refused;
  - LAMBADA on 200 items: int 0.800 against float 0.780, ratio 1.026.
- **The two LAMBADA refusals are both calibration bounds, fixed at no proof
  cost.** With the fixes, both refused sequences ran through all 32 layers
  with 0 violations (`runs/llama3-8b/e8_LOWh8v6_lam0/refusal_fixcheck.json`).
  - L21 FFN gate on " the": channel 5158 reached 16.19 against a range of
    ±16. Fixed by a wider group-SiLU tensor cap (4 instead of 2), which moves
    that channel one member coarser.
  - L15 score on " it": the out-of-range entry is a **masked future score**.
    The native relation range-checks the whole T×T score matrix, but the
    calibration statistics cover causal pairs only. Fixed by one more SH_S /
    e_s bit at that layer, inside the counted window.
  - **Open:** the full 96-sequence perplexity and 200-item LAMBADA sets have
    not been re-run with the two fixes. Expected effect on perplexity: at most
    0.002 [MODEL].
- **TinyLlama: the cheapest passing stack is "LOW"** (no h int24):
  - perplexity 1.0086 / 1.0101, 0 refused;
  - LAMBADA on 1000 items: 0.599 against 0.598, ratio 1.002, 0 refused. All 7
    refusals of the earlier LOW run are gone.
  - The 8B stack (+h int24) at TinyLlama costs 0.43 points more and measures
    1.0041 / 1.0084.

**One line for Victor:** parity at the amended D32 bar costs **+22.8%
committed proof at 8B T128** (about +15.5% prove time [MODEL]), or **+24.9%
against today's DD prover at 8B T512**, with stack LOW + h int24. Measured:
perplexity 1.011 / 1.009, LAMBADA 0.80 against 0.78 float.

## Cost of the chosen stack

[COUNTED] with a copy of the native r11 counter (`cost/fp_r11_stacks.py`,
stack LOW16_H24; the replica anchor re-runs and asserts).

| Model and length | vs R9 non-DD | vs R9 DD | Time [MODEL] |
|---|---|---|---|
| 8B T128 | +22.82% | +23.74% | prove +15.5% / +15.7% |
| 8B T512 | +19.73% | +24.92% | argument phases +18.4% / +22.2% |
| TinyLlama T128 | +21.41% | +22.94% | prove +19.2% / +19.9% |

- TinyLlama's cheapest stack, LOW, costs +20.98% vs non-DD and +22.48% vs DD.
- Score int12 rules out DD. At 8B T512, R9 with DD is 20.8% smaller than
  without, so LOW + score int12 would cost +54.0% against R9 DD; it ranks
  last.

## Results per model and export against the amended bar

Ratio = int perplexity / float perplexity. 48 FineWeb + 48 WikiText sequences
unless noted. All [MEASURED] on the shared box, n = 1.

| Model | Export or stack | FineWeb | WikiText | LAMBADA ratio | Refused (ppl / LAMBADA) | Verdict |
|---|---|---|---|---|---|---|
| TinyLlama | pg_rot1_b4 (R2), 128+128 | 1.233 | 1.292 | 0.873 | 1 / 7 | FAIL |
| TinyLlama | dg_rot1 (R8, b01a6db1), 128+128 | 1.118 | 1.138 | 0.906 | 0 / 2 | FAIL |
| TinyLlama | **LOW (spec form)** | 1.0086 | 1.0101 | **1.002** | **0 / 0** | **PASS** |
| TinyLlama | LOW + h int24 | 1.0041 | 1.0084 | not run | 0 | ppl pass |
| 8B | b7 (pg_rot1_b7_T128) | 1.630 | 1.772 | 0.731 | 48 / 10 | FAIL |
| 8B | b7voc0 variant (the R8 proving stack) | 1.647 | 1.710 | – | 3 | FAIL |
| 8B | dg_rot1_voc0 (00aba3d9) | 1.281 | 1.277 | 0.865 | 2 / 7 | FAIL |
| 8B | **LOW + h int24** | 1.0108 | 1.0094 | **1.026** | **0 / 2, fixed** | **PASS** (full re-run pending) |

- 8B LAMBADA on the same 200 items: b7 0.570, dg 0.675, chosen stack 0.800,
  float 0.780.
- Against the original 1.01 / 99% bar: 8B LOW + h int24 misses FineWeb by
  0.0008. HIGH would pass it (1.0045 / 1.0034) at +29.16%.

## Which lever moves each metric

**8B, FineWeb / WikiText:**

| Step | Result | Cost |
|---|---|---|
| b7 → dg (per-layer constants) | 1.63 / 1.77 → 1.28 / 1.28 | none |
| + c2 multipliers | → 1.166 / 1.149 (float-weights bound 1.165 / 1.137) | +10.06% |
| + group SiLU | → 1.140 / 1.098 | 0 committed |
| + norm int16, F_P 12, attention int16, SiLU input int12 (= LOW) | → 1.0207 / 1.0099 | LOW +22.35% |
| + h int24 | → 1.0108 / 1.0094 | +0.47% |
| + score int12 instead of h int24 | → 1.0113 / 1.0100 | non-DD only |
| HIGH | 1.0045 / 1.0034 | +29.16% |

**TinyLlama, FineWeb / WikiText:**

| Stack | Result | Verdict |
|---|---|---|
| c2 | 1.067 / 1.093 | |
| c2 + group SiLU | 1.036 / 1.056 | |
| P1 (+ SiLU input int12 + F_P 12) | 1.031 / 1.047 | fails |
| P2 (+ norm int16) | 1.022 / 1.028 | fails |
| P3 (attention int16, norm int8) | 1.0164 / 1.0225 | fails |
| P3 + h int24 | 1.0133 / 1.0221 | fails |
| LOW | 1.0086 / 1.0101 | passes |

- Attention words int16 together with norm int16 is the step that clears
  1.02. The P family fails even at TinyLlama, so it was not run at 8B.
- F_P alone and a finer SiLU output (MID) buy nothing measurable.

## Weight-range options side by side

Committed % vs R9 non-DD, as 8B T128 / 8B T512 / TinyLlama T128.

| Option | Counted cost | Measured |
|---|---|---|
| (a)-exact | +9.59 / +6.73 / +8.29 | **Invalid run:** fp_variant's up-bound hook took the statistics ids before the extra-calibration merge, so the up options were ignored. Bug fixed; rerun dropped (would save only 0.47 / 0.32 points against c2). |
| (a) without up | +4.20 / +2.91 / +3.59 | 8B 1.142 / 1.107, but 44 refused at the layer-0 FFN up |
| (b) 12-bit multipliers | +21.96 / +15.39 / +19.07 | not needed |
| **(c2)** | +10.06 / +7.05 / +8.72 | **8B 1.166 / 1.149, 0 refused, equal to the float-weights bound**; TinyLlama 1.067 / 1.093 |
| (c3) int12 words | +10.98 / +7.70 / +9.53 | not run |

## The native build spec in brief

Full detail in `S2_BUILD_SPEC.json`. Everything is relative to the dg exports
(R8 per-layer constants).

- **c2 multipliers per output channel:** q 5, k 5, **v 6** (not 7), o 8, g 6,
  u 4, d 6 bits. m_j = ceil(2^b · rowmax / 127); words W'_j = round(W_real ·
  2^b / m_j); output = round(m · acc / 2^(sh+b)).
- **Norm outputs y and nm:** int16 by the tn route (tn − 8). The norm window
  becomes 24 bits / 3 limbs.
- **Attention words q, k, v, qr, kr, o:** int16, 2^6 finer, keeping 2 bits of
  range headroom. q/k shift 8+8−6+5 = 15; v shift 8+8−6+6 = 16 (hence V at 6
  bits). RoPE unchanged.
- **Score word:** stays int8, which keeps DD. Shift sh_s + 12, giving 17..20.
  Exp table unchanged (f_e 9).
- **Softmax:** F_P 12. PV shift 12.
- **ao:** shift sh_ao + 14. **z:** shift sh_z + 14. Both int16.
- **up:** shift 12.
- **Gate and SiLU:** SiLU input int12 with 4096-row registry tables, at most 4
  per layer at T128 (at most 8 at T512), plus a public group column. Member
  rule: e_j = the finest e_in in [−5, −1] with 127·2^e_j ≥ min(8× channel max,
  **4×** tensor max); the finest groups merge into the 4th coarsest, one output
  member per group. The per-channel gate step must fold into the gate
  multipliers with the shift kept at most 24 (**native lane to confirm**). The
  per-group output scale folds into the down projection's input columns.
  **Correction (Sol, 2026-10-26 18:01Z, accepted by the coordinator):** the
  measured arithmetic (`fp_lib.rx_block`) applies the group output scale
  BEFORE the h-product rounding; folding it into W_d after rounding is
  generally different (a=1, u=16, shift_h=5, scale 1/2: exact h = 0 vs
  rounded-then-scaled 1/2). R13 follows the measured arithmetic (with
  power-of-two group scales this is a per-group h shift selected by the
  public group column) and recounts the product window.
  **Word domain (coordinator, 2026-10-26 19:50Z, conditional on Sol's
  dependency check):** the widened int16 word sites (y, nm, q, k, v, qr, kr,
  o) are defined over the two's-complement range [−32768, 32767], not the
  symmetric [−32767, 32767] that `fp_lib` checks today (`LA = 2^(7+ka) − 1`).
  Each word is fixed by its division identity, so this only turns a word
  landing exactly on −32768 from a refusal into an accepted run; every other
  value is unchanged. Saves +2.78 points at 8B T128 against an inverse-based
  exclusion. `S2_BUILD_SPEC.json` is left byte-identical (Sol pinned it);
  this note amends it. The int8 score word and int8 weights stay symmetric.
- **Product h:** int24, shift sh_h − 8 = 5..8, one byte.
- **Unchanged:** residual int16, exp table, D25 head.
- **Every spec shift sits inside the counted LOW16_H24 windows:** q/k 2 bytes,
  v 2, ao 3, g 3, up 2, z 3, score 3, PV 2, RH 1.
- **Calibration rules for any new model, Shieldstral included:**
  1. Score bounds must cover **all** T×T pairs, not only causal ones (the
     alternative — a native change that range-checks only causal entries — is
     not costed).
  2. Group-SiLU bounds come from the export's full calibration set.
  3. Layer-0 vocabulary maxima, plus extra calibration and refused-sequence
     maxima, go in as for the 8B dg export.

## Corrections and caveats

- **ah2 is not free in general.** Zero-cost only with V at 6 bits; with the
  native lane's own c2 base shifts it would push q/k/v to three bytes, about
  +1.9 points.
- **Earlier runs used too many SiLU tables.** LOW / MID / HIGH runs before the
  cap used up to 8 tables per layer; all later runs are capped at 4.
- **The 8B perplexity run is not exactly the spec form.** It used V at 7 bits
  and tensor cap 2. A unit check shows the same block error with V at 6 bits;
  the LAMBADA runs are in spec form.
- **Stale token_io wording.** `exports/llama3_8b_pg_rot1_b7voc0_T128` (profile
  26fc103b) still carries b7's `token_io.json` and `README.md` as hard links.
  The wording describes b7; the data files are correct. Left untouched. The
  T32 b7voc0 and 8B dg exports have rewritten token_io and SHA256SUMS.
- **Scheduling incidents:** the 8B items 100–199 run was admitted before a
  deferral arrived; a second lane-Y loop re-ran some jobs harmlessly; one lane
  line was read before it was rewritten, so t_LOWs4f ran instead of
  t_LOWs4g; guard admission was starved from 03:09 to 03:33 (10-21).

## For Astra (A2)

- Stack flags: `fp_eval.py --mult-bits q:5,k:5,v:6,o:8,g:6,u:4,d:6
  --gate-pc=-5:mc8:tm4:ng4 --mods y8,fp12,a8,ah2,g4,h8`.
- fp_eval hard-codes the group-SiLU statistics pickle per model (8B b5,
  TinyLlama b3). Shieldstral needs its own.
- `fp_diag_refusal.py --run TAG [--gate-pc ...] [--sh-s-plus L:b] [--to-end]`
  gives the unclamped value behind each refusal and checks a fix.
- The RoPE/YaRN warning (transformers ≥ 5.13.1 reference, not 4.48.1) is
  recorded in the ledger.

## Files

All under `results/zk60_fidelity_parity_20261019/`: `S2_BUILD_SPEC.json`,
`PROGRESS.md`, `results_summary.json`; `cost/fp_r11_stacks.py` and its
`.json`; `fp_lib.py` (width what-ifs yK, fpN, aK, ahJ, gK, oK, hK, sK; group
SiLU mc / tm / ng); `fp_eval.py`, `fp_variant.py` (up-bound fix),
`fp_diag_refusal.py`; runs: `runs/llama3-8b/e8_LOWh8g`,
`lambada_LOWh8v6.json`, `e8_LOWh8v6_lam0/refusal_diag.json`,
`e8_LOWh8v6_lam0/refusal_fixcheck.json`; `runs/tinyllama/t_LOWg`,
`lambada_LOWv6.json`.
