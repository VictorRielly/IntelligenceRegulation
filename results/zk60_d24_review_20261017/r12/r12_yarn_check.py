"""D24 review r12 (independent): Shieldstral's YaRN RoPE tables.

My own binary64 transcription of transformers main `_compute_yarn_parameters`
(the copy at results/zk60_1b_native_20261017/r12/reference/
transformers_main_modeling_rope_utils.py, read by me), compared with:
  * the INSTALLED transformers 5.13.1 output the prep lane saved
    (crosscheck/inv_freq_transformers5131.npy, float32);
  * transformers 4.48.1's shipped-config default (correction range at
    max_position_embeddings = 262144; crosscheck/
    inv_freq_transformers448_maxpos262144.npy) — must DIFFER;
  * the prep lane's float64 reference table (rope_tables_reference.npz).
Integer tables round_half_up(cos/sin(t inv) * 2^7), digested as the native
tests digest them (SHA-256 of the LE int64 cos words, then the sin words),
for T in 128, 256, 512, 2048, and the entries a float32 frequency vector moves.
Writes r12_yarn_check.json beside itself. Usage: python3 -I r12_yarn_check.py
"""
import hashlib
import json
import math
import os
import struct

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
P = "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021/crosscheck"
CFG = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r12/reference/shieldstral_config.json"


def yarn(dim, base, factor, omax, beta_fast, beta_slow, truncate=True):
    def corr(rot):
        return (dim * math.log(omax / (rot * 2 * math.pi))) / (2 * math.log(base))
    low, high = corr(beta_fast), corr(beta_slow)
    if truncate:
        low, high = math.floor(low), math.ceil(high)
    low, high = max(low, 0), min(high, dim - 1)
    if low == high:
        high += 0.001
    inv = []
    for i in range(dim // 2):
        pos = base ** ((2 * i) / dim)  # base ** (arange(0, dim, 2) / dim)
        ramp = min(max((i - low) / (high - low), 0.0), 1.0)
        extra = 1.0 - ramp  # inv_freq_extrapolation_factor
        inv.append((1.0 / (factor * pos)) * (1.0 - extra) + (1.0 / pos) * extra)
    return inv, (low, high)


def rhu(x):
    """round half up, as tables_attn::round_half_up (floor(x + 0.5))"""
    return math.floor(x + 0.5)


def tables(inv, t_max, f_ro=7):
    s = 2.0 ** f_ro
    half = len(inv)
    c = [0] * (t_max * half)
    sn = [0] * (t_max * half)
    for i, w in enumerate(inv):
        for t in range(t_max):
            a = t * w
            c[t * half + i] = rhu(math.cos(a) * s)
            sn[t * half + i] = rhu(math.sin(a) * s)
    return c, sn


def digest(c, s):
    h = hashlib.sha256()
    h.update(b"".join(struct.pack("<q", v) for v in c))
    h.update(b"".join(struct.pack("<q", v) for v in s))
    return h.hexdigest()


cfg = json.load(open(CFG))
rp = cfg["text_config"]["rope_parameters"]
dim = cfg["text_config"]["head_dim"]
out = {"config_rope_parameters": rp, "head_dim": dim}
inv, rng = yarn(dim, rp["rope_theta"], rp["factor"], rp["original_max_position_embeddings"], rp["beta_fast"], rp["beta_slow"], rp.get("truncate", True))
out["correction_range"] = rng
mscale_af = (0.1 * rp["mscale"] * math.log(rp["factor"]) + 1.0) / (0.1 * rp["mscale_all_dim"] * math.log(rp["factor"]) + 1.0)
out["attention_factor_main"] = mscale_af
out["attention_factor_4_48_default"] = 0.1 * math.log(rp["factor"]) + 1.0
hf5 = np.load(os.path.join(P, "inv_freq_transformers5131.npy")).astype(np.float64)
hf448 = np.load(os.path.join(P, "inv_freq_transformers448_maxpos262144.npy")).astype(np.float64)
mine = np.array(inv)
out["max_rel_mine_vs_hf5131"] = float(np.max(np.abs(mine - hf5) / mine))
out["max_rel_mine_vs_hf448_shipped"] = float(np.max(np.abs(mine - hf448) / mine))
ref = np.load(os.path.join(P, "rope_tables_reference.npz"))
out["max_abs_mine_vs_prep_reference_inv_freq"] = float(np.max(np.abs(mine - ref["inv_freq"])))
out["prep_reference_bitwise_equal"] = bool(np.array_equal(mine, ref["inv_freq"]))
out["inv_freq_f64_bits"] = [struct.pack("<d", v).hex() for v in inv]
inv32 = [float(np.float32(v)) for v in hf5]  # transformers' own float32 frequencies
out["tables"] = {}
for t in (128, 256, 512, 2048):
    c, s = tables(inv, t)
    c32, s32 = tables(inv32, t)
    c448, s448 = tables(list(hf448), t)
    cu, su = tables([rp["rope_theta"] ** (-2.0 * i / dim) for i in range(dim // 2)], t)
    rows = {
        "sha256_mine_f64": digest(c, s),
        "entries": 2 * len(c),
        "entries_moved_by_hf5131_float32_frequencies": sum(a != b for a, b in zip(c + s, c32 + s32)),
        "entries_differing_from_4_48_shipped_default": sum(a != b for a, b in zip(c + s, c448 + s448)),
        "entries_differing_from_unscaled": sum(a != b for a, b in zip(c + s, cu + su)),
        "position0_ok": all(v == 128 for v in c[: dim // 2]) and all(v == 0 for v in s[: dim // 2]),
        "class_ok": all(-128 <= v <= 128 for v in c + s),
    }
    # the prep lane's float64 reference cos/sin (2048 x 64), rounded the same way
    rc = [rhu(float(x) * 128.0) for x in ref["cos"][:t].reshape(-1)]
    rs = [rhu(float(x) * 128.0) for x in ref["sin"][:t].reshape(-1)]
    rows["entries_differing_from_prep_reference_rounded"] = sum(a != b for a, b in zip(c + s, rc + rs))
    out["tables"][str(t)] = rows
json.dump(out, open(os.path.join(HERE, "r12_yarn_check.json"), "w"), indent=1)
print(json.dumps({k: v for k, v in out.items() if k != "inv_freq_f64_bits"}, indent=1))
