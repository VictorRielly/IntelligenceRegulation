# Token I/O for this export (rung R3, Llama-3-8B)

Calibration lane B8, written by `results/zk60_8b_calibration_20261017/b8_token_io.py` (build). Public model data
and calibration data: not a proof, not a privacy claim. Format and rules as the TinyLlama R2 inputs
(`results/zk60_1b_calibration_20260929/export/TOKEN_IO_SPEC.md`; the fidelity lane's `s4_head.py` per-row head;
D25 T3 ties to the lowest id, T4 as amended: per-row int8 + 12-bit multipliers). Hashes of every file: `SHA256SUMS`.

| file | content |
|---|---|
| `embedding_int16.bin` | int16 LE [128256, 4096]: x_in_L00[t] = table[token_t] (TOKEN_IO_SPEC steps 1-3 at s_in = 0.0007218075732845454, rotated basis seed 1); sha256 8b5a5fb10fb331dd5b8882bac6717d800f88a2b9a6affe1c7b7b75238686f1ca |
| `head_int8_perrow.bin` | int8 [128256, 4096] row-major: W' = lm_head diag(norm_weight) R^T, row j quantised at s_j = max_i abs(W'_j,i) / 127, round half up, clip +-127 (0 clipped, 0 words -128); sha256 f50ba1aa4150172ffb381a335faa41050abf9a45c1ab6b0cbc6401ac8db228cc |
| `head_mult12.bin` | int64 LE [128256]: m_j = max(1, floor(2^12 s_j / max s + 0.5)), in [859, 4096], 2304 distinct; sha256 9eafb7f4ecd6a6f14ef0c1d8186be69c2f9ce70c034e81732423936c8ee0d1f3 |
| `calib_final_xhat_rot_absmax.bin` | float64 [4096]: per-channel max abs of the rotated xhat of the calibration set's final residual (the final-norm Cn input) |
| `head_manifest.json`, `token_io.json` | digests, shapes, rules, scales, source tensor digests |
| `f2_fidelity.json` | the checks and F2 below, in full |

Final norm (block norm relation, uniform gain): g0 127, tn 9 (window 32 bits at width 4096),
Ceps 78617 (= the profile's), **Cn 4234** by the calibration rule (norm_site, c = 1, margin 0.5);
refusal-free alternative Cn = 2^tn = 512. Integer next token: y = final norm of x_out_L31; l_j = y . W'q_j
(raw, exact); C_j = m_j l_j; token = first maximum of C (lowest id on ties). Keyed window: bits(2^17 x 2 d 127^2 x 2^12 + V - 1)
= 56 bits.

Checks [MEASURED]: the table reproduces x_in_L00 of every exported sequence (seq_ho00, seq_ho09) and the
run's whole held-out integer input chain (15 sequences x T 128); each exported x_out_L31 equals
the run's integer chain; final_norm == tlcalib.i_norm with a uniform gain (64 rows incl. int16 extremes).

F2, integer head vs the float head (TOKEN_IO_SPEC float path) on the SAME integer stack output, 15 held-out
sequences x T 128 = 1920 positions [MEASURED]:

| set | agreement |
|---|---|
| all positions | 99.06 % (1902/1920) |
| float top-2 margin >= 0.3 logits (D25 T4 criterion) | 100.00 % (1576/1576) -> criterion met: True |
| last position | 100.00 % (15/15) |
| domain:fineweb-edu | 98.96 % (760/768) |
| domain:licence-docstring | 99.13 % (1142/1152) |

Final-norm refusals: 0 positions. Exact ties in C: 0 positions (lowest id rule).
Max abs raw logit 640767 (20 bits; class bound 26 bits); max abs
scaled logit 30 bits; keyed delta needs 48 of 56 bits
(fits: True; strict off the argmax: True). Disagreements: 18
(by float margin in f2_fidelity.json). Shared box, n=1.
