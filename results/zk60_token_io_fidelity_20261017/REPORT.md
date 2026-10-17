# Token-head fidelity: integer final norm + int8 LM head vs the float head (TinyLlama, pg_rot1_b4)

Lane TOKEN-HEAD FIDELITY, 2026-10-17, 19:02–20:13 UTC. Saved by the
coordinating session from the lane's final report (the lane could not write
this file itself); every number is on disk in `data/s4_head.json`,
`data/s6_tables.md`, `data/s7_decomp.json`, `data/s5_prefix.json`,
`data/s3_int_T*.json`. Python/numpy reference only: calibration data, not a
proof, not a privacy claim. Labels: [MEASURED] = a run happened on the shared
box, n = 1; [COUNTED] = exact arithmetic.

## 1. Plain words

The design (`results/zk60_token_io_design_20261017/DESIGN.md` §3) computes the
next token with an integer final norm (block norm relation, uniform gain), an
int8 head with one scale per tensor, raw integer logits and the lowest-index
maximum. D25 T4 accepts this if it agrees with the float head on the same
integer stack output on >= 99% of held-out positions, otherwise per-row head
scales.

**Answer: not quite.**
- Per-tensor (as designed): **98.45%** of 11,520 held-out positions (T128
  98.50%, T32 98.26%).
- Per-row (the fallback): **98.91%** (T128 99.00%, T32 98.52%); better (112
  positions fixed vs 60 broken, KL halved) but not robustly over 99%. 12-bit
  integer row multipliers match exact float scales (98.88%); 8-bit ones are
  worse than per-tensor (98.19%).
- The two roundings cost about equally: head weights alone 98.76%, int8 norm
  output alone 98.94%. Per-row weights plus a 16-bit final-norm output give
  **99.57%** (T128 99.60%, T32 99.48%) — a design change: a 16-bit output range
  proof on the final norm, keyed-argmax window 61 bits (2 bits under p/2).
- **Every miss is a float near-tie**: all 178 per-tensor misses have a float
  top-2 margin below 0.3 logits; on the 9,408 positions with margin >= 0.3
  agreement is 100%. The integer head picks the float head's second choice in
  172/178 misses; float regret median 0.034 logits, max 0.18.
- The integer stack itself agrees with the float model on ~73%; the head choice
  does not change that (73.57% integer head vs 73.51% float head at T128).
- Proof side: 0 final-norm refusals, 0 exact integer ties, max |logit| 17.5
  bits (bound ~25), keyed difference 33 bits inside the 41-bit window; the
  smallest off-token difference is 30,884 > 0 (strict first maximum).
- F4 holds exactly: the integer stack is prefix-consistent.

**Recommendation (the lane's):** per-row scales with 12-bit multipliers over
per-tensor (+0.46 pt; worst-case window 41 -> 53 bits). T4 then needs either
(a) 99% plus a 16-bit final-norm output (99.57%, a design change), or (b) a
restated criterion: margin-conditioned agreement (100% where the float margin
is >= 0.3 logits) or a KL bound (about 0.0007 nats per position against the
stack's ~0.4). Do not tune the norm margin on held-out data.

## 2. F1: what was built

- **Head.** `W' = lm_head diag(norm_weight) R^T` in float64 (R the export's
  seed-1 randomized Hadamard, sha256 checked); fold check on 512 positions:
  top-1 1.0, max logit difference 1.6e-5. Per-tensor `s_w = max|W'|/127 =
  0.0026756`, quantized with `tlcalib.qw`, 0 clipped, no -128; int8 sha256
  `0f40a48d91a99df7d5118e1bc344b831b47c06da7b5e20877fbd84f2d986dd95`. Per-row:
  scale ratio max/min 3.99, 0 clipped; int8 sha256
  `b99cbec5f457e47ca2441de517135ba1bd1870e2ae8abe2038dbd84617436280`, scales
  sha256 `5eb2b350e384749b9f7ab976e1f5027a4793e6a5a75515af9577e43ad5ea1b1c`;
  integer multipliers `m_j = round(2^b s_j / max s)`.
- **Final norm.** `D = isqrt(sum x^2 + Ceps)`,
  `y = floor((2 x g0 Cn + D 2^tn)/(2 D 2^tn))`, y in ±127, both remainders
  < 2^32, else the position refuses. tn 10 (D24), Ceps 74,429 (= profile),
  g0 127, Cn 5,664 (`norm_site`, c = 1, margin 0.5 on the calibration rotated
  |xhat'| max 5.454). Held-out |xhat'| reaches 5.30 / 4.79, y peaks at 82.
- **Logits.** Exact int64, no requant; numpy first-maximum argmax.
- **Integer stack.** `embedding_int16.bin`, then `tlcalib.i_block` over 22
  layers from the export binaries (sha256 checked), all 72 held-out sequences
  at T128 and T32: 0/72 refused each; `seq_ho00`, `seq_ho36` bit-exact with
  the export.

## 3. F2 numbers [MEASURED, shared box, n=1]

Held-out sets: B4's 36 licence/docstring + 36 FineWeb-Edu per T; every
position counts; T32 windows are separate sequences.

| T | head | vs float head | vs float model | refused | int ties | KL |
|---|---|---|---|---:|---:|---:|
| 128 | float head (reference) | — | 73.51% | — | — | — |
| 128 | per-tensor (design) | 98.50% (9078/9216) | 73.57% | 0 | 0 | 0.00068 |
| 128 | per-row, float scales | 99.00% | — | 0 | — | 0.00038 |
| 128 | per-row, 12-bit / 8-bit multipliers | 99.00% / 98.24% | — | 0 | 0 | — |
| 32 | float head (reference) | — | 68.92% | — | — | — |
| 32 | per-tensor (design) | 98.26% (2264/2304) | 68.32% | 0 | 0 | 0.00078 |
| 32 | per-row, float scales / 12-bit | 98.52% / 98.39% | — | 0 | 0 | 0.00045 |
| both | per-tensor / per-row float / 12-bit / 8-bit | 98.45 / 98.91 / 98.88 / 98.19% | | 0 | 0 | |

By domain (T128): per-tensor 98.46% FineWeb-Edu, 98.55% licence; per-row
98.76% / 99.24%. Last position only (72 per T): per-tensor 98.61% (T128),
100% (T32). Binomial 1-sigma about 0.11 pt; positions within a sequence are
correlated, so the real uncertainty is larger.

Decomposition (pooled, `data/s7_decomp.json`):

| norm output y | head weights | vs float head |
|---|---|---:|
| exact | per-tensor int8 | 98.76% |
| exact | per-row int8 | 99.55% |
| int8 | float | 98.94% |
| int8 | per-tensor (design) | 98.45% |
| int8 | per-row | 98.91% |
| int16, refusal-free | per-tensor | 98.78% |
| int16 | per-row, 12-bit multipliers | **99.57%** |
| int16 | per-row, 8-bit multipliers | 98.46% |

Cn sweep (diagnostic; per-tensor / per-row; 0 refusals): Cn 1,024
(refusal-free for any input) 93.65 / 93.72%; 5,664 (calibration rule) 98.45 /
98.91%; 6,797 98.41 / 99.04%; 8,497 98.65 / 99.10%.

Misses by float top-2 margin (per-tensor): T128 19/57 (< 0.01), 43/112
(0.01–0.03), 68/423 (0.03–0.1), 8/1,042 (0.1–0.3), **0/7,582 (>= 0.3)**; T32
8/21, 9/33, 21/111, 2/313, **0/1,826**. One integer LSB is 1.72e-4 float
logits.

Windows: max |l| 181,485 (17.47 bits, T128), 154,459 (T32), bound
33,032,192. Keyed difference measured max 33 bits against the design's 41.
Worst-case windows [COUNTED]: per-tensor 41; per-row 8-bit 49; per-row 12-bit
53; int16 per-tensor 49; int16 per-row 8-bit 57; int16 per-row 12-bit 61.

## 4. F4 prefix consistency [MEASURED] (`data/s5_prefix.json`)

Sequences 0, 1, 36, 37: T128 vs its T64 / T32 prefixes, 0 differing words in
all 22 layers at positions < T'. First 64 tokens kept, the rest swapped: 0
differing words at positions < 64; control: 524,155 of 524,288 layer-21 words
at positions >= 64 differ. No refusals.

## 5. Not done, caveats

F3 (greedy continuations) and F6 (right-padded hidden-selector inputs) not
run. Python reference only. 72 sequences per T, two domains, no chat data.
The calibration maximum came from the float model. The int16 norm output is
not a relation the design has; adopting it needs the design lane and the
security owner.

## 6. Files and commands

Under `results/zk60_token_io_fidelity_20261017/`: `tools/` (B4 snapshot copies
`tlcalib` d42a8647…, `b3calib` 637cd418…, `corpus`, `corpus4`, `spm_bpe`,
`b4_token_io.py`; lane scripts `fid_common.py`, `s1_tokens.py`, `s2_float.py`,
`s3_int.py`, `s4_head.py`, `s5_prefix.py`, `s6_tables.py`, `s7_decomp.py`),
`data/`, `logs/` (each run's log, `.done` = 0, guard JSON). Every step ran
detached through the resource guard, class light: s1 3 s / 0.15 GiB; s2 775 s
/ 0.78; s3 196 + 584 s / 0.69, 1.34; s5 141 s / 0.99; s4 41 + 314 s / 1.80,
1.97; s7 130 s / 1.71; tables unguarded.
