# Llama-3-8B calibrated integer blocks — export `llama3_8b_pg_rot1_T32`

**Scope: calibration data, not a proof, not a privacy claim, not proof readiness.** Public integer words (int8 weights, int8 norm gains, exp / SiLU / RoPE tables, per-layer constants) for the native private-block prover at the Llama-3-8B geometry, plus held-out sequences' exact integer hidden states for bit-exact parity. Fidelity numbers come from the Python reference of the native relations (`tlcalib.i_block`).

Schema `zk60-trained-profile-export/1`. Model `NousResearch/Meta-Llama-3-8B` (Llama-3-8B (Meta Llama 3)) revision `315b20096dc791d381d514deb5f8bd9c8d6d3061`; shard sha256 {"model-00001-of-00004.safetensors": "f2c144103072514542e327fa8080bd375cb300f2d453fba9ca3aea81d0d4cf33", "model-00002-of-00004.safetensors": "d9eee5f23d94405d90b7e9ff88b9443fee42f8528a658f54214c2aba7530d80c", "model-00003-of-00004.safetensors": "4b8fbc5e113f69768dd8de84661ea20af8a32b734a9976144b4236c447b40ccc", "model-00004-of-00004.safetensors": "5dc34e6bdf2da9e35f0d93b5c333c870f3677dc43dc3a91ea3a8ad28a1fe1acb"}. Licence: the repo's `LICENSE` and `USE_POLICY.md` (Meta Llama 3 Community License + Acceptable Use Policy) are copied here with `NOTICE` ("Built with Meta Llama 3").

Geometry: width 4096, FFN 14336, 32 q / 8 kv heads (group 4), head_dim 128, 32 layers, RoPE theta 500000.0, RMSNorm eps 1e-05. T = 32.

## What the native lane must take from this export

* **RoPE base 500000.0** as this profile's own value (the accepted TinyLlama class pins 10000): every `rope_cos/rope_sin` is `rope_tables_generate(T, 128, 500000.0, 7)` (tables_attn.rs semantics, re-implemented in Python; digest in each manifest).
* **head_dim 128**: exp tables are `exp_member(e_s, 128, f_e)`; RoPE half-width 64.
* **norm**: tn 9 (D24 at width 4096); D_max = isqrt(Ceps + 4096 * 32768^2) has 22 bits, window 9 + 1 + 22 = 32 (four limbs).
* constants follow the D24 windows (qkv/s/g/z 1..8, o/h 9..16, ao 0..8; Cn <= 2^20; Ceps <= 2^40; per-layer e_s and frozen SiLU member).
* FFN 14336 pads to 16384; vocabulary 128256 and BOS id 128000 stay outside the block proof.

## Constants

Uniform over all layers (`null` = per layer):

```
{
 "exp_e_s": null,
 "f_e": 9,
 "f_p": 9,
 "f_ro": 7,
 "norm_ceps": 78617,
 "norm_cn_a": 2266,
 "norm_cn_m": 1557,
 "norm_tn": 9,
 "rope_theta": 500000.0,
 "sh_ao": 3,
 "sh_g": 8,
 "sh_h": 14,
 "sh_o": 9,
 "sh_qkv": 8,
 "sh_r2": 0,
 "sh_rope": 7,
 "sh_s": 6,
 "sh_u": 0,
 "sh_z": 5,
 "silu_member": null
}
```

| layer | e_s | SiLU (e_in,e_out) |
|---|---|---|
| 0 | 2 | (-4, -12) |
| 1 | 2 | (-2, -11) |
| 2 | 2 | (-4, -13) |
| 3 | 1 | (-4, -13) |
| 4 | 1 | (-4, -12) |
| 5 | 2 | (-4, -12) |
| 6 | 2 | (-3, -12) |
| 7 | 2 | (-4, -12) |
| 8 | 2 | (-4, -12) |
| 9 | 1 | (-4, -12) |
| 10 | 2 | (-4, -12) |
| 11 | 1 | (-4, -12) |
| 12 | 1 | (-3, -12) |
| 13 | 1 | (-4, -12) |
| 14 | 2 | (-3, -12) |
| 15 | 2 | (-3, -11) |
| 16 | 2 | (-3, -11) |
| 17 | 1 | (-3, -11) |
| 18 | 2 | (-3, -11) |
| 19 | 2 | (-3, -11) |
| 20 | 1 | (-3, -11) |
| 21 | 2 | (-3, -11) |
| 22 | 2 | (-3, -11) |
| 23 | 2 | (-3, -11) |
| 24 | 2 | (-3, -11) |
| 25 | 2 | (-3, -11) |
| 26 | 2 | (-3, -11) |
| 27 | 2 | (-3, -11) |
| 28 | 2 | (-3, -11) |
| 29 | 2 | (-2, -11) |
| 30 | 2 | (-2, -11) |
| 31 | 4 | (-1, -10) |

## Files

* `layer_NN/*.bin` raw little-endian, UNPADDED: `wq` int8 (4096, 4096), `wk`/`wv` int8 (1024, 4096), `wo` int8 (4096, 4096) — (output, input); `gamma_a`/`gamma_m` int8 [4096]; `wg_t`/`wu_t` int8 (4096, 14336), `wd_t` int8 (14336, 4096) — (input, output); `exp` int64[256]; `act` int16[256]; `rope_cos`/`rope_sin` int64 (32, 64). No int8 word is -128.
* `seq_hoNN/` int16 (T, 4096) x_in/x_out per layer of one held-out sequence per domain, continuous chain.
* `rotation.json` / `rotation_sign.bin`: R = H diag(sign)/sqrt(4096), x' = x R^T (public-weight preparation).

## Independent check

`b3_verify_export.py` (ZK60_MODEL=llama3-8b, reads only these files): ok = **True**, layers 32, sequences {"seq_ho00": {"layers_bit_exact": 32, "tokens": 32}, "seq_ho36": {"layers_bit_exact": 32, "tokens": 32}}, errors none.

## Fidelity (calibration evidence, NOT a proof)

Calibration 54 sequences x T=32 (licence/docstring + FineWeb-Edu row group 0); held-out from disjoint sources (licence/docstring held-out files + FineWeb-Edu row group 1). Tokenizer: the repo's tokenizer.json at the pinned revision (sha256 e134af98b985517b4f068e3755ae90d4e9cd2d45d328325dc503f1c6b2d06cc7). Float reference: float32; final norm + head in float outside the proof (D13).

| held-out domain | sequences | refused | top-1 (all) | ppl float / int | KL |
|---|---|---|---|---|---|
| fineweb-edu | 36 | 1 | 0.623 | 18.85 / 37.11 | 0.737 |
| licence-docstring | 36 | 0 | 0.547 | 22.81 / 49.75 | 1.060 |

Residual scale s_x 0.000721808 (one scale, rotated basis). Calibration tool sha256: {"b3_ladder.py": "13675c3b7797bd65b1954b2cee922381333c0ecc323dd3b1be9e8be8e8b16f0b", "b3calib.py": "f2994c63649328569d92923bf615f0dd97d2664853c350faadec1472cfdbe27c", "b5_8b.py": "27f9c415faba7e2a1f0acc9ff5db3b34be9788105701ed828b9d98fdb33e5314", "corpus.py": "273e4ef41f8b18fb14b0e3568f9825ba6c0d4c09e08ebfad323c6c77543ba7f6", "corpus4.py": "1b3b08ca070391d76e8b8b91f3a5a7247d567553052085e9dd0f139f7f51da0c", "tlcalib.py": "1c373d16e66b575261b995015e5b72f686bfb08cf02a588a1f1d86b1bdba56c3"}.
