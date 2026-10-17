# TinyLlama-1.1B calibrated integer blocks — export `a_export_T32`

**Scope: calibration data, not a proof, not a privacy claim, not proof readiness.** These files are the public
integer words (int8 weights, int8 norm gains, exp / SiLU / RoPE tables, per-layer constants) that the native
private-block prover would bind, plus one held-out sequence's exact integer hidden states for a bit-exact
parity check. The fidelity numbers below come from a Python/numpy reference of the native relations
(`tlcalib.i_block`), not from the native prover.

Schema `zk60-trained-profile-export/1`. Model `TinyLlama/TinyLlama-1.1B-Chat-v1.0` revision `fe8a4ea1ffedaf415f4da2f062534de366a451e6`, `model.safetensors` sha256 `6e6001da2106d4757498752a021df6c2bdc332c650aae4bae6b0c004dcf14933`. T = 32 tokens. 22 layers.

## Variant

`{"cn_max": 65536, "margin": 0.5, "margin_ch": 3.0, "margin_pow2": 0.25, "name": "a", "norm_cn": "profile", "residual": "global", "rotate": null, "shapes": ["range", "smooth", "gamma"], "shifts": "native", "tables": "profile", "tn": 10}`

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
 "exp_e_s": 2,
 "f_e": 9,
 "f_p": 9,
 "f_ro": 7,
 "norm_ceps": 259,
 "norm_cn_a": 4511,
 "norm_cn_m": 2438,
 "norm_tn": 10,
 "rope_theta": 10000.0,
 "sh_ao": 7,
 "sh_g": 7,
 "sh_h": 14,
 "sh_o": 9,
 "sh_qkv": 7,
 "sh_r2": 0,
 "sh_rope": 7,
 "sh_s": 6,
 "sh_u": 0,
 "sh_z": 6,
 "silu_member": [
  -1,
  -10
 ]
}
```

Constants that differ per layer: none.

| layer | Cn_a | Cn_m | Ceps | e_s | SiLU (e_in,e_out) | SH qkv/s/ao/g/h/z | sh_r2 |
|---|---|---|---|---|---|---|---|
| 0 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 1 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 2 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 3 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 4 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 5 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 6 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 7 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 8 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 9 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 10 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 11 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 12 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 13 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 14 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 15 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 16 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 17 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 18 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 19 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 20 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |
| 21 | 4511 | 2438 | 259 | 2 | (-1, -10) | 7/6/7/7/14/6 | 0 |

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

`b3_verify_export.py` (reads only these files): ok = **True**, layers 22, sequences {"seq_ho00": {"layers_bit_exact": 22, "tokens": 32}, "seq_ho01": {"layers_bit_exact": 22, "tokens": 32}}, errors none. It re-hashes every array, regenerates
every table from its key, and re-runs the exact integer block from the binaries: x_out is reproduced bit
for bit at every layer and the chain is continuous.

## Fidelity (calibration evidence, NOT a proof)

Calibration: 54 sequences x T=32 (GPL-3, GFDL-1.3, MPL-2.0 and six
Python 3.10 stdlib modules' docstrings); held-out: 36 sequences x T=32 from DISJOINT sources (Apache-2.0, LGPL-2.1,
Artistic and six other stdlib modules). Float reference: float32 HF-Llama semantics; final norm + LM head
in float outside the proved stack (D13).

* held-out sequences refused by the native relations (never clamped silently): 21 of 36; calibration refused: 32 of 54.
* accepted held-out (15 sequences, 465 predicted positions): top-1 agreement with
  float 0.13978494623655913, perplexity float 24.540217323590547 vs integer 1430.1530464199911,
  mean KL(float || integer) 4.753205286584937 nats.
* all held-out (refusals clamped to continue: DIAGNOSTIC ONLY): top-1 0.13620071684587814, ppl integer 1378.5486924112715.

Residual scale(s): 0.00889853 at layer 0 input.

Calibration tool: `results/zk60_1b_calibration_20260929` with sha256 {"b3_ladder.py": "edd51658563a8461d564b9901444530ce3221ed72f4e42d09652593de69b2cb0", "b3calib.py": "fa67026894d33f862de7e10e1b52aa35cfd2fdeb64328b3084920c30227087fe", "corpus.py": "273e4ef41f8b18fb14b0e3568f9825ba6c0d4c09e08ebfad323c6c77543ba7f6", "spm_bpe.py": "26f8be84ca392489d81bf30b16866e08ecfe70a4e5be7108ecd61d26babec663", "tlcalib.py": "7df863ea23d3c5f9813abe184cd51631c125e31805c3178bf2cd8843b8c7fbb5"}.
