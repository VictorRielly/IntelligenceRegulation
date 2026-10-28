#!/usr/bin/env python3
"""Lane B3 driver: the native-compatibility fidelity ladder and the
`zk60-trained-profile-export/1` exports for TinyLlama-1.1B-Chat (fe8a4ea1).

Flow (one variant per process):
  pass 1   float32 statistics of every block over the CALIBRATION sequences
           (cached per T / calibration size / rotation in runs/b3_stats_*.pkl);
  pre-pass per-layer solves without a residual scale: the per-layer optimum
           norm constants, the exp e_s and SiLU member each layer needs, and
           the residual-scale floors (int16 range; SH_AO; SH_Z);
  profile  the shared decisions of the variant (one Cn per norm type, one
           e_s, one SiLU member, one s_x or a per-layer rescale schedule);
  pass 2   per layer: final solve, the EXACT integer block (tlcalib.i_block)
           on the calibration set (chained), the HELD-OUT set chained (the
           integer stack end to end) and isolated, against the float block;
  head     float final norm + LM head (outside the proved stack, D13) on the
           float and on the integer final residual: top-1 agreement, ppl, KL,
           over ALL held-out sequences (refusals clamped: diagnostic only) and
           over the sequences the native kernel ACCEPTS at every layer.

A refusal is never clamped silently: every out-of-class value is counted and
attributed to its sequence; such a sequence is not a native output.
Calibration data, not a proof, not a privacy claim.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pickle
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
import b3calib as b3  # noqa: E402
# Shieldstral data/CLI are provided by prepare_calibration.py and build_export.py.

try:
    from threadpoolctl import threadpool_limits
except ImportError:  # pragma: no cover
    threadpool_limits = None

HERE = tc.HERE
from shieldstral_geometry import MODEL

SCHEMA = "zk60-trained-profile-export/1"


def log(msg: str):
    print(f"[{time.strftime('%H:%M:%S', time.gmtime())}Z] {msg}", flush=True)


def sha_file(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def load_layer(ck, l, R):
    W = tc.layer_f32(ck, l)
    return b3.rotate_layer(W, R) if R is not None else W


def run_int(x, P, rope, rec, chunk):
    return np.concatenate([tc.i_block(x[s:s + chunk], P, rope, rec, seq0=s) for s in range(0, x.shape[0], chunk)])


def summ(c):
    return {"mean": float(c.mean()), "min": float(c.min()), "p01": float(np.quantile(c, 0.01))}


def head_metrics(xf, xi, ids, norm_w, lm_head, mask=None, chunk=4):
    if mask is not None:
        xf, xi, ids = xf[mask], xi[mask], ids[mask]
    if len(ids) == 0:
        return None
    agree, n, nll_f, nll_i, kl = 0, 0, 0.0, 0.0, 0.0
    for s in range(0, xf.shape[0], chunk):
        lf = tc.f_head(xf[s:s + chunk], norm_w, lm_head).astype(np.float64)[:, :-1]
        li = tc.f_head(xi[s:s + chunk], norm_w, lm_head).astype(np.float64)[:, :-1]
        tgt = ids[s:s + chunk, 1:]
        agree += int((lf.argmax(-1) == li.argmax(-1)).sum())
        n += tgt.size
        lsf = lf - lf.max(-1, keepdims=True)
        lsf -= np.log(np.exp(lsf).sum(-1, keepdims=True))
        lsi = li - li.max(-1, keepdims=True)
        lsi -= np.log(np.exp(lsi).sum(-1, keepdims=True))
        nll_f -= float(np.take_along_axis(lsf, tgt[..., None], -1).sum())
        nll_i -= float(np.take_along_axis(lsi, tgt[..., None], -1).sum())
        kl += float((np.exp(lsf) * (lsf - lsi)).sum())
    return {"sequences": int(len(ids)), "positions": n, "top1_agreement": agree / n, "ppl_float": float(np.exp(nll_f / n)),
            "ppl_int": float(np.exp(nll_i / n)), "kl_float_to_int_mean": kl / n}


# ------------------------------------------------------------------ pass 1

def float_stats(ck, xc, rope_f, L, R, cache_path: Path, chunk: int = 27):
    if cache_path.exists():
        with cache_path.open("rb") as f:
            obj = pickle.load(f)
        if len(obj) >= L:
            log(f"pass 1: stats from cache {cache_path.name}")
            return obj[:L]
    stats, x = [], xc
    keep = np.ones(xc.shape[0], dtype=bool)
    for l in range(L):
        W = load_layer(ck, l, R)
        st = {}
        if l == 0:
            ref = tc.f_block(x[:2], W, *rope_f)
            got = b3.f_block_stats(x[:2], W, *rope_f, None)
            assert np.array_equal(ref, got), "f_block_stats differs from tlcalib.f_block"
        outs, excl, gmax = [], 0, 0.0
        for s0 in range(0, x.shape[0], chunk):
            outs.append(b3.f_block_stats(x[s0:s0 + chunk], W, *rope_f, st, keep=keep[s0:s0 + chunk]))
            excl += st["excluded_here"]
            gmax = max(gmax, st["gate_absmax_all_sequences"])
        x = np.concatenate(outs)
        st["excluded_here"], st["excluded_total"], st["gate_absmax_all_sequences"] = excl, int((~keep).sum()), gmax
        if st["excluded_here"]:
            log(f"pass 1 L{l:02d}: {st['excluded_here']} calibration sequence(s) with |gate| > 63.5 (no frozen SiLU member "
                f"can carry it; max {st['gate_absmax_all_sequences']:.1f}) excluded from this layer's statistics on")
        stats.append(b3.finalize_stats(st))
    if L == ck.config["layers"]:
        # atomic: concurrent runs may compute the same cache
        tmp = cache_path.with_suffix(f".tmp{os.getpid()}")
        with tmp.open("wb") as f:
            pickle.dump(stats, f)
        os.replace(tmp, cache_path)
    return stats


# ------------------------------------------------------------------ profile decisions

def residual_schedule(need_in, need_out, mode):
    """s_in[l] >= need_in[l], s_out[l] = s_in[l+1] >= need_out[l]. global: one
    scale. layer: powers of two above s_in[0] = need_in[0], non-decreasing
    (only x2 = requant(x1 + (z << k), k), k >= 0, is expressible)."""
    L = len(need_in)
    if mode == "global":
        s = max(max(need_in), max(need_out))
        return [s] * L, [s] * L
    base = need_in[0]
    E = [0] * (L + 1)
    for l in range(L + 1):
        want = 0
        if l < L:
            want = max(want, int(np.ceil(np.log2(need_in[l] / base) - 1e-9)))
        if l > 0:
            want = max(want, int(np.ceil(np.log2(need_out[l - 1] / base) - 1e-9)), E[l - 1])
        E[l] = max(want, 0)
    s = [base * 2.0 ** e for e in E]
    return s[:L], s[1:]


def range_needs(stats, var):
    need_in = [max(st["x_amax"], st["x1_amax"], st["ao_amax"]) * var.m / 32767.0 for st in stats]
    need_out = [max(st["x2_amax"], st["z_amax"]) * var.m / 32767.0 for st in stats]
    return need_in, need_out


def prepass(ck, stats, var, R, L, floors: str):
    """Returns (Globals, per-layer caches, prepass table)."""
    import dataclasses
    caches = [{} for _ in range(L)]
    table = []
    rin, rout = range_needs(stats, var)
    p_in, p_out = residual_schedule(rin, rout, var.residual)      # provisional: int16 ranges only
    glob = b3.Globals(s_in=p_in, s_out=p_out)
    t0 = time.time()
    # stage 1: per-layer optimum norm constants, tables and (free) shifts at the provisional scales
    for l in range(L):
        W = load_layer(ck, l, R)
        _, rep = b3.solve_layer(W, stats[l], var, p_in[l], p_out[l], glob, caches[l])
        table.append({"layer": l, "stage1": {"cn_a": rep["norm_consts"]["cn_a"], "cn_m": rep["norm_consts"]["cn_m"],
                                             "e_s": rep["score"]["e_s"], "silu": rep["ffn"]["silu_member"],
                                             "norm_a": rep["norm_a"], "norm_m": rep["norm_m"], "shifts": rep["shifts"],
                                             "ao_floor": rep["v_o"]["ao_floor"], "z_floor": rep["u_h_d"]["z_floor"]}})
        log(f"prepass-1 L{l:02d} cn {rep['norm_consts']['cn_a']}/{rep['norm_consts']['cn_m']} shape "
            f"{rep['norm_a']['shape']}/{rep['norm_m']['shape']} noise {rep['norm_a']['noise']:.3f}/{rep['norm_m']['noise']:.3f} "
            f"e_s {rep['score']['e_s']} silu {rep['ffn']['silu_member']} shifts {rep['shifts']} ({time.time() - t0:.0f}s)")
    if var.shifts == "profile":
        sites = ("qkv", "s", "ao", "g", "h", "z")
        glob.shifts = dict(b3.NATIVE_SHIFTS)
        glob.shifts["o"] = 1 if var.o16 else var.f_p
        for k in sites:
            vals = [t["stage1"]["shifts"][k] for t in table]
            # SH_AO / SH_Z: the largest value every layer can take without an
            # empty scale interval (the minimum); the others: the median
            glob.shifts[k] = int(min(vals)) if k in ("ao", "z") else int(np.floor(np.median(vals)))
        log(f"profile shift set (min over layers for ao/z, median otherwise): {glob.shifts}")
    if var.norm_cn == "profile":
        # one K per norm type: the SMALLEST per-layer optimum (no layer's
        # gains hit the 127 cap harder than at its own optimum), within the
        # unit-gain overflow bound of every layer and Cn <= cn_max
        hi = lambda key: min(int(np.floor((2 ** var.tn) * np.sqrt(tc.GEO.d) * 127.0 / float(b3.rb(st[key], var.m, var.margin_ch).max())))
                             for st in stats)
        cn_a = min(max(t["stage1"]["cn_a"] for t in table), hi("xa_max"), var.cn_max)
        cn_m = min(max(t["stage1"]["cn_m"] for t in table), hi("xm_max"), var.cn_max)
        glob.cn_a, glob.cn_m = cn_a, cn_m
        glob.K_a, glob.K_m = b3.norm_K(cn_a, var.tn), b3.norm_K(cn_m, var.tn)
    if var.tables == "profile":
        m2 = var.m2
        gmax = max(max(st["gate_pos"], st["gate_neg"]) for st in stats)
        amax = max(st["act_max"] for st in stats)
        glob.silu = b3.silu_choice(b3.gate_e_in(gmax, m2), amax, m2)
        # one exp table: the e_s minimising the summed attention objective
        e_lo = max(int(np.ceil(np.log2(float(st["raw_kv"].max()) * m2 / 127.0) - 1e-9)) for st in stats)
        cands = list(range(e_lo, e_lo + 3))
        tot = {e: 0.0 for e in cands}
        for l in range(L):
            W = load_layer(ck, l, R)
            for e in cands:
                res = b3.norm_a_search(W, stats[l], var, dataclasses.replace(glob, e_s=e), p_in[l], caches[l])
                tot[e] += res[4]["noise"] if res is not None else np.inf
            log(f"e_s selection L{l:02d}: running totals {({e: round(v, 4) for e, v in tot.items()})}")
        glob.e_s = min(cands, key=lambda e: tot[e])
        if not np.isfinite(tot[glob.e_s]):
            raise RuntimeError("no single e_s is feasible for every layer")
    # stage 2: with the profile decisions: floors at the provisional scales
    need_in, need_out = [], []
    for l in range(L):
        W = load_layer(ck, l, R)
        _, rep = b3.solve_layer(W, stats[l], var, p_in[l], p_out[l], glob, caches[l])
        free_floor = var.shifts == "free"
        aof = rep["v_o"]["ao_floor_min_shift"] if free_floor else rep["v_o"]["ao_floor"]
        zf = rep["u_h_d"]["z_floor_min_shift"] if free_floor else rep["u_h_d"]["z_floor"]
        need_in.append(max(rin[l], aof) if floors == "strict" else rin[l])
        need_out.append(max(rout[l], zf) if floors == "strict" else rout[l])
        table[l]["stage2"] = {"e_s": rep["score"]["e_s"], "range_in": rin[l], "range_out": rout[l], "ao_floor": aof, "z_floor": zf,
                              "cn_a": rep["norm_consts"]["cn_a"], "cn_m": rep["norm_consts"]["cn_m"], "shifts": rep["shifts"],
                              "norm_a": rep["norm_a"], "norm_m": rep["norm_m"]}
        log(f"prepass-2 L{l:02d} e_s {rep['score']['e_s']} range in/out {rin[l]:.3g}/{rout[l]:.3g} floors ao {aof:.3g} z {zf:.3g} "
            f"({time.time() - t0:.0f}s)")
    glob.s_in, glob.s_out = residual_schedule(need_in, need_out, var.residual)
    return glob, caches, table


# ------------------------------------------------------------------ export

def write_bin(dirp: Path, name: str, arr: np.ndarray, dtype: str) -> dict:
    a = np.ascontiguousarray(arr).astype(dtype)
    p = dirp / f"{name}.bin"
    p.write_bytes(a.tobytes())
    return {"file": p.name, "dtype": {"<i1": "int8", "<i2": "int16", "<i8": "int64"}[dtype], "shape": list(a.shape),
            "sha256": sha_file(p)}


def layer_constants(P, var) -> dict:
    return {"norm_tn": P.tn, "norm_cn_a": P.cn_a, "norm_cn_m": P.cn_m, "norm_ceps": P.ceps,
            "sh_qkv": P.sh_qkv, "sh_rope": P.sh_rope, "sh_s": P.sh_s, "sh_o": P.sh_o, "sh_ao": P.sh_ao,
            "sh_g": P.sh_g, "sh_u": P.sh_u, "sh_h": P.sh_h, "sh_z": P.sh_z, "f_e": P.f_e, "f_p": P.f_p, "f_ro": P.f_ro,
            "sh_r2": P.sh_r2, "silu_member": list(P.silu), "exp_e_s": P.e_s, "rope_theta": tc.GEO.theta}


def export_layer(root: Path, l: int, P, rep, T: int, var) -> dict:
    d = root / f"layer_{l:02d}"
    d.mkdir(parents=True, exist_ok=True)
    c, s = b3.rope_generate(T, tc.GEO.dh, tc.GEO.theta, P.f_ro)
    arrays = {
        "wq": write_bin(d, "wq", P.wq, "<i1"), "wk": write_bin(d, "wk", P.wk, "<i1"),
        "wv": write_bin(d, "wv", P.wv, "<i1"), "wo": write_bin(d, "wo", P.wo, "<i1"),
        "gamma_a": write_bin(d, "gamma_a", P.gamma_a, "<i1"), "gamma_m": write_bin(d, "gamma_m", P.gamma_m, "<i1"),
        "wg_t": write_bin(d, "wg_t", P.wg_t, "<i1"), "wu_t": write_bin(d, "wu_t", P.wu_t, "<i1"),
        "wd_t": write_bin(d, "wd_t", P.wd_t, "<i1"),
        "exp": write_bin(d, "exp", P.exp, "<i8"), "act": write_bin(d, "act", P.act, "<i2"),
        "rope_cos": write_bin(d, "rope_cos", c, "<i8"), "rope_sin": write_bin(d, "rope_sin", s, "<i8"),
    }
    man = {"schema": SCHEMA, "kind": "layer", "variant": var.name, "layer": l, "constants": layer_constants(P, var),
           "tables": {"exp": {"generator": f"hashline tables_attn.rs exp_member(e_s, head_dim {tc.GEO.dh}, f_e)", "e_s": P.e_s,
                              "spec_digest": P.exp_digest},
                      "act": {"generator": "zkp-core tables.rs int16out_member(Silu, e_in, e_out) (frozen registry)",
                              "silu_member": list(P.silu), "spec_digest": P.act_digest},
                      "rope": {"generator": f"hashline tables_attn.rs rope_tables_generate(T, {tc.GEO.dh}, {tc.GEO.theta}, {P.f_ro})", "t_max": T,
                               "spec_digest": b3.rope_digest(T, tc.GEO.dh, tc.GEO.theta, P.f_ro, c, s)}},
           "orientation": {"wq/wk/wv/wo": "(output, input) row-major", "wg_t/wu_t": "(input d, output f) row-major",
                           "wd_t": "(input f, output d) row-major", "padding": "none (true extents)"},
           "arrays": arrays,
           "metadata_out_of_proof": {"scales": rep["metadata_scales"], "norm_consts": rep["norm_consts"],
                                     "weights_clipped": rep.get("weights_clipped", {})}}
    (d / "manifest.json").write_text(json.dumps(man, indent=1, sort_keys=True))
    return man


def write_token_io(root: Path, ck, R, s_in0: float, s_out_last: float, args, ho_ids, chain_h, seq_idx):
    """B4-4: the layer-0 integer input as a PUBLIC lookup table (one int16 row
    per vocabulary token): x_in_L00[t] = table[token_t]. Exactly the path the
    calibration used: float32 embedding row -> (rotated: float64 FWHT, cast to
    float32) -> round_half_up(float64(x) / s_x). Checked against the exported
    sequences' x_in_L00 before writing."""
    E = tc.tensor_f32(ck.refs["model.embed_tokens.weight"])
    rows = []
    for s0 in range(0, E.shape[0], 4000):
        x = E[s0:s0 + 4000]
        if R is not None:
            x = R.fwd(x).astype(np.float32)
        q = np.floor(x.astype(np.float64) / s_in0 + 0.5)
        if np.abs(q).max() > 32767:
            raise ValueError("an embedding row leaves int16 at this s_x (that token would refuse)")
        rows.append(q.astype(np.int16))
    table = np.concatenate(rows)
    for i in seq_idx:
        if not np.array_equal(table[ho_ids[i]], chain_h[0][i]):
            raise AssertionError(f"embedding table does not reproduce x_in_L00 of held-out {i}")
    spec = write_bin(root, "embedding_int16", table, "<i2")
    ident = ck.identity["tensor_sha256"]
    tio = {"schema": SCHEMA, "kind": "token_io", "embedding_table": spec,
           "s_x_in_layer0": s_in0, "s_x_out_layer21": s_out_last,
           "rotation": None if R is None else {"seed": args.rotate, "file": "rotation_sign.bin (see rotation.json)"},
           "source_tensors_sha256": {k: ident[k] for k in ("model.embed_tokens.weight", "model.norm.weight", "lm_head.weight")},
           "rms_norm_eps": tc.GEO.eps,
           "spec": "see export/TOKEN_IO_SPEC.md", "checked_against_sequences": [f"seq_ho{i:02d}" for i in seq_idx]}
    (root / "token_io.json").write_text(json.dumps(tio, indent=1, sort_keys=True))
    if R is not None:
        raw = R.sign.astype("<f8").tobytes()
        (root / "rotation_sign.bin").write_bytes(raw)
        (root / "rotation.json").write_text(json.dumps({"kind": "randomized Sylvester Hadamard", "n": 2048, "seed": args.rotate,
                                                        "file": {"name": "rotation_sign.bin", "dtype": "float64 little-endian",
                                                                 "shape": [2048], "sha256": hashlib.sha256(raw).hexdigest()},
                                                        "definition": "R = H diag(sign) / sqrt(2048); x' = x R^T; see export/TOKEN_IO_SPEC.md"},
                                                       indent=1))
    log(f"token io written: embedding_int16.bin sha256 {spec['sha256']}")


# ------------------------------------------------------------------ main

if __name__ == "__main__":
    raise SystemExit("Use Shieldstral build_export.py, not the upstream CLI")
