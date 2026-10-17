# TinyLlama-1.1B calibrated integer blocks — export `dg_rot1_export_T32`

**Scope: calibration data, not a proof, not a privacy claim, not proof readiness.** These files are the public
integer words (int8 weights, int8 norm gains, exp / SiLU / RoPE tables, per-layer constants) that the native
private-block prover would bind, plus one held-out sequence's exact integer hidden states for a bit-exact
parity check. The fidelity numbers below come from a Python/numpy reference of the native relations
(`tlcalib.i_block`), not from the native prover.

Schema `zk60-trained-profile-export/1`. Model `TinyLlama/TinyLlama-1.1B-Chat-v1.0` revision `fe8a4ea1ffedaf415f4da2f062534de366a451e6`, `model.safetensors` sha256 `6e6001da2106d4757498752a021df6c2bdc332c650aae4bae6b0c004dcf14933`. T = 32 tokens. 22 layers.

## Variant

`{"cn_max": 65536, "margin": 0.5, "margin_ch": 3.0, "margin_pow2": 0.25, "name": "dg", "norm_cn": "layer", "residual": "global", "rotate": 1, "shapes": ["range", "smooth", "gamma"], "shifts": "free", "tables": "layer", "tn": 10}`

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
 "norm_ceps": 91255,
 "norm_cn_a": null,
 "norm_cn_m": null,
 "norm_tn": 10,
 "rope_theta": 10000.0,
 "sh_ao": null,
 "sh_g": 8,
 "sh_h": null,
 "sh_o": 9,
 "sh_qkv": 8,
 "sh_r2": 0,
 "sh_rope": 7,
 "sh_s": null,
 "sh_u": 0,
 "sh_z": null,
 "silu_member": null
}
```

Constants that differ per layer: ['exp_e_s', 'norm_cn_a', 'norm_cn_m', 'sh_ao', 'sh_h', 'sh_s', 'sh_z', 'silu_member'].

| layer | Cn_a | Cn_m | Ceps | e_s | SiLU (e_in,e_out) | SH qkv/s/ao/g/h/z | sh_r2 |
|---|---|---|---|---|---|---|---|
| 0 | 1191 | 1085 | 91255 | 1 | (-5, -13) | 8/6/7/8/14/8 | 0 |
| 1 | 2203 | 2101 | 91255 | 1 | (-5, -13) | 8/7/6/8/14/8 | 0 |
| 2 | 2439 | 817 | 91255 | 1 | (-2, -11) | 8/7/6/8/16/6 | 0 |
| 3 | 3999 | 2364 | 91255 | 1 | (-5, -13) | 8/7/5/8/14/8 | 0 |
| 4 | 2803 | 2233 | 91255 | 1 | (-4, -13) | 8/6/5/8/15/8 | 0 |
| 5 | 2629 | 2134 | 91255 | 1 | (-5, -13) | 8/6/5/8/15/8 | 0 |
| 6 | 3650 | 1554 | 91255 | 1 | (-4, -13) | 8/6/5/8/14/8 | 0 |
| 7 | 2897 | 641 | 91255 | 1 | (-1, -10) | 8/6/4/8/16/5 | 0 |
| 8 | 2645 | 1566 | 91255 | 2 | (-4, -13) | 8/6/4/8/14/8 | 0 |
| 9 | 2555 | 2621 | 91255 | 1 | (-4, -12) | 8/6/5/8/14/8 | 0 |
| 10 | 2663 | 1834 | 91255 | 1 | (-4, -13) | 8/6/5/8/14/8 | 0 |
| 11 | 2626 | 1811 | 91255 | 1 | (-4, -12) | 8/6/4/8/14/8 | 0 |
| 12 | 2648 | 1617 | 91255 | 1 | (-4, -12) | 8/5/4/8/13/8 | 0 |
| 13 | 2866 | 2083 | 91255 | 1 | (-4, -12) | 8/6/5/8/14/8 | 0 |
| 14 | 2685 | 1895 | 91255 | 1 | (-4, -12) | 8/5/4/8/14/8 | 0 |
| 15 | 2647 | 1553 | 91255 | 2 | (-3, -11) | 8/6/4/8/13/8 | 0 |
| 16 | 3807 | 1746 | 91255 | 1 | (-3, -11) | 8/6/4/8/14/8 | 0 |
| 17 | 2814 | 2370 | 91255 | 1 | (-4, -12) | 8/5/4/8/14/8 | 0 |
| 18 | 2601 | 1817 | 91255 | 1 | (-3, -11) | 8/5/3/8/14/8 | 0 |
| 19 | 2952 | 2693 | 91255 | 1 | (-3, -11) | 8/5/3/8/14/8 | 0 |
| 20 | 2989 | 2151 | 91255 | 1 | (-3, -11) | 8/5/3/8/14/7 | 0 |
| 21 | 3732 | 3122 | 91255 | 1 | (-1, -11) | 8/6/3/8/16/5 | 0 |

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

* held-out sequences refused by the native relations (never clamped silently): 1 of 36; calibration refused: 1 of 54.
* accepted held-out (35 sequences, 1085 predicted positions): top-1 agreement with
  float 0.7539170506912443, perplexity float 30.062369634565165 vs integer 32.621782064382174,
  mean KL(float || integer) 0.25384625114543896 nats.
* all held-out (refusals clamped to continue: DIAGNOSTIC ONLY): top-1 0.757168458781362, ppl integer 31.806667361670428.

Residual scale(s): 0.000473736 at layer 0 input.

Calibration tool: `results/zk60_1b_calibration_20260929` with sha256 {"b3_ladder.py": "edd51658563a8461d564b9901444530ce3221ed72f4e42d09652593de69b2cb0", "b3calib.py": "fa67026894d33f862de7e10e1b52aa35cfd2fdeb64328b3084920c30227087fe", "corpus.py": "273e4ef41f8b18fb14b0e3568f9825ba6c0d4c09e08ebfad323c6c77543ba7f6", "spm_bpe.py": "26f8be84ca392489d81bf30b16866e08ecfe70a4e5be7108ecd61d26babec663", "tlcalib.py": "7df863ea23d3c5f9813abe184cd51631c125e31805c3178bf2cd8843b8c7fbb5"}.
