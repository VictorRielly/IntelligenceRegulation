#!/usr/bin/env python3
"""Build a calibration VARIANT of the TinyLlama integer model as a pseudo-export
(same layer layout and manifests as `zk60-trained-profile-export/1`, written by
the calibration lane's own `b3_ladder.export_layer`), so `fp_eval.py` can
evaluate it unchanged. The calibration lane's tools are imported read-only;
pass 1 statistics come from its cache (b3_stats4_T128_c6_r1_b4fw54.pkl, the
pg_rot1_b4 calibration: 54 licence/docstring + 54 FineWeb row-group-0
sequences at T 128).

  python3 fp_variant.py --variant pg [--qkv-window 16] [--margin 0.5] --name NAME

`--variant pg` reproduces export/pg_rot1_b4_T128 word for word (checked).
Variant tokens are b3calib's (dg = per-layer free shifts / Cn / tables;
+feN = exp-table f_e N; +fpN = probability bits F_P N; +o16 = o int16).
Not a proof, not a privacy claim; refusals are measured by fp_eval.
"""

from __future__ import annotations

import argparse
import os
import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fp_lib as fl  # noqa: E402
from fp_lib import tc, b3  # noqa: E402

sys.path.insert(0, str(fl.CAL))
import b3_ladder as bl  # noqa: E402

REF_EXPORT = (fl.C8 / "export" / "llama3_8b_pg_rot1_b7_T128") if fl.IS8B else (fl.CAL / "export" / "pg_rot1_b4_T128")


def glob_from_prepass(path: Path, tn: int):
    """b5_8b.glob_from_prepass (copied): reuse a run's profile decisions."""
    pr = json.loads(path.read_text())["profile"]
    return b3.Globals(s_in=pr["s_in"], s_out=pr["s_out"], cn_a=pr["cn_a"], cn_m=pr["cn_m"],
                      K_a=b3.norm_K(pr["cn_a"], tn) if pr["cn_a"] else None, K_m=b3.norm_K(pr["cn_m"], tn) if pr["cn_m"] else None,
                      e_s=pr["e_s"], silu=tuple(pr["silu"]) if pr["silu"] else None, shifts=pr["shifts"])


def merge_vocab0(ck, R, stats):
    """Vocabulary-wide FLOAT layer-0 maxima (rotated basis, gammas folded, float32 like the pipeline):
    per-channel |xhat|, per-(head, RoPE pair) |q|, |k| norms and per-channel |v|, merged (max) into
    stats[0]. Layer 0's norm and Q/K/V depend on the token alone, so this covers every input."""
    g = tc.GEO
    W = bl.load_layer(ck, 0, R)
    ref = ck.refs["model.embed_tokens.weight"]
    V = ref.shape[0]
    Wq, Wk, Wv = (W[f"self_attn.{n}_proj.weight"].astype(np.float32) for n in "qkv")
    xa = np.zeros(g.d); qp = np.zeros((g.H, g.half)); kp = np.zeros((g.KV, g.half)); vm = np.zeros(g.KV * g.dh)
    for a0 in range(0, V, 4096):
        x = R.fwd(fl.emb_rows(np.arange(a0, min(V, a0 + 4096)))).astype(np.float32)
        xh = tc.f_xhat(x, g.eps)
        xa = np.maximum(xa, np.abs(xh).max(0))
        q = (xh @ Wq.T).reshape(-1, g.H, g.dh)
        k = (xh @ Wk.T).reshape(-1, g.KV, g.dh)
        v = xh @ Wv.T
        qp = np.maximum(qp, np.sqrt(q[..., :g.half].astype(np.float64) ** 2 + q[..., g.half:].astype(np.float64) ** 2).max(0))
        kp = np.maximum(kp, np.sqrt(k[..., :g.half].astype(np.float64) ** 2 + k[..., g.half:].astype(np.float64) ** 2).max(0))
        vm = np.maximum(vm, np.abs(v).max(0))
    st = stats[0]
    rep = {"xa_max": [float(st["xa_max"].max()), float(xa.max())], "q_pair": [float(st["q_pair"].max()), float(qp.max())],
           "k_pair": [float(st["k_pair"].max()), float(kp.max())], "v_max": [float(st["v_max"].max()), float(vm.max())]}
    st["xa_max"] = np.maximum(st["xa_max"], xa)
    st["q_pair"] = np.maximum(st["q_pair"], qp)
    st["k_pair"] = np.maximum(st["k_pair"], kp)
    st["v_max"] = np.maximum(st["v_max"], vm)
    return rep


def install_wide_searches():
    """Copies of b3calib.norm_a_search / norm_m_search whose free-shift candidate
    lists cover the widened windows (b3calib tries SH_QKV in (7, 8, 6) and SH_G in
    (7, 8, 6, 5) only). Installed into b3calib's namespace, so solve_layer uses them."""
    import numpy as _np

    def cands(site, base):
        lo, hi = tc.SHIFT_WINDOW[site]
        extra = [v for v in range(9, hi + 1)]
        return tuple(base) + tuple(extra)

    def norm_a_search(W, st, var, glob, s_x, cache):
        free, sh = b3._shift_mode(var, glob)
        key = ("a", glob.K_a, glob.e_s, round(s_x, 12), tuple(sorted(sh.items())) if glob.shifts else free)
        if key in cache:
            return cache[key]
        ga = W["input_layernorm.weight"].astype(_np.float64)
        mats = [W["self_attn.q_proj.weight"], W["self_attn.k_proj.weight"], W["self_attn.v_proj.weight"]]
        best = None
        for i, s_qkv in enumerate(cands("qkv", (7, 8, 6)) if free else (sh["qkv"],)):
            obj = b3.AttnObjective(W, st, ga, var, s_qkv, sh["s"], sh["ao"], glob.e_s, free, s_x, sh_o=sh["o"],
                                   ao_win=(1, 16) if var.o16 else None)
            try:
                g8, cn, K, info = b3.choose_norm(ga, st["xa_max"], st["xa_ms"], mats, obj, var, glob.K_a,
                                                 shapes=None if i == 0 else (best[4]["shape"],))
            except ValueError:
                continue
            if best is None or info["noise"] < best[4]["noise"]:
                best = (s_qkv, g8, cn, K, info)
        cache[key] = best
        return best

    def norm_m_search(W, st, var, glob, member, s_x_out, cache):
        free, sh = b3._shift_mode(var, glob)
        sh_h = b3.layer_sh_h(st, var, glob, member)
        key = ("m", glob.K_m, member, sh_h, round(s_x_out, 12), tuple(sorted(sh.items())) if glob.shifts else free)
        if key in cache:
            return cache[key]
        gm = W["post_attention_layernorm.weight"].astype(_np.float64)
        mats = [W["mlp.gate_proj.weight"], W["mlp.up_proj.weight"]]
        best = None
        for i, s_g in enumerate(cands("g", (7, 8, 6, 5)) if free else (sh["g"],)):
            obj = b3.FfnObjective(W, st, gm, var, s_g, member, sh_h, sh["z"], free, s_x_out)
            g8, cn, K, info = b3.choose_norm(gm, st["xm_max"], st["xm_ms"], mats, obj, var, glob.K_m,
                                             shapes=None if i == 0 else (best[5]["shape"],))
            if best is None or info["noise"] < best[5]["noise"]:
                best = (s_g, sh_h, g8, cn, K, info)
        cache[key] = best
        return best

    b3.norm_a_search = norm_a_search
    b3.norm_m_search = norm_m_search


def main():
    if (fl.HERE / "logs" / "HOLD").exists() and os.environ.get("FP_ALLOW") != "1":
        fl.log("DEFERRED: lane hold (logs/HOLD); re-run through logs/stream.sh")
        raise SystemExit(3)
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", default="pg")
    ap.add_argument("--rotate", type=int, default=1)
    ap.add_argument("--T", type=int, default=128)
    ap.add_argument("--margin", type=float, default=0.5)
    ap.add_argument("--qkv-window", type=int, default=8, help="upper end of the SH_QKV window (8 native; 16 = two-byte remainder)")
    ap.add_argument("--name", required=True)
    ap.add_argument("--profile-from", default="", help="prepass.json whose profile decisions to reuse (8B b7: runs/llama3_8b_pg_rot1_T128)")
    ap.add_argument("--sh-s-layer", default="", help="per-layer SH_S overrides 'layer:shift,...' (8B b7: 1:7)")
    ap.add_argument("--window", default="", help="widen requant shift windows 'site:hi,...' (two-byte remainders: qkv:16,g:16,z:16)")
    ap.add_argument("--vocab0", action="store_true", help="merge vocabulary-wide float layer-0 maxima (norm, Q/K pairs, V) into the layer-0 statistics")
    ap.add_argument("--only-layers", default="", help="solve only these layers ('0,1'); hard-link every other layer (and token_io) from the reference export")
    a = ap.parse_args()
    if (fl.HERE / "logs" / f"HOLD2_build_{a.name}").exists():
        fl.log(f"DEFERRED: per-build hold logs/HOLD2_build_{a.name}")
        raise SystemExit(3)
    t0 = time.time()
    if a.qkv_window != 8:
        tc.SHIFT_WINDOW["qkv"] = (1, a.qkv_window)
    for tok in [t for t in a.window.split(",") if t]:
        site, hi = tok.split(":")
        tc.SHIFT_WINDOW[site] = (tc.SHIFT_WINDOW[site][0], int(hi))
    if a.window or a.qkv_window != 8:
        install_wide_searches()
    var = b3.variant_by_name(a.variant, rotate=a.rotate, margin=a.margin)
    if fl.IS8B:
        kw = dict(var.__dict__)
        kw.update(tn=9, cn_max=1 << 20)       # D24: tn <= 9 at width 4096, Cn <= 2^20 (as b5_8b.py)
        var = b3.Variant(**kw)
    shs = {int(k): int(v) for k, v in (t.split(":") for t in a.sh_s_layer.split(",") if t)}
    out = fl.HERE / "variants" / a.name
    if out.exists() and any(out.iterdir()):
        raise SystemExit(f"{out} exists and is not empty")
    out.mkdir(parents=True, exist_ok=True)
    ck = fl.checkpoint()
    R = b3.Rotation(tc.GEO.d, a.rotate)
    L = ck.config["layers"]
    cache = (fl.C8 / "runs" / f"b5_stats_T{a.T}_n30_r{a.rotate}_L{L}.pkl") if fl.IS8B else \
        (fl.CAL / "runs" / f"b3_stats4_T{a.T}_c6_r{a.rotate}_b4fw54.pkl")
    assert cache.exists(), cache
    stats = bl.float_stats(ck, None, None, L, R, cache)
    fl.log(f"variant {a.name}: {var}; qkv window {tc.SHIFT_WINDOW['qkv']}; stats {cache.name}; sh_s overrides {shs}")
    vocab_rep = None
    if a.vocab0:
        vocab_rep = merge_vocab0(ck, R, stats)
        fl.log(f"vocab0: layer-0 maxima merged {vocab_rep}")
    only = {int(t) for t in a.only_layers.split(",") if t}
    floors = "none" if var.residual == "global" else "strict"
    if a.profile_from:
        glob, caches = glob_from_prepass(Path(a.profile_from), var.tn), [{} for _ in range(L)]
    else:
        glob, caches, ptable = bl.prepass(ck, stats, var, R, L, floors)
    fl.log(f"profile: cn {glob.cn_a}/{glob.cn_m} e_s {glob.e_s} silu {glob.silu} shifts {glob.shifts} s_x {glob.s_in[0]:.6g} "
           f"({time.time() - t0:.0f}s)")
    layers, same = [], []
    for l in range(L):
        if only and l not in only:
            src_dir, dst = REF_EXPORT / f"layer_{l:02d}", out / f"layer_{l:02d}"
            dst.mkdir(parents=True, exist_ok=True)
            for f in sorted(src_dir.iterdir()):
                os.link(f, dst / f.name)
            man = json.loads((dst / "manifest.json").read_text())
            layers.append({"layer": l, "dir": dst.name, "manifest_sha256": fl.sha_file(dst / "manifest.json"),
                           "constants": {**{k: v for k, v in man["constants"].items()}}, "clipped": {}, "linked_from_reference": True})
            same.append(13)
            continue
        W = bl.load_layer(ck, l, R)
        glob_l = glob
        if l in shs:
            glob_l = b3.Globals(**{**glob.__dict__, "shifts": dict(glob.shifts, s=shs[l])})
        P, rep = b3.solve_layer(W, stats[l], var, glob.s_in[l], glob.s_out[l], glob_l, caches[l])
        del W
        bl.export_layer(out, l, P, rep, a.T, var)
        layers.append({"layer": l, "dir": f"layer_{l:02d}", "manifest_sha256": fl.sha_file(out / f"layer_{l:02d}" / "manifest.json"),
                       "constants": bl.layer_constants(P, var), "clipped": {k: v for k, v in rep.get("weights_clipped", {}).items() if v}})
        ref = REF_EXPORT / f"layer_{l:02d}" / "manifest.json"
        if ref.exists():
            rm = json.loads(ref.read_text())["arrays"]
            mm = json.loads((out / f"layer_{l:02d}" / "manifest.json").read_text())["arrays"]
            same.append(sum(rm[k]["sha256"] == mm[k]["sha256"] for k in rm))
        fl.log(f"L{l:02d} {bl.layer_constants(P, var)} clip {layers[-1]['clipped']} words equal to {REF_EXPORT.name}: "
               f"{same[-1] if same else '-'} / 13 ({time.time() - t0:.0f}s)")
    raw = R.sign.astype("<f8").tobytes()
    (out / "rotation_sign.bin").write_bytes(raw)
    if only and (REF_EXPORT / "token_io").is_dir():
        rp = json.loads((REF_EXPORT / "profile.json").read_text())["metadata_out_of_proof"]
        assert rp["residual_scales_out"][-1] == glob.s_out[-1], "token_io can be shared only at the same s_out"
        (out / "token_io").mkdir()
        for f in sorted((REF_EXPORT / "token_io").iterdir()):
            os.link(f, out / "token_io" / f.name)
    pc = layers[0]["constants"]
    uniform = {k: pc[k] if all(e["constants"][k] == pc[k] for e in layers) else None for k in pc}
    prof = {"schema": "zk60-trained-profile-export/1 (pseudo-export of the fidelity lane; NOT an export of record)",
            "kind": "profile", "variant": a.name, "variant_options": var.__dict__, "T": a.T,
            "shift_windows": {k: list(v) for k, v in tc.SHIFT_WINDOW.items()}, "profile_constants": uniform,
            "per_layer_constants_differ": sorted(k for k, v in uniform.items() if v is None),
            "layers": [{k: e[k] for k in ("layer", "dir", "manifest_sha256")} for e in layers], "sequences": [],
            "metadata_out_of_proof": {"residual_scales_in": glob.s_in, "residual_scales_out": glob.s_out,
                                      "rotation": {"seed": a.rotate, "sign_sha256": hashlib.sha256(raw).hexdigest()},
                                      "profile_decisions": {"cn_a": glob.cn_a, "cn_m": glob.cn_m, "e_s": glob.e_s,
                                                            "silu": glob.silu, "shifts": glob.shifts}},
            "reference_export": str(REF_EXPORT), "words_equal_to_reference_per_layer": same,
            "profile_from": a.profile_from or None, "sh_s_overrides": shs, "vocab0": vocab_rep,
            "only_layers": sorted(only) or None,
            "tool_sha256": {p: fl.sha_file(fl.HERE / p) for p in ("fp_variant.py", "fp_lib.py")},
            "scope": "fidelity data, not a proof, not a privacy claim"}
    (out / "profile.json").write_text(json.dumps(prof, indent=1, sort_keys=True, default=str))
    fl.log(f"done ({time.time() - t0:.0f}s) -> {out}")


if __name__ == "__main__":
    try:
        from threadpoolctl import threadpool_limits
        import os
        with threadpool_limits(limits=int(os.environ.get("OPENBLAS_NUM_THREADS", "4"))):
            main()
    except ImportError:
        main()
