# TinyLlama-1.1B calibrated integer blocks — export `pg_rot1_b4_T128`

**Scope: calibration data, not a proof, not a privacy claim, not proof readiness.** These files are the public
integer words (int8 weights, int8 norm gains, exp / SiLU / RoPE tables, per-layer constants) that the native
private-block prover would bind, plus one held-out sequence's exact integer hidden states for a bit-exact
parity check. The fidelity numbers below come from a Python/numpy reference of the native relations
(`tlcalib.i_block`), not from the native prover.

Schema `zk60-trained-profile-export/1`. Model `TinyLlama/TinyLlama-1.1B-Chat-v1.0` revision `fe8a4ea1ffedaf415f4da2f062534de366a451e6`, `model.safetensors` sha256 `6e6001da2106d4757498752a021df6c2bdc332c650aae4bae6b0c004dcf14933`. T = 128 tokens. 22 layers.

## Variant

`{"cn_max": 65536, "margin": 0.5, "margin_ch": 3.0, "margin_pow2": 0.25, "name": "pg", "norm_cn": "profile", "o16": false, "residual": "global", "rotate": 1, "shapes": ["range", "smooth", "gamma"], "shifts": "profile", "tables": "layer", "tn": 10}`

* `norm_cn` profile = one Cn per norm type for every layer; layer = per layer.
* `tables` profile = one exp e_s and one SiLU member for every layer; layer = per layer (still native
  generators / frozen registry members, chosen per block).
* `residual` global = one residual scale s_x for the whole stack (residual-2 rescale k = sh_r2 = 0);
  layer = per-layer power-of-two rescale x2 = requant(x1 + (z << k), k), k = sh_r2 >= 0.
* `shifts` native = the toy shifts (SH_QKV 7, rope 7, S 6, O 9, AO 7, G 7, U 0, H 14, Z 6); free = per layer
  inside the structure-preserving windows (one-byte sites 1..8, O and product 9..16); profile = one set.
* `rotate` = seed of a randomized Hadamard rotation of the residual basis (public-weight change only:
  gammas folded into the consumers, gains of the rotated norms carried by the int8 gain vectors).

## Constants

Uniform over all layers (`null` = differs per layer; see each `layer_NN/manifest.json`):

```
{
 "exp_e_s": null,
 "f_e": 9,
 "f_p": 9,
 "f_ro": 7,
 "norm_ceps": 74429,
 "norm_cn_a": 3583,
 "norm_cn_m": 2873,
 "norm_tn": 10,
 "rope_theta": 10000.0,
 "sh_ao": 3,
 "sh_g": 8,
 "sh_h": 14,
 "sh_o": 9,
 "sh_qkv": 8,
 "sh_r2": 0,
 "sh_rope": 7,
 "sh_s": 6,
 "sh_u": 0,
 "sh_z": 4,
 "silu_member": null
}
```

Constants that differ per layer: ['exp_e_s', 'silu_member'].

| layer | Cn_a | Cn_m | Ceps | e_s | SiLU (e_in,e_out) | SH qkv/s/ao/g/h/z | sh_r2 |
|---|---|---|---|---|---|---|---|
| 0 | 3583 | 2873 | 74429 | 1 | (-5, -13) | 8/6/3/8/14/4 | 0 |
| 1 | 3583 | 2873 | 74429 | 2 | (-5, -13) | 8/6/3/8/14/4 | 0 |
| 2 | 3583 | 2873 | 74429 | 1 | (-2, -11) | 8/6/3/8/14/4 | 0 |
| 3 | 3583 | 2873 | 74429 | 1 | (-5, -13) | 8/6/3/8/14/4 | 0 |
| 4 | 3583 | 2873 | 74429 | 1 | (-3, -12) | 8/6/3/8/14/4 | 0 |
| 5 | 3583 | 2873 | 74429 | 1 | (-5, -13) | 8/6/3/8/14/4 | 0 |
| 6 | 3583 | 2873 | 74429 | 2 | (-4, -13) | 8/6/3/8/14/4 | 0 |
| 7 | 3583 | 2873 | 74429 | 2 | (-1, -9) | 8/6/3/8/14/4 | 0 |
| 8 | 3583 | 2873 | 74429 | 3 | (-4, -13) | 8/6/3/8/14/4 | 0 |
| 9 | 3583 | 2873 | 74429 | 1 | (-4, -12) | 8/6/3/8/14/4 | 0 |
| 10 | 3583 | 2873 | 74429 | 1 | (-4, -13) | 8/6/3/8/14/4 | 0 |
| 11 | 3583 | 2873 | 74429 | 2 | (-4, -12) | 8/6/3/8/14/4 | 0 |
| 12 | 3583 | 2873 | 74429 | 2 | (-4, -12) | 8/6/3/8/14/4 | 0 |
| 13 | 3583 | 2873 | 74429 | 2 | (-4, -12) | 8/6/3/8/14/4 | 0 |
| 14 | 3583 | 2873 | 74429 | 2 | (-4, -12) | 8/6/3/8/14/4 | 0 |
| 15 | 3583 | 2873 | 74429 | 2 | (-3, -11) | 8/6/3/8/14/4 | 0 |
| 16 | 3583 | 2873 | 74429 | 2 | (-3, -11) | 8/6/3/8/14/4 | 0 |
| 17 | 3583 | 2873 | 74429 | 2 | (-3, -11) | 8/6/3/8/14/4 | 0 |
| 18 | 3583 | 2873 | 74429 | 2 | (-3, -11) | 8/6/3/8/14/4 | 0 |
| 19 | 3583 | 2873 | 74429 | 2 | (-3, -11) | 8/6/3/8/14/4 | 0 |
| 20 | 3583 | 2873 | 74429 | 2 | (-3, -11) | 8/6/3/8/14/4 | 0 |
| 21 | 3583 | 2873 | 74429 | 2 | (-1, -11) | 8/6/3/8/14/4 | 0 |

Notes on constants: `norm_tn` 10 keeps the four-limb norm window (tn + 1 + bits(D_max) = 32 at width 2048,
D_max = isqrt(2048 * 32768^2 + Ceps) < 2^21). `norm_ceps` = round(d * eps / s_x^2) reproduces RMSNorm's
eps = 1e-5 at the layer's residual scale; values above 2684 are outside the bound the 2026-09-30 contract
review checked (`results/zk60_trained_contract_review_20260930/HANDOFF.md`) and need that no-wrap argument
re-run (Ceps only enters the norm's sum of squares). `norm_cn` <= 65536 (the reviewed bound).

## Files

* `profile.json` — schema, model pin, calibration tool sha256s, T, constants, layer list (with each
  manifest's sha256), sequences, out-of-proof metadata (residual scales, per-layer float scales, rotation).
* `layer_NN/manifest.json` — the layer's constants, table keys + spec digests, and every array
  `{file, dtype, shape, sha256}`.
* `layer_NN/*.bin` — raw little-endian, UNPADDED, native orientations: `wq` int8 (2048, 2048), `wk`/`wv`
  int8 (256, 2048), `wo` int8 (2048, 2048) — all (output, input); `gamma_a`/`gamma_m` int8 [2048];
  `wg_t`/`wu_t` int8 (2048, 5632) and `wd_t` int8 (5632, 2048) — (input, output); `exp` int64[256];
  `act` int16[256]; `rope_cos`/`rope_sin` int64 (T, 32) (the native generator's tables, for cross-check).
  No int8 word is -128.
* `seq_hoNN/x_in_LNN.bin`, `x_out_LNN.bin` — int16 (T, 2048): the exact integer block's input and output of
  layer NN on held-out sequence NN (chained: x_in of layer N+1 = x_out of layer N), plus `manifest.json`
  with the token ids, source and selection rule (the first held-out sequence(s) accepted at every layer,
  no fidelity-based choice).

Tables: exp = `tables_attn.rs exp_member(e_s, 64, 9)`; act = `zkp-core tables.rs int16out_member(Silu, e_in,
e_out)` (frozen registry; digest re-checked against the pin); rope = `rope_tables_generate(T, 64, 10000.0, 7)`.
All generators were re-implemented in `b3calib.py` and reproduce the native pins byte for byte
(`verify_tables`: 9/9 SiLU registry digests, exp pins for e_s -1/-2, RoPE t16/t32 pins).

## Independent check

`b3_verify_export.py` (reads only these files): ok = **True**, layers 22, sequences {"seq_ho00": {"layers_bit_exact": 22, "tokens": 128}, "seq_ho36": {"layers_bit_exact": 22, "tokens": 128}}, errors none. It re-hashes every array, regenerates
every table from its key, and re-runs the exact integer block from the binaries: x_out is reproduced bit
for bit at every layer and the chain is continuous.

## Fidelity (calibration evidence, NOT a proof)

Calibration: 108 sequences x T=128 (licence/docstring domain: GPL-3, GFDL-1.3, MPL-2.0 and six Python 3.10 stdlib modules' docstrings; FineWeb-Edu domain: row group 0 of the local shard); held-out: 72 sequences x T=128 from DISJOINT sources (Apache-2.0, LGPL-2.1,
Artistic and six other stdlib modules; FineWeb-Edu row group 1). Float reference: float32 HF-Llama semantics; final norm + LM head in float outside the proved stack (D13).

* held-out sequences refused by the native relations (never clamped silently): 0 of 72; calibration refused: 0 of 108.
* accepted held-out (72 sequences, 9144 predicted positions): top-1 agreement with
  float 0.7344706911636045, perplexity float 10.040848433788131 vs integer 13.779621541361866,
  mean KL(float || integer) 0.3926361512083566 nats.
* all held-out (refusals clamped to continue: DIAGNOSTIC ONLY): top-1 0.7344706911636045, ppl integer 13.779621541361866.


Calibration: T_cal = 128, 108 sequences, domains ['fineweb-edu', 'licence-docstring']; FineWeb-Edu HuggingFaceFW/fineweb-edu (sample/10BT, shard 000_00000) rev 87f09149ef4734204d70ed1d046ddc9ca3f2b8f9 (no licence file in /home/victor/models/fineweb-edu; the public dataset card states ODC-By 1.0 and use subject to the Common Crawl terms of use (recorded, not verified offline)).

| held-out domain | sequences | refused | top-1 (all) | ppl float / int (all) | KL (all) | top-1 (accepted) |
|---|---|---|---|---|---|---|
| fineweb-edu | 36 | 0 | 0.745 | 12.67 / 15.80 | 0.298 | 0.745 |
| licence-docstring | 36 | 0 | 0.724 | 7.96 / 12.01 | 0.488 | 0.724 |

Token I/O: `embedding_int16.bin` (int16 [32000, 2048], sha256 `ad68c716693f12d17cd19c957fbe84ca0f94d79063735f7eb84ead8063d9ab06`) gives x_in_L00 = table[token] exactly; the output side and the rotation are specified in `../TOKEN_IO_SPEC.md`.

Residual scale(s): 0.000524558 at layer 0 input.

Calibration tool: `results/zk60_1b_calibration_20260929` with sha256 {"b3_ladder.py": "bf637099c9de78fe15bb53b75865668fc66544af8d4a261de57d0828ce56e1b9", "b3calib.py": "637cd41812501398bacef558a7ce949f33439b2878f37db64940e718ea5e77ff", "corpus.py": "273e4ef41f8b18fb14b0e3568f9825ba6c0d4c09e08ebfad323c6c77543ba7f6", "corpus4.py": "1b3b08ca070391d76e8b8b91f3a5a7247d567553052085e9dd0f139f7f51da0c", "spm_bpe.py": "26f8be84ca392489d81bf30b16866e08ecfe70a4e5be7108ecd61d26babec663", "tlcalib.py": "d42a8647f8f98989e3c03b33b55e459b4ad9046f187b3721767470f3f9f58c81"}.
