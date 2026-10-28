#!/usr/bin/env python3
"""NATIVE R12 (F1): the RoPE frequency transforms' REFERENCE values, for the
Rust tables to be checked against (`r12_tests::f1_*`).

Three independent computations per transform:
  (A) the transformers main-branch formulas (`reference/transformers_main_
      modeling_rope_utils.py`, `_compute_yarn_parameters` and
      `_compute_llama3_parameters`, fetched 2026-10-21) transcribed line for
      line in binary64 Python floats;
  (B) the same transcription in torch float32, as transformers computes it;
  (C) the INSTALLED transformers (4.48.1) functions themselves, called on a
      config adapted to the 4.48 signature: 4.48's YaRN reads the correction
      range at `config.max_position_embeddings` and has no mscale handling,
      so the adapted config sets max_position_embeddings = the original
      context (16384) and attention_factor = 1.0 explicitly — exactly what the
      main-branch formula computes for Shieldstral (mscale = mscale_all_dim);
      4.48's llama3 formula is the main branch's.
(A) is what the prover implements (binary64); (B) and (C) must agree with it
to float32 precision, which shows the transcription is the reference formula.
The integer tables `round_half_up(cos / sin (t inv) 2^7)` are built from (A)
and digested as the Rust test digests them (SHA-256 of the little-endian
int64 cos words, then the sin words); the table built from (B)'s float32
frequencies is compared entry by entry (how many of the 2^7-scaled entries a
float32 frequency would move).
usage: python3 rope_reference.py   (writes rope_reference.json beside itself)"""
import hashlib
import json
import math
import os
import struct

import torch

HERE = os.path.dirname(os.path.abspath(__file__))
F_RO = 7


def yarn_a(dim, base, factor, omax, beta_fast, beta_slow, mscale, mscale_all_dim, truncate=True):
    """transformers main `_compute_yarn_parameters`, binary64"""
    def get_mscale(scale, m=1):
        return 1.0 if scale <= 1 else 0.1 * m * math.log(scale) + 1.0
    attention_factor = get_mscale(factor, mscale) / get_mscale(factor, mscale_all_dim) if (mscale and mscale_all_dim) else get_mscale(factor)

    def find_correction_dim(num_rotations):
        return (dim * math.log(omax / (num_rotations * 2 * math.pi))) / (2 * math.log(base))
    low, high = find_correction_dim(beta_fast), find_correction_dim(beta_slow)
    if truncate:
        low, high = math.floor(low), math.ceil(high)
    low, high = max(low, 0), min(high, dim - 1)
    if low == high:
        high += 0.001
    out = []
    for i in range(dim // 2):
        pos = base ** ((2 * i) / dim)
        ramp = min(max((i - low) / (high - low), 0.0), 1.0)
        extra = 1.0 - ramp
        out.append((1.0 / (factor * pos)) * (1.0 - extra) + (1.0 / pos) * extra)
    return out, attention_factor


def yarn_b(dim, base, factor, omax, beta_fast, beta_slow, truncate=True):
    """the same in torch float32, as transformers computes it"""
    def find_correction_dim(num_rotations):
        return (dim * math.log(omax / (num_rotations * 2 * math.pi))) / (2 * math.log(base))
    low, high = find_correction_dim(beta_fast), find_correction_dim(beta_slow)
    if truncate:
        low, high = math.floor(low), math.ceil(high)
    low, high = max(low, 0), min(high, dim - 1)
    if low == high:
        high += 0.001
    pos_freqs = base ** (torch.arange(0, dim, 2).to(dtype=torch.float) / dim)
    inv_extra, inv_inter = 1.0 / pos_freqs, 1.0 / (factor * pos_freqs)
    ramp = torch.clamp((torch.arange(dim // 2, dtype=torch.float32) - low) / (high - low), 0, 1)
    ef = 1 - ramp
    return (inv_inter * (1 - ef) + inv_extra * ef).tolist()


def llama3_a(dim, base, factor, low_ff, high_ff, old):
    """transformers main `_compute_llama3_parameters`, binary64"""
    low_wl, high_wl = old / low_ff, old / high_ff
    out = []
    for i in range(dim // 2):
        inv = 1.0 / (base ** ((2 * i) / dim))
        wl = 2 * math.pi / inv
        il = inv / factor if wl > low_wl else inv
        if not (wl < high_wl) and not (wl > low_wl):
            smooth = (old / wl - low_ff) / (high_ff - low_ff)
            il = (1 - smooth) * il / factor + smooth * il
        out.append(il)
    return out


def llama3_b(dim, base, factor, low_ff, high_ff, old):
    inv = 1.0 / (base ** (torch.arange(0, dim, 2, dtype=torch.int64).to(dtype=torch.float) / dim))
    low_wl, high_wl = old / low_ff, old / high_ff
    wl = 2 * math.pi / inv
    il = torch.where(wl > low_wl, inv / factor, inv)
    smooth = (old / wl - low_ff) / (high_ff - low_ff)
    sm = (1 - smooth) * il / factor + smooth * il
    med = ~(wl < high_wl) * ~(wl > low_wl)
    return torch.where(med, sm, il).tolist()


def installed(kind, dim, base, **kw):
    """(C): the installed transformers 4.48 functions on an adapted config"""
    from transformers import PretrainedConfig
    from transformers.modeling_rope_utils import _compute_llama3_parameters, _compute_yarn_parameters
    if kind == "yarn":
        cfg = PretrainedConfig(rope_theta=base, head_dim=dim, hidden_size=dim * 32, num_attention_heads=32, max_position_embeddings=kw["omax"],
                               rope_scaling={"rope_type": "yarn", "factor": kw["factor"], "beta_fast": kw["beta_fast"], "beta_slow": kw["beta_slow"], "attention_factor": 1.0})
        inv, af = _compute_yarn_parameters(cfg, "cpu")
    else:
        cfg = PretrainedConfig(rope_theta=base, head_dim=dim, hidden_size=dim * 32, num_attention_heads=32, max_position_embeddings=kw["old"],
                               rope_scaling={"rope_type": "llama3", "factor": kw["factor"], "low_freq_factor": kw["low_ff"], "high_freq_factor": kw["high_ff"], "original_max_position_embeddings": kw["old"]})
        inv, af = _compute_llama3_parameters(cfg, "cpu")
    return inv.tolist(), af


def tables(inv, t_max):
    half = len(inv)
    c = [0] * (t_max * half)
    s = [0] * (t_max * half)
    for i, w in enumerate(inv):
        for t in range(t_max):
            a = t * w
            c[t * half + i] = math.floor(math.cos(a) * 2 ** F_RO + 0.5)
            s[t * half + i] = math.floor(math.sin(a) * 2 ** F_RO + 0.5)
    return c, s


def digest(c, s):
    h = hashlib.sha256()
    for v in c + s:
        h.update(struct.pack("<q", v))
    return h.hexdigest()


def bits(x):
    return struct.pack("<d", x).hex()


def main():
    t_max = 512
    out = {"t_max": t_max, "f_ro": F_RO, "cases": {}}
    cases = [
        ("shieldstral-yarn-hd128", "yarn", 128, 1_000_000.0, dict(factor=16.0, omax=16384, beta_fast=32.0, beta_slow=1.0, mscale=1.0, mscale_all_dim=1.0)),
        ("llama3_1-hd128", "llama3", 128, 500_000.0, dict(factor=8.0, low_ff=1.0, high_ff=4.0, old=8192)),
        ("llama3_1-hd64", "llama3", 64, 500_000.0, dict(factor=8.0, low_ff=1.0, high_ff=4.0, old=8192)),
    ]
    for name, kind, dim, base, kw in cases:
        if kind == "yarn":
            a, af = yarn_a(dim, base, kw["factor"], kw["omax"], kw["beta_fast"], kw["beta_slow"], kw["mscale"], kw["mscale_all_dim"])
            b = yarn_b(dim, base, kw["factor"], kw["omax"], kw["beta_fast"], kw["beta_slow"])
            cinst, afc = installed("yarn", dim, base, **kw)
        else:
            a, af = llama3_a(dim, base, kw["factor"], kw["low_ff"], kw["high_ff"], kw["old"]), 1.0
            b = llama3_b(dim, base, kw["factor"], kw["low_ff"], kw["high_ff"], kw["old"])
            cinst, afc = installed("llama3", dim, base, **kw)
        rel = lambda x, y: max(abs(p - q) / abs(p) for p, q in zip(x, y))
        ca, sa = tables(a, t_max)
        cb, sb = tables(b, t_max)
        moved = sum(1 for p, q in zip(ca + sa, cb + sb) if p != q)
        out["cases"][name] = dict(kind=kind, head_dim=dim, base=base, params=kw, attention_factor=af, attention_factor_installed=afc,
                                  inv_freq_f64_bits=[bits(x) for x in a], max_rel_a_vs_torch_f32=rel(a, b), max_rel_a_vs_installed=rel(a, cinst),
                                  table_sha256=digest(ca, sa), entries_moved_by_f32_frequencies=moved, unscaled_entries_differing=None)
        print(f"{name}: attention factor {af} (installed {afc}); max rel |A - torch f32| {rel(a, b):.2e}, |A - installed 4.48| {rel(a, cinst):.2e}; "
              f"table sha256 {digest(ca, sa)}; entries moved by f32 frequencies {moved} of {2 * t_max * dim // 2}")
    # the frozen generator's unscaled table at Shieldstral's base, for contrast
    un = [base ** (-2.0 * i / 128) for i in range(64) for base in [1_000_000.0]]
    cu, su = tables(un, t_max)
    ys = out["cases"]["shieldstral-yarn-hd128"]
    ca, sa = tables([struct.unpack("<d", bytes.fromhex(x))[0] for x in ys["inv_freq_f64_bits"]], t_max)
    ys["unscaled_entries_differing"] = sum(1 for p, q in zip(ca + sa, cu + su) if p != q)
    out["unscaled_theta_1e6_hd128_sha256"] = digest(cu, su)
    print(f"YaRN vs the unscaled table at theta 1e6: {ys['unscaled_entries_differing']} of {2 * t_max * 64} entries differ; unscaled sha256 {digest(cu, su)}")
    json.dump(out, open(os.path.join(HERE, "rope_reference.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
