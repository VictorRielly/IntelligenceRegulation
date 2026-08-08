# The frugal-lm 125M int8 Calibration Study (U-AG-B1, Agent BC)

Status: LANE DELIVERABLE (2026-08-08, lane BC). Executable:
`scripts/m125_int8_calibration.py` (seeded 1337; run under
frugal-lm's own venv — mlx + numpy; ~2-3 min on the Mac box; every
number below is machine-independent). Raw tables:
`results/m125_int8_calibration.json`. This is the LLM_POC_ROADMAP.md
**risk 5** de-risk: "Quantization reality of the 125M checkpoint: if
calibration fails the range facts, the PoC needs a
quantization-aware pass first (frugal-lm side work, not proof-system
work)."

## 1. The checkpoint and the semantics applied

**Checkpoint (READ-ONLY; nothing under frugal-lm is written):**
`/Users/victorrielly/frugal-lm/runs/125m-baseline/ckpt-00009536/
model.safetensors` — a **COMPLETED** 125M training run (2,499,805,184
of the 2.5e9 token budget; final val_loss 3.0816 per its log.jsonl;
bf16). NOT a partial/probe fallback — the best case the lane brief
allowed. Architecture per `frugal-lm/configs/125m.yaml` +
`src/frugal_lm/config.py`: n_layers 12, d_model 768, n_heads 12,
n_kv_heads 4, vocab 49152 (SmolLM2 tokenizer), tied embeddings;
**mlp_hidden = 2048 resolves from the config-code default**
`((8*768//3)+127)//128*128` — the yaml does not state it (worth
knowing when reading frugal-lm configs: the ledger's "mlp_hidden
2048" is the resolved value, not a yaml line). FFN tensors per layer:
`blocks.N.mlp.w_gate.weight` [2048, 768], `w_up.weight` [2048, 768],
`w_down.weight` [768, 2048] — 36 tensors, 113,265,408 total model
params (loaded strictly through frugal_lm's own model code; the
study's manual block walk reproduces the model's forward to max |d| =
0.0).

**Semantics (TARGET_CONTRACT.md Section 2, applied verbatim):** int8
symmetric, power-of-two scales; requantization x = 2^shift · y + r
with the remainder r proven in [0, 2^shift) (floor semantics as
written); rescaled activations narrowed to int8 by proven range
facts, SiLU via the frozen 256-row int8 -> int8 table
(domain-membership narrowing); attention / RMSNorm / residual stay
OUTSIDE the statement (contract Section 1) and run in fp32 here.

**Convention pin (exported to BB):** "int8 symmetric" is read as the
range **[-127, 127]**. This is not a free choice: the contract's own
accumulator row — 27-bit signed at inner 4096 — reproduces ONLY under
[-127, 127] (4096 · 127² = 66,064,384 < 2^26 fits 27-bit two's
complement; the [-128, 128]-product bound is exactly 2^26, which does
NOT). The study reproduces both contract rows (27-bit @ 4096, 29-bit
@ 11008) under this reading before deriving the 125M rows.

**Honest accumulator widths at the 125M inner dims** (the contract's
27/29-bit rows are for 4096/11008 and do NOT transfer):

| matmul | inner dim | worst-case max abs acc | honest width |
|---|---:|---:|---|
| gate/up (X @ Wg/Wu) | 768 | 768 · 127² = 12,387,072 = 2^23.56 | **25-bit signed** |
| down (h @ Wd) | 2048 | 2048 · 127² = 33,032,192 = 2^24.98 | **26-bit signed** |
| Hadamard product a∘up | — | 127² = 16,129 | 15-bit signed (the committed Z class) |

Both far inside q31 (q/2 ≈ 2^30): worst-case exact at q31 a fortiori.
**These 25/26-bit rows are the 125M statement's honest lines** — BB
should carry them, not the 27/29 rows.

## 2. Weight quantization (Section 1 of the script)

All 36 FFN tensors are remarkably uniform (weight decay 0.1 training):

| quantity | across all 36 tensors |
|---|---|
| absmax | 0.12500 - 0.13086 |
| RMS | 0.0337 - 0.0425 |
| chosen exponent e (scale 2^e) | **-9 for every tensor** (scale 1/512) |
| saturations at e | 0 (by construction; 0 measured) |
| saturations at e-1 (one bit tighter) | 21 - 744 per tensor — the margin is real but thin at e-1 |
| per-tensor relative RMS quantization error | 1.34% - 1.89% |

Weight quantization is effectively free for this model: the
**weights-only end-to-end val-loss delta is -0.0001 nats** (noise) —
see Section 4. This is the P2-relevant side: the committed private
weight tensors survive int8 with zero quality cost.

## 3. Activation calibration

Batches: seeded (1337) disjoint windows of fineweb-edu-val
(`data/fineweb-edu-val/shard-00000.npy`, uint16 tokens): 8 seq x 512
tokens CALIBRATION (scale selection) + 8 seq x 512 HELD-OUT (range
facts + loss; simulates future passes at frozen declared scales).
T = 512 matches the contract workload. Capture points per layer: X =
mlp_norm output (the statement's X), gate, up, a = SiLU(gate),
h = a∘up, z = down output.

The calibrated power-of-two exponent table (the export BB's statement
metadata needs — scale = 2^e, per tensor, max-calibrated):

| layer | eX | eW(g/u/d) | eGate | eA | eUp | eH | eZ | absmax X / gate / z |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | -3 | -9 | -3 | -3 | -3 | 0 | 1 | 12.57 / 10.84 / 130.74 |
| 1 | -2 | -9 | -4 | -4 | -3 | 0 | -1 | 20.60 / 7.30 / 34.84 |
| 2 | -2 | -9 | -3 | -3 | -2 | 2 | 1 | 20.12 / 11.13 / 168.64 |
| 3 | -2 | -9 | -3 | -3 | -4 | -1 | -1 | 20.14 / 8.42 / 46.36 |
| 4 | -2 | -9 | -4 | -4 | -4 | -2 | -1 | 20.30 / 7.20 / 58.88 |
| 5 | -2 | -9 | -3 | -3 | -3 | -1 | -3 | 19.70 / 8.14 / 11.14 |
| 6 | -2 | -9 | -3 | -3 | -3 | 0 | -3 | 19.66 / 9.29 / 13.17 |
| 7 | -2 | -9 | -3 | -3 | -3 | -1 | -3 | 19.73 / 8.89 / 14.96 |
| 8 | -2 | -9 | -3 | -3 | -3 | 0 | -2 | 19.40 / 10.39 / 17.91 |
| 9 | -2 | -9 | -3 | -3 | -3 | 0 | -2 | 18.41 / 10.55 / 29.61 |
| 10 | -2 | -9 | -3 | -3 | -2 | 0 | 0 | 18.39 / 12.58 / 113.43 |
| 11 | -2 | -9 | -3 | -3 | -2 | 0 | 1 | 17.48 / 11.20 / 179.89 |

**The outlier structure (the finding that drives Section 4):** the
model has classic LLM activation outliers. Layer 11: X absmax 17.48
vs p99.9 = 4.93 (a 3.5x tail); z absmax 179.9 vs p99.9 = 21.1 (an
8.5x tail). Layer 2: z absmax 168.6 vs p99.9 = 5.4 (31x). Because the
contract's requant relation CANNOT express saturation (a clamped
value would need a remainder >= 2^shift — the range fact fails by
construction; equivalently the SiLU table has no row for an
overflowed input), **scales must cover the true max**: the outliers
directly eat resolution for the bulk of values (typical |X| ~ 1 at
scale 0.25 leaves ~9 quantization levels). This is a structural
consequence of the semantics, not a tuning mistake — percentile/
clipping calibration is NOT available inside the current contract.

## 4. The int8 chain on held-out data (exact integer arithmetic)

The chain per contract semantics — int8 matmuls with exact integer
accumulators (float64-carried, every value << 2^53), floor
requantization with checked nonnegative remainders, 256-row SiLU
table, int8 narrowing with violation counting; attention/norms fp32;
errors propagate through the pass end to end.

**Variant A — the semantics exactly as written** (floor requant,
per-tensor weight scales), held-out batch:

- **Range facts: 0 violations** in 4096 positions x 5 fact classes x
  12 layers (X clip, gate, up, h, z narrowings all hold).
- Accumulators: max measured |acc| 43,928 (gate/up, bound 12.4M) and
  76,254 (down, bound 33.0M) — real data uses ~2^15-2^17 of the
  25/26-bit worst-case ceilings; Hadamard max 6,715 inside the
  15-bit class.
- Per-layer matched-input relative FFN error: 0.42-0.87 for most
  layers, but 1.14 / 2.37 / **7.58** at layers 0/1/2 (the
  outlier-dominated early layers — error above 1.0 means the
  quantized FFN output is worse than emitting zero, i.e. the
  per-tensor scale is so outlier-stretched that typical outputs fall
  below one quantization step).
- **End-to-end: val loss 3.2287 (fp32 reference) -> 8.2093, delta
  +4.98 nats** — quality collapse.

**Attribution variants** (same gadget classes; statement-level design
choices only):

| variant | requant | weight scales | val loss | delta | range viol |
|---|---|---|---:|---:|---:|
| bf16/fp32 reference | — | — | 3.2287 | — | — |
| A (as written) | floor | per-tensor | 8.2093 | +4.9807 | **0** |
| B | round-to-nearest (public pre-add) | per-tensor | 5.5184 | +2.2897 | 13 |
| C | round-to-nearest | per-channel | 5.4943 | +2.2656 | 11 |
| W (weights-only int8, fp activations) | — | per-channel | 3.2286 | **-0.0001** | n/a |

Readings, each load-bearing:

1. **The floor form costs ~2.7 nats by itself** (A vs B). The
   contract's x = 2^shift·y + r relation applied to the publicly
   pre-shifted value x + 2^(shift-1) implements round-to-nearest
   with the SAME gadget at the same cost — recovering 2.7 nats free.
   Exported to BB as a statement design note (the pre-add is public
   arithmetic; the proven relation is unchanged).
2. **Boundary interplay (why B/C show 13/11 violations where A shows
   0):** floor tolerates values up to 128·2^e before overflowing the
   narrowing; round overflows at 127.5·2^e — a narrower band, and 13
   held-out positions (of ~50M checked values) drifted past it. A
   rounding deployment must calibrate with explicit margin (choose e
   against absmax·(1+eps) or accept the floor form's hidden 0.4%
   band). Cheap, but it must be DECLARED — silent clamping is not
   expressible in the semantics.
3. **Per-channel weight scales buy nothing here** (B vs C, +0.024):
   this model's weight tensors are uniform (Section 2). No case for
   granularity complexity in the statement today.
4. **Weight quantization is free; ALL the remaining +2.27 nats is
   activation resolution** (W vs reference at -0.0001). The
   activation outliers stretch the per-tensor power-of-two scales;
   under semantics that forbid clipping there is no proof-side fix.
   The standard model-side lever (SmoothQuant-class per-channel
   rebalancing X·D^-1, D·W — function-preserving, migrates outlier
   scale into the weight side, which has ~9 bits of unused headroom
   here) attacks exactly this term, and is frugal-lm-side work — the
   roadmap's anticipated branch.

## 5. Verdict and exports

> **VERDICT (2026-08-08): the 125M checkpoint CALIBRATES in the
> contract's formal sense** — at max-calibrated per-tensor
> power-of-two scales, every proof-side fact holds on held-out data:
> range facts 0 violations, accumulators inside the honest 25/26-bit
> ceilings, remainders in [0, 2^shift), SiLU inputs inside the table
> domain. **The PoC statement can be built and will verify on this
> model as-is.** The QUALITY of the quantized model is a separate,
> quantified matter: +4.98 nats val loss as-written, +2.29 with the
> free rounding fix, with the remainder attributed entirely to
> activation-outlier resolution (weights-only cost: -0.0001). A
> proven-but-degraded model is the honest current state; making the
> proven model GOOD needs a quantization-aware / outlier-suppressed
> frugal-lm pass (model-side, not proof-system work) — exactly
> roadmap risk 5's anticipated branch, now with the number attached.

**Exports to lane BB (the statement builder):**

1. Tensor dims per layer: gate/up [2048, 768], down [768, 2048]; 12
   layers; X is [512, 768] per sequence at the contract workload.
2. Honest accumulator lines: **25-bit (inner 768), 26-bit (inner
   2048)** — replace the contract's 27/29 rows at this shape;
   Hadamard stays 15-bit.
3. The int8 convention pin: symmetric [-127, 127] (forced by the
   contract's own 27-bit row — Section 1).
4. The scale table (Section 3) as statement quantization metadata;
   weight scales are uniformly 2^-9.
5. The rounding design note: adopt the public pre-add
   round-to-nearest form of the requant relation (free, -2.7 nats)
   WITH explicit calibration margin (reading 2 above).
6. Range-fact margins for the declared scales: held-out drift stayed
   inside all facts (variant A); the engine's derive should fail
   loudly on any violation — that is intended behavior, not an
   error path to soften.

**Honest limitations:** one checkpoint (the completed 125m-baseline);
8+8 sequences of 512 (4096 calibration + 4096 held-out positions);
per-tensor activation scales (the contract's conservative reading);
fp32 reference forward (bf16 checkpoint widened); loss on this
study's val windows (3.2287) sits 0.15 nats above the training log's
running val (3.0816) — different slice and precision, not a
discrepancy in the model. The [MAC-BOX] rule is moot here: every
reported number is machine-independent.

---

*Changelog: 2026-08-08 — first edition (U-AG-B1 lane BC).
Completed-run checkpoint located and used (no fallback needed);
contract convention pinned ([-127,127] via the 27-bit row);
125M accumulator rows derived (25/26-bit); 36 weight tensors
quantized (e = -9 uniform, 0 saturation, weights-only delta -0.0001
nats); activation scale table calibrated on seeded fineweb-edu-val;
int8 chain exact-integer simulation: range facts HOLD (0 violations
held-out), quality +4.98 nats as-written, attributed: ~2.7 floor
bias (free fix: public pre-add rounding), ~0 weight granularity,
+2.27 activation-outlier resolution (model-side work); verdict:
formally CALIBRATES, PoC-buildable now, quality needs a
quantization-aware frugal-lm pass.*
