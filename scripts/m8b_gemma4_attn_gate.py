"""m8b_gemma4_attn_gate — U-PERF3 round 3 lane CC: the ATTENTION-site
qualification gate for Gemma-4-12B (the MVP-2 de-risk measurement).

Question: does attention carry the same outlier/resolution disease the
FFN did (+17.60 nats at per-tensor int8, fixed only by the widened
a16+uhz16 stack)?  MVP-2's cost and spec depend on which attention
sites are int8-clean vs needing the widened class.  The FFN answer took
days of blind variant passes until the per-site ATTRIBUTION found it in
one sweep — here the attribution runs FIRST.

Method (the m8b_gemma4_attrib.py pattern transplanted to attention):
  --phase stats   one fp walk over the 8 calibration windows collecting
                  per-layer per-site range profiles (absmax/p999/p9999,
                  per-head where head-structured) for the sites of
                  ATTENTION_INTEGER_SPEC.md / the lane-X design's
                  AM-3 axis table -> results/m8b_gemma4_attn_stats.json
  --phase attrib  the fp forward (FFN stays fp!) with quantize-dequant
                  at exactly ONE attention site at a time, int8 at the
                  stats pass's absmax-derived per-tensor power-of-two
                  exponents; first-order loss delta per site on the val
                  subset (--take 2) -> results/m8b_gemma4_attn_attrib.json
  --phase widen   int16 rerun (same absmax coverage, exponent e-8 =
                  256x finer step) at the named material sites, plus a
                  per-head-exponent variant and the composed stack row
                  -> results/m8b_gemma4_attn_widen.json
  --phase equiv   bit-exactness of this walker vs the validated
                  m8b_gemma4_walker with all hooks off (SMOKE, 2 layers)

Sites (names used everywhere below; spec/AM references in brackets):
  Wattn   wq/wk/wv/wo int8 per-tensor (weight anchor; q/k norm gammas
          and layer norms stay fp — recorded caveat)
  xattn   input_layernorm output = the attention seam input   [xn8, 2.1]
  q, k    post-QK-norm, PRE-rope (Gemma's q_norm/k_norm)      [q8/k8 + AM-5]
  v       post scale-less v_norm                              [v8]
  scores  raw masked QK^T logits (Gemma-4 has NO attention softcap —
          walker facts F4; scaling 1.0, the norm scalars carry it)
          quantized on the causal support only                [s8, 2.4]
  exps    softmax numerator exp(s - max) in [0,1] at fixed-point fE=9,
          round-half-up (the exp table's OUTPUT resolution)   [E, 2.5]
  probs   softmax output in [0,1] at fixed-point fP=9, FLOOR (the
          spec's P = floor(E*2^fP/Sum) division-relation form) [P, 2.5]
  ctx     probs @ V head outputs (pre-concat/o_proj)          [o8, 2.6]
  ao      o_proj output                                       [ao8, 2.6]
  postn   post_attention_layernorm output (the Gemma four-norm
          sandwich's extra requant edge)                      [AM-5]
  xres    the residual stream after the attention add         [xres1, 2.7]

Scales/windows: REUSED verbatim from results/m8b_gemma4_calibration.json
(same checkpoint, seed 1337, same FineWeb text, 8+8 x 512 windows) so
deltas are comparable with the FFN attribution and the C4 verdicts.
Deltas are FIRST-ORDER attribution (the real chain compounds); the
'all_int8' row composes every attention site (still fp FFN) as the
upper anchor.  Labels: [MEASURED WSL-BOX] on the val subset.
"""

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125     # noqa: E402  (primitives, never edited)
import m8b_int8_calibration as m8b       # noqa: E402  (imported, never edited)
import m8b_gemma4_walker as g4           # noqa: E402  (the validated forward)

BASELINE_JSON = ROOT / "results" / "m8b_gemma4_calibration.json"
STATS_JSON = ROOT / "results" / "m8b_gemma4_attn_stats.json"
ATTRIB_JSON = ROOT / "results" / "m8b_gemma4_attn_attrib.json"
WIDEN_JSON = ROOT / "results" / "m8b_gemma4_attn_widen.json"

FE = 9   # exp table output frac bits (spec 2.5)
FP = 9   # softmax P frac bits (spec 2.5)

TENSOR_E_SITES = ("xattn", "q", "k", "v", "scores", "ctx", "ao",
                  "postn", "xres")
ALL_SITES = ("Wattn", "xattn", "q", "k", "v", "scores", "exps",
             "probs", "ctx", "ao", "postn", "xres")


# --------------------------------------------------------------------------
# quantize-dequant primitives (attrib-script conventions)
# --------------------------------------------------------------------------

def deq8(x, e):
    """int8 quantize-dequant at 2^e (round + clip 127, m125.quantize)."""
    q = np.clip(np.round(x / (2.0 ** e)), -127, 127)
    return q * (2.0 ** e)


def deq16(x, e8):
    """int16 quantize-dequant with the SAME absmax coverage as the int8
    exponent e8 (e16 = e8 - 8): 256x finer step, identical range."""
    e = np.asarray(e8) - 8
    q = np.clip(np.floor(x / (2.0 ** e) + 0.5), -32767, 32767)
    return q * (2.0 ** e)


def fixp(x, f, mode):
    """Fixed-point on [0,1]-valued tensors: f frac bits."""
    s = 2.0 ** f
    q = np.floor(x * s + 0.5) if mode == "round" else np.floor(x * s)
    return q / s


# --------------------------------------------------------------------------
# range-profile helpers (stats phase)
# --------------------------------------------------------------------------

def _prof(x):
    a = np.abs(np.asarray(x)).ravel()
    if a.size == 0:
        return dict(absmax=0.0, p999=0.0, p9999=0.0, ratio=0.0)
    mx = float(a.max())
    p999 = float(np.quantile(a, 0.999))
    return dict(absmax=mx, p999=p999,
                p9999=float(np.quantile(a, 0.9999)),
                ratio=(mx / p999 if p999 > 0 else float("inf")))


def _site_stats(rec, name, x, d_axis=False):
    pr = _prof(x)
    pr["e8"] = m125.pow2_exp_for(pr["absmax"])
    if d_axis:
        cm = np.abs(x).reshape(-1, x.shape[-1]).max(axis=0)
        med = float(np.median(cm))
        pr["col_ratio"] = float(cm.max()) / med if med > 0 else float("inf")
    rec[name] = pr


def _head_stats(rec, name, x):
    """x (B,T,H,hd): per-tensor profile + per-head absmax/p999/e8."""
    pr = _prof(x)
    pr["e8"] = m125.pow2_exp_for(pr["absmax"])
    H = x.shape[2]
    hm, hp, he = [], [], []
    for h in range(H):
        a = np.abs(x[:, :, h, :]).ravel()
        m = float(a.max())
        hm.append(m)
        hp.append(float(np.quantile(a, 0.999)))
        he.append(m125.pow2_exp_for(m))
    pr["head_absmax"] = hm
    pr["head_p999"] = hp
    pr["e8_head"] = he
    rec[name] = pr


# --------------------------------------------------------------------------
# the hooked walker (subclass; the validated walker file is untouched)
# --------------------------------------------------------------------------

class AttnGateWalker(g4.Gemma4Walker):
    """g4.Gemma4Walker with (a) per-site range-stat recording, (b)
    quantize-dequant at declared attention sites.  With rec=None and
    sites empty the forward is op-identical to the parent (asserted by
    --phase equiv)."""

    def __init__(self, store, arch, t_max):
        super().__init__(store, arch, t_max)
        self.rec = None            # list of per-layer dicts (stats phase)
        self.sites = frozenset()   # active quantization sites
        self.wide = frozenset()    # subset of sites at int16 / f+8
        self.perhead = frozenset() # subset using per-head exponents
        self.exps = None           # {layer: {site: e8, site+"_head": [...]}}
        self._li = None

    # -- quantization application ------------------------------------
    def _e(self, name, headshape=None):
        ex = self.exps[self._li]
        if name in self.perhead and (name + "_head") in ex:
            v = np.asarray(ex[name + "_head"], dtype=np.float64)
            return v.reshape(headshape) if headshape else v
        return ex[name]

    def _apply(self, name, x, headshape=None):
        if name not in self.sites:
            return x
        if name == "probs":
            return fixp(x, FP + (8 if name in self.wide else 0), "floor")
        if name == "exps":
            return fixp(x, FE + (8 if name in self.wide else 0), "round")
        e = self._e(name, headshape)
        return deq16(x, e) if name in self.wide else deq8(x, e)

    def _apply_scores(self, s, h):
        if "scores" not in self.sites:
            return s
        ex = self.exps[self._li]
        e = (ex["scores_head"][h] if "scores" in self.perhead
             and "scores_head" in ex else ex["scores"])
        fin = np.isfinite(s)
        out = s.copy()
        v = s[fin]
        out[fin] = deq16(v, e) if "scores" in self.wide else deq8(v, e)
        return out

    # -- the attention block (parent copy + marked hook lines) --------
    def _attention(self, xn, lw, layer_type):
        a = self.arch
        B, T, _ = xn.shape
        if layer_type == "full_attention":
            hd, Hk = a.global_head_dim, a.global_kv_heads
            cos, sin = self.cos_g[:T], self.sin_g[:T]
        else:
            hd, Hk = a.head_dim, a.kv_heads
            cos, sin = self.cos_s[:T], self.sin_s[:T]
        H = a.heads
        rep = H // Hk
        rec = self.rec[self._li] if self.rec is not None else None
        # HOOK: attention seam input + weight anchor
        xn = self._apply("xattn", xn)
        if "Wattn" in self.sites:
            lw = dict(lw)
            for wname in ("wq", "wk", "wv", "wo"):
                if wname in lw:
                    W = lw[wname]
                    e = m125.pow2_exp_for(float(np.abs(W).max()))
                    lw[wname] = deq8(W.astype(np.float64),
                                     e).astype(np.float32)
        flat = xn.reshape(B * T, -1)
        q = (flat @ lw["wq"].T).reshape(B, T, H, hd)
        k = (flat @ lw["wk"].T).reshape(B, T, Hk, hd)
        if "wv" in lw:
            vr = (flat @ lw["wv"].T).reshape(B, T, Hk, hd)
        else:
            vr = k.copy()   # k_eq_v: RAW k_proj output (facts F4)
        q = m8b.rmsnorm(q, lw["q_norm"], a.eps)
        k = m8b.rmsnorm(k, lw["k_norm"], a.eps)
        v = g4.rmsnorm_noscale(vr, a.eps)
        del vr
        # HOOK: post-norm q/k/v sites
        q = self._apply("q", q, (1, 1, H, 1))
        k = self._apply("k", k, (1, 1, Hk, 1))
        v = self._apply("v", v, (1, 1, Hk, 1))
        if rec is not None:
            rec["layer"] = self._li
            rec["layer_type"] = layer_type
            _site_stats(rec, "xattn", xn, d_axis=True)
            _head_stats(rec, "q", q)
            _head_stats(rec, "k", k)
            _head_stats(rec, "v", v)
        mask = np.triu(np.full((T, T), -np.inf, dtype=np.float32), k=1)
        out = np.empty((B, T, H, hd), dtype=np.float32)
        tri = np.tril_indices(T) if rec is not None else None
        sc_h = [[] for _ in range(H)] if rec is not None else None
        pr_h = [[] for _ in range(H)] if rec is not None else None
        qr_mx = np.zeros(H) if rec is not None else None
        kr_mx = np.zeros(Hk) if rec is not None else None
        for b in range(B):
            qb = m8b.rope_apply(q[b], cos, sin)
            kb = m8b.rope_apply(k[b], cos, sin)
            if rec is not None:
                qr_mx = np.maximum(
                    qr_mx, np.abs(qb).max(axis=(0, 2)))
                kr_mx = np.maximum(
                    kr_mx, np.abs(kb).max(axis=(0, 2)))
            for h in range(H):
                # scaling = 1.0 — facts F4: NO hd**-0.5
                s = (qb[:, h] @ kb[:, h // rep].T) + mask
                if rec is not None:
                    sc_h[h].append(np.abs(s[tri]).astype(np.float32))
                s = self._apply_scores(s, h)          # HOOK: s8 site
                s = s - s.max(axis=-1, keepdims=True)
                e = np.exp(s)
                e = self._apply("exps", e)            # HOOK: E site
                w = e / e.sum(axis=-1, keepdims=True)
                w = self._apply("probs", w)           # HOOK: P site
                if rec is not None:
                    pr_h[h].append(w[tri].astype(np.float32))
                out[b, :, h] = w @ v[b, :, h // rep]
        # HOOK: context (PV output) site
        out = self._apply("ctx", out, (1, 1, H, 1))
        if rec is not None:
            _head_stats(rec, "ctx", out)
            rec["qr"] = dict(head_absmax=[float(x) for x in qr_mx],
                             absmax=float(qr_mx.max()),
                             e8=m125.pow2_exp_for(float(qr_mx.max())))
            rec["kr"] = dict(head_absmax=[float(x) for x in kr_mx],
                             absmax=float(kr_mx.max()),
                             e8=m125.pow2_exp_for(float(kr_mx.max())))
            sm, sp, se, sunion = [], [], [], []
            step = 2.0 ** (-FP)
            for h in range(H):
                sa = np.concatenate(sc_h[h])
                sm.append(float(sa.max()))
                sp.append(float(np.quantile(sa, 0.999)))
                se.append(m125.pow2_exp_for(float(sa.max())))
                sunion.append(sa)
            alls = np.concatenate(sunion)
            del sunion
            allp = np.concatenate([np.concatenate(pr_h[h])
                                   for h in range(H)])
            spr = _prof(alls)
            spr["e8"] = m125.pow2_exp_for(spr["absmax"])
            spr["head_absmax"] = sm
            spr["head_p999"] = sp
            spr["e8_head"] = se
            rec["scores"] = spr
            rec["probs"] = dict(
                pmax=float(allp.max()),
                p999=float(np.quantile(allp, 0.999)),
                frac_below_fp9_step=float(np.mean(allp < step)))
            del sc_h, pr_h, allp, alls
        ao = out.reshape(B * T, H * hd) @ lw["wo"].T
        ao = self._apply("ao", ao)                    # HOOK: o_proj out
        if rec is not None:
            _site_stats(rec, "ao", ao, d_axis=True)
        return ao

    # -- the walk (parent copy + postn/xres hook lines) ---------------
    def walk(self, tokens, ffn_override=None, collect=None):
        a = self.arch
        B, T = tokens.shape
        x = (self.embed.gather(tokens.reshape(-1)).reshape(B, T, a.d)
             * np.float32(g4.EMBED_SCALE))                 # facts F6
        for l in range(a.n_layers):
            self._li = l
            lt = a.layer_types[l]
            lw = self.load_layer(l)
            hn = m8b.rmsnorm(x, lw["attn_norm"], a.eps)
            att = self._attention(hn, lw, lt).reshape(B, T, a.d)
            pn = m8b.rmsnorm(att, lw["post_attn_norm"], a.eps)
            pn = self._apply("postn", pn)             # HOOK: postn site
            x = x + pn
            x = self._apply("xres", x)                # HOOK: xres site
            if self.rec is not None:
                _site_stats(self.rec[l], "postn", pn, d_axis=True)
                _site_stats(self.rec[l], "xres", x, d_axis=True)
            del hn, att, pn
            xin = m8b.rmsnorm(x, lw["pre_ffw_norm"], a.eps)
            if ffn_override is not None:
                z = ffn_override(l, xin, lw)
            else:
                flat = xin.reshape(B * T, a.d)
                gate = flat @ lw["w_gate"].T
                up = flat @ lw["w_up"].T
                act = g4.gelu_tanh(gate)                   # facts F3
                h = act * up
                z = (h @ lw["w_down"].T).reshape(B, T, a.d)
                if collect is not None:
                    collect(l, dict(x=xin, gate=gate, up=up, a=act,
                                    h=h, z=z))
                del gate, up, act, h
            x = x + m8b.rmsnorm(z, lw["post_ffw_norm"], a.eps)
            x = x * np.float32(lw["layer_scalar"][0])      # facts F2
            del lw, xin, z
        fw = self.store.get(self._n("final_norm"))
        return m8b.rmsnorm(x, fw, a.eps)


# --------------------------------------------------------------------------
# shared setup
# --------------------------------------------------------------------------

def setup(max_layers=None):
    base = json.loads(BASELINE_JSON.read_text())
    ckpt = base["checkpoint"]
    arch = g4.arch_gemma4(ckpt)
    if max_layers:
        arch.n_layers = min(arch.n_layers, max_layers)
    store = m8b.TensorStore(ckpt)
    t = base["dims"]["t"]
    walker = AttnGateWalker(store, arch, t)

    class A:
        text = str(Path.home() / "models" / "fineweb-edu" /
                   "sample_text.txt")
        tokens = None
        cal_seqs = 8
        val_seqs = 8
    A.t = t
    toks = m8b.load_token_stream(A, ckpt)
    cal, val = m8b.token_batches(toks, base["seed"], A.cal_seqs,
                                 A.val_seqs, t)
    return base, arch, walker, cal, val


def load_exps(arch):
    st = json.loads(STATS_JSON.read_text())
    exps = {}
    for row in st["layers"]:
        li = row["layer"]
        d = {}
        for s in TENSOR_E_SITES:
            if s in row and "e8" in row[s]:
                d[s] = row[s]["e8"]
            if s in row and "e8_head" in row[s]:
                d[s + "_head"] = row[s]["e8_head"]
        exps[li] = d
    assert len(exps) >= arch.n_layers, "stats pass incomplete"
    return exps


def run_one(walker, vsub, label, sites, wide=(), perhead=(), out=None,
            results=None, ref_sub=None, meta=None):
    walker.sites = frozenset(sites)
    walker.wide = frozenset(wide)
    walker.perhead = frozenset(perhead)
    t0 = time.time()
    loss = walker.loss(vsub)
    d = None if ref_sub is None else loss - ref_sub
    results[label] = dict(loss=loss,
                          delta_vs_fp_subset=d,
                          sites=sorted(sites), wide=sorted(wide),
                          perhead=sorted(perhead),
                          wall_s=round(time.time() - t0, 1))
    print("  %-16s loss %.4f  delta %s  (%.0fs)"
          % (label, loss,
             ("%+8.4f" % d) if d is not None else "    ref ",
             time.time() - t0), flush=True)
    out.write_text(json.dumps(dict(meta=meta, results=results),
                              indent=1))
    walker.sites = frozenset()
    walker.wide = frozenset()
    walker.perhead = frozenset()
    return loss


# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phase", required=True,
                    choices=["stats", "attrib", "widen", "equiv"])
    ap.add_argument("--take", type=int, default=2,
                    help="val windows for attrib/widen (default 2)")
    ap.add_argument("--sites", default=None,
                    help="comma list: widen targets / attrib subset")
    ap.add_argument("--max-layers", type=int, default=None,
                    help="truncate the stack (SMOKE ONLY)")
    args = ap.parse_args()

    base, arch, walker, cal, val = setup(args.max_layers)
    smoke = bool(args.max_layers)
    tag = " ** SMOKE (truncated) — results are not the model's **" \
        if smoke else ""
    print("m8b_gemma4_attn_gate --phase %s: %d layers (%d sliding/%d "
          "full)%s" % (
              args.phase, arch.n_layers,
              sum(1 for t in arch.layer_types[:arch.n_layers]
                  if t == "sliding_attention"),
              sum(1 for t in arch.layer_types[:arch.n_layers]
                  if t == "full_attention"), tag), flush=True)

    if args.phase == "equiv":
        refw = g4.Gemma4Walker(walker.store, arch, base["dims"]["t"])
        w1 = val[:1, :-1]
        h_ref = refw.walk(w1)
        h_new = walker.walk(w1)
        assert np.array_equal(h_ref, h_new), "NOT bit-exact"
        print("equiv: hooked walker BIT-EXACT vs m8b_gemma4_walker "
              "(%d layers, 1 window); peak RSS %.2f GB"
              % (arch.n_layers, m8b.rss_gb()))
        return

    if args.phase == "stats":
        walker.rec = [dict() for _ in range(arch.n_layers)]
        t0 = time.time()
        walker.walk(cal[:, :-1])
        wall = time.time() - t0
        rows = walker.rec
        walker.rec = None
        # sliding-vs-global family summary
        fam = {}
        for lt in ("sliding_attention", "full_attention"):
            sel = [r for r in rows if r.get("layer_type") == lt]
            if not sel:
                continue
            fam[lt] = {
                s: dict(
                    e8_min=min(r[s]["e8"] for r in sel),
                    e8_max=max(r[s]["e8"] for r in sel),
                    worst_ratio=max(r[s].get("ratio", 0.0)
                                    for r in sel))
                for s in TENSOR_E_SITES if all(s in r for r in sel)}
        outj = dict(
            meta=dict(experiment="m8b_gemma4_attn_gate --phase stats",
                      checkpoint=base["checkpoint"], seed=base["seed"],
                      t=base["dims"]["t"], cal_windows=int(cal.shape[0]),
                      smoke=smoke, wall_s=round(wall, 1),
                      box="[MEASURED WSL-BOX NT]" if not smoke
                      else "[SMOKE]",
                      note="range profiles on the fp reference forward; "
                           "e8 = ceil(log2(absmax/127)) per tensor; "
                           "per-head lists where head-structured; "
                           "scores/probs on the causal support only"),
            family_summary=fam, layers=rows)
        STATS_JSON.write_text(json.dumps(outj, indent=1))
        print("stats: %d layers in %.0fs; JSON -> %s; peak RSS %.2f GB"
              % (len(rows), wall, STATS_JSON, m8b.rss_gb()))
        return

    # attrib / widen need the stats exponents
    walker.exps = load_exps(arch)
    vsub = val[:args.take]
    meta = dict(experiment="m8b_gemma4_attn_gate --phase " + args.phase,
                checkpoint=base["checkpoint"], seed=base["seed"],
                t=base["dims"]["t"], val_take=int(vsub.shape[0]),
                smoke=smoke, fE=FE, fP=FP,
                box="[MEASURED WSL-BOX NT, val subset]" if not smoke
                else "[SMOKE]",
                ref_full=base["verdict"]["loss_ref"],
                note="first-order per-site attribution; FFN fp; "
                     "exponents frozen from the cal-window stats pass")
    print("val subset: %d of %d windows; ref(full) %.4f"
          % (vsub.shape[0], val.shape[0],
             base["verdict"]["loss_ref"]), flush=True)

    if args.phase == "attrib":
        results = {}
        ref_sub = run_one(walker, vsub, "none", (), out=ATTRIB_JSON,
                          results=results, meta=meta)
        meta["ref_subset"] = ref_sub
        site_list = (args.sites.split(",") if args.sites
                     else list(ALL_SITES))
        for s in site_list:
            run_one(walker, vsub, s, (s,), out=ATTRIB_JSON,
                    results=results, ref_sub=ref_sub, meta=meta)
        run_one(walker, vsub, "all_int8", ALL_SITES, out=ATTRIB_JSON,
                results=results, ref_sub=ref_sub, meta=meta)
        print("JSON ->", ATTRIB_JSON)
        print("peak RSS %.2f GB" % m8b.rss_gb())
        return

    # widen: int16 (e-8 / f+8) singles at the named sites, a per-head
    # exponent variant for head-axis sites, and the composed stack
    assert args.sites, "--phase widen needs --sites site1,site2,..."
    mat = args.sites.split(",")
    prev = json.loads(ATTRIB_JSON.read_text())["results"]
    ref_sub = prev["none"]["loss"]
    meta["ref_subset"] = ref_sub
    results = {}
    for s in mat:
        run_one(walker, vsub, s + "16", (s,), wide=(s,),
                out=WIDEN_JSON, results=results, ref_sub=ref_sub,
                meta=meta)
    headable = [s for s in mat if s in ("q", "k", "v", "scores", "ctx")]
    for s in headable:
        run_one(walker, vsub, s + "_ph8", (s,), perhead=(s,),
                out=WIDEN_JSON, results=results, ref_sub=ref_sub,
                meta=meta)
    # the composed stack: every site int8 except the material ones wide
    run_one(walker, vsub, "stack_wide", ALL_SITES, wide=mat,
            out=WIDEN_JSON, results=results, ref_sub=ref_sub, meta=meta)
    print("JSON ->", WIDEN_JSON)
    print("peak RSS %.2f GB" % m8b.rss_gb())


if __name__ == "__main__":
    main()
