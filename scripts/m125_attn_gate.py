"""m125_attn_gate — U-PERF3 round 9 lane PP: the ATTENTION-site
qualification gate for the frugal-lm 125M checkpoint (X2 = the memo's
AT-O1 as a C4-style gate run at 125M).

WHY: the original 125M quantization study (m125_int8_calibration.py)
ran attention fp32 — the 125M attention exponents were NEVER measured
(lane JJ's round-6 close recorded this).  X3 (one full attention layer
proven at 125M) must build on MEASURED exponents, in the exact form
lane CC produced for Gemma (scripts/m8b_gemma4_attn_gate.py — the
pattern of record; its Gemma defaults are untouched by this file).

Method (the Gemma gate pattern on the frugal adapter):
  --phase equiv   the precondition: this hooked walker with all hooks
                  off is BIT-EXACT vs the validated frugal walker
                  (m8b_int8_calibration.Walker, --arch frugal) on the
                  val windows: final-hidden array_equal, loss equal,
                  logits sha256 digests -> results/m125_attn_equiv.json
  --phase stats   one fp walk over the 8 calibration windows collecting
                  per-layer per-site range profiles (absmax/p999/p9999,
                  per-head where head-structured)
                  -> results/m125_attn_stats.json
  --phase attrib  the fp forward (FFN stays fp!) with quantize-dequant
                  at exactly ONE attention site at a time, int8 at the
                  stats pass's absmax-derived per-tensor power-of-two
                  exponents; first-order loss delta per site on the val
                  subset (--take 2) -> results/m125_attn_attrib.json
  --phase widen   int16 rerun (same absmax coverage, exponent e-8 =
                  256x finer step) at the named material sites, plus a
                  per-head-exponent variant and the composed stack row
                  -> results/m125_attn_widen.json
  --phase record  the AT-O1 table X3 consumes: per site per layer the
                  exponent, the class (int8/int16 from the attrib/widen
                  verdicts), the exp-member keying (eS, d_h 64, fE 9)
                  and wrho = fE + log2(T) -> results/m125_attn_at_o1.json

Sites at 125M (frugal arch, src/frugal_lm/model.py: pre-norm two-norm
sandwich, RoPE rotate-half, GQA H 12 / H_kv 4, d 768, d_h 64, scale
hd**-0.5, NO QK-norm):
  Wattn   wq/wk/wv/wo int8 per-tensor (weight anchor; norm gammas fp)
  xattn   attn_norm output = the attention seam input        [xn8, 2.1]
  q, k    RAW projection outputs, PRE-rope (NO QK-norm at 125M — the
          hook position matches Gemma's q8/k8: post-"norm", pre-rope;
          here the norm stage simply does not exist)         [q8/k8]
  v       raw v projection (no v_norm at 125M)               [v8]
  scores  masked SCALED logits (qb @ kb.T) * hd**-0.5 + mask (unlike
          Gemma the 125M walker carries the hd**-0.5 — s8 is the
          scaled site), quantized on the causal support only [s8, 2.4]
  exps    softmax numerator exp(s - max) in [0,1] at fixed-point fE=9,
          round-half-up (the exp table's OUTPUT resolution)  [E, 2.5]
  probs   softmax output in [0,1] at fixed-point fP=9, FLOOR (the
          spec's P = floor(E*2^fP/Sum) division form)        [P, 2.5]
  ctx     probs @ V head outputs (pre-concat/o_proj)         [o8, 2.6]
  ao      o_proj output                                      [ao8, 2.6]
  xres    the residual stream after the attention add        [xres1, 2.7]

Gemma sites ABSENT at 125M (by architecture, stated not papered):
  postn (post_attention_layernorm — frugal is the two-norm sandwich:
  attn_norm + mlp_norm only, so the Gemma four-norm requant edge does
  not exist), QK-norm q_norm/k_norm and the scale-less v_norm (AM-5),
  post_ffw_norm + the layer scalar (Gemma facts F2), and the
  sliding/global layer-family split (all 12 layers are plain causal).
  qr/kr (post-rope maxes) are recorded as stats like the Gemma gate.

Scales/windows: the m125 study's sampler verbatim (seed 1337, 8 cal +
8 val disjoint windows of T=512 from the local fineweb-edu-val shard;
scripts/m8b_verify_125m.py proved this sampler + walker reproduce the
committed calibration exponents 108/108 on this box).  Deltas are
FIRST-ORDER attribution (the real chain compounds); the 'all_int8' row
composes every attention site (still fp FFN) as the upper anchor.
Labels: [MEASURED WSL-BOX] on the val subset.
"""

import argparse
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125     # noqa: E402  (primitives, never edited)
import m8b_int8_calibration as m8b       # noqa: E402  (imported, never edited)

import os  # noqa: E402
CKPT = Path(os.environ.get(
    "M8B_TEST_CKPT",
    "/home/victor/models/125m-best-adamw-val3.0816/model.safetensors"))
TOKENS = Path(os.environ.get("M8B_TEST_TOKENS",
                             "/home/victor/shard-00000.npy"))
BASELINE_JSON = ROOT / "results" / "m125_int8_calibration.json"
EQUIV_JSON = ROOT / "results" / "m125_attn_equiv.json"
STATS_JSON = ROOT / "results" / "m125_attn_stats.json"
ATTRIB_JSON = ROOT / "results" / "m125_attn_attrib.json"
WIDEN_JSON = ROOT / "results" / "m125_attn_widen.json"
ATO1_JSON = ROOT / "results" / "m125_attn_at_o1.json"

SEED = 1337
T_TOKENS = 512
N_CAL = 8
N_VAL = 8
FE = 9   # exp table output frac bits (spec 2.5)
FP = 9   # softmax P frac bits (spec 2.5)
D_H = 64

TENSOR_E_SITES = ("xattn", "q", "k", "v", "scores", "ctx", "ao", "xres")
ALL_SITES = ("Wattn", "xattn", "q", "k", "v", "scores", "exps",
             "probs", "ctx", "ao", "xres")
# the +0.1-nat class boundary used in the FFN/Gemma rulings
POISON_NATS = 0.10


# --------------------------------------------------------------------------
# quantize-dequant primitives (the Gemma gate's conventions, verbatim)
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
# the hooked walker (subclass; the validated m8b Walker is untouched)
# --------------------------------------------------------------------------

class AttnGateWalker(m8b.Walker):
    """m8b.Walker (frugal arch) with (a) per-site range-stat recording,
    (b) quantize-dequant at declared attention sites.  With rec=None and
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
    def _attention(self, xn, lw):
        a = self.arch
        B, T, _ = xn.shape
        hd, H, Hk = a.head_dim, a.heads, a.kv_heads
        rep = H // Hk
        scale = hd ** -0.5
        rec = self.rec[self._li] if self.rec is not None else None
        # HOOK: attention seam input + weight anchor
        xn = self._apply("xattn", xn)
        if "Wattn" in self.sites:
            lw = dict(lw)
            for wname in ("wq", "wk", "wv", "wo"):
                W = lw[wname]
                e = m125.pow2_exp_for(float(np.abs(W).max()))
                lw[wname] = deq8(W.astype(np.float64),
                                 e).astype(np.float32)
        flat = xn.reshape(B * T, -1)
        q = (flat @ lw["wq"].T).reshape(B, T, H, hd)
        k = (flat @ lw["wk"].T).reshape(B, T, Hk, hd)
        v = (flat @ lw["wv"].T).reshape(B, T, Hk, hd)
        # HOOK: q/k/v sites (raw projections — NO QK-norm at 125M)
        q = self._apply("q", q, (1, 1, H, 1))
        k = self._apply("k", k, (1, 1, Hk, 1))
        v = self._apply("v", v, (1, 1, Hk, 1))
        if rec is not None:
            rec["layer"] = self._li
            _site_stats(rec, "xattn", xn, d_axis=True)
            _head_stats(rec, "q", q)
            _head_stats(rec, "k", k)
            _head_stats(rec, "v", v)
        cos, sin = self.cos[:T], self.sin[:T]
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
                # 125M HAS the hd**-0.5 scaling (unlike Gemma-4)
                s = (qb[:, h] @ kb[:, h // rep].T) * scale + mask
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

    # -- the walk (parent copy + xres hook line; NO postn at 125M) ----
    def walk(self, tokens, ffn_override=None, collect=None):
        a = self.arch
        B, T = tokens.shape
        emb = self.store.get(self._n("embed"))
        x = emb[tokens.reshape(-1)].reshape(B, T, a.d).astype(np.float32)
        del emb
        for l in range(a.n_layers):
            self._li = l
            lw = self.load_layer(l)
            xn = m8b.rmsnorm(x, lw["attn_norm"], a.eps)
            x = x + self._attention(xn, lw).reshape(B, T, a.d)
            x = self._apply("xres", x)                # HOOK: xres site
            if self.rec is not None:
                _site_stats(self.rec[l], "xres", x, d_axis=True)
            xin = m8b.rmsnorm(x, lw["mlp_norm"], a.eps)
            if ffn_override is not None:
                z = ffn_override(l, xin, lw)
            else:
                flat = xin.reshape(B * T, a.d)
                gate = flat @ lw["w_gate"].T
                up = flat @ lw["w_up"].T
                sa = gate / (1.0 + np.exp(-gate))   # SiLU
                h = sa * up
                z = (h @ lw["w_down"].T).reshape(B, T, a.d)
                if collect is not None:
                    collect(l, dict(x=xin, gate=gate, up=up, a=sa, h=h,
                                    z=z))
                del gate, up, sa, h
            x = x + z
            del lw
        fw = self.store.get(self._n("final_norm"))
        return m8b.rmsnorm(x, fw, a.eps)


# --------------------------------------------------------------------------
# shared setup
# --------------------------------------------------------------------------

def setup(max_layers=None):
    arch = m8b.arch_frugal()
    if max_layers:
        arch.n_layers = min(arch.n_layers, max_layers)
    store = m8b.TensorStore(CKPT)
    walker = AttnGateWalker(store, arch, T_TOKENS)
    toks = np.load(TOKENS, mmap_mode="r")
    cal, val = m8b.token_batches(toks, SEED, N_CAL, N_VAL, T_TOKENS)
    base = (json.loads(BASELINE_JSON.read_text())
            if BASELINE_JSON.exists() else {})
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
# the record phase: the AT-O1 table X3 consumes
# --------------------------------------------------------------------------

def build_record(arch, smoke):
    st = json.loads(STATS_JSON.read_text())
    at = json.loads(ATTRIB_JSON.read_text())["results"]
    wd = (json.loads(WIDEN_JSON.read_text())["results"]
          if WIDEN_JSON.exists() else {})
    classes = {}
    verdicts = {}
    for s in ALL_SITES:
        d = at.get(s, {}).get("delta_vs_fp_subset")
        if d is None:
            continue
        poisoned = d >= POISON_NATS
        cls = "int16" if poisoned else "int8"
        if s in ("exps", "probs"):
            cls = ("fixp%d+8" % (FE if s == "exps" else FP)) \
                if poisoned else "fixp%d" % (FE if s == "exps" else FP)
        classes[s] = cls
        verdicts[s] = dict(int8_delta_nats=d,
                           verdict="POISONED (widened class)"
                           if poisoned else "CLEAN at int8",
                           widen_delta_nats=(
                               wd.get(s + "16", {})
                               .get("delta_vs_fp_subset")))
    wrho = FE + int(math.log2(T_TOKENS))
    layers = []
    for row in st["layers"]:
        li = row["layer"]
        ent = dict(layer=li)
        for s in TENSOR_E_SITES:
            if s in row:
                ent[s] = dict(e8=row[s]["e8"],
                              cls=classes.get(s, "int8"))
                if "e8_head" in row[s]:
                    ent[s]["e8_head"] = row[s]["e8_head"]
        for s in ("qr", "kr"):
            if s in row:
                ent[s] = dict(e8=row[s]["e8"])
        eS = row["scores"]["e8"]
        ent["exp_member"] = dict(family="exp-neg-table-v1", eS=eS,
                                 d_h=D_H, fE=FE,
                                 key="(exp-neg, eS %d, d_h %d, fE %d)"
                                 % (eS, D_H, FE))
        ent["probs"] = dict(cls=classes.get("probs", "fixp%d" % FP),
                            **row.get("probs", {}))
        layers.append(ent)
    members = sorted(set(r["exp_member"]["eS"] for r in layers))
    outj = dict(
        meta=dict(experiment="m125_attn_gate --phase record (AT-O1)",
                  checkpoint=str(CKPT), seed=SEED, t=T_TOKENS,
                  d_h=D_H, fE=FE, fP=FP, wrho=wrho, smoke=smoke,
                  poison_threshold_nats=POISON_NATS,
                  note="the 125M attention exponent table for X3: "
                       "per-site per-layer absmax-derived power-of-two "
                       "exponents from the cal-window stats pass; "
                       "classes from the first-order attrib (+widen) "
                       "verdicts; exp members keyed (eS, d_h, fE); "
                       "wrho = fE + log2(T)"),
        site_verdicts=verdicts,
        distinct_eS=members,
        n_exp_members=len(members),
        layers=layers)
    ATO1_JSON.write_text(json.dumps(outj, indent=1))
    print("AT-O1 record -> %s" % ATO1_JSON)
    print("site classes: %s" % json.dumps(classes))
    print("distinct eS values (exp members needed): %s (%d members "
          "over %d layers)" % (members, len(members), len(layers)))
    for v in ("CLEAN at int8", "POISONED (widened class)"):
        names = [s for s in ALL_SITES
                 if verdicts.get(s, {}).get("verdict") == v]
        print("  %s: %s" % (v, ", ".join(names) if names else "(none)"))


# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phase", required=True,
                    choices=["equiv", "stats", "attrib", "widen",
                             "record"])
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
    print("m125_attn_gate --phase %s: %s, %d layers, d %d, H %d/%d, "
          "d_h %d%s" % (args.phase, arch.tag, arch.n_layers, arch.d,
                        arch.heads, arch.kv_heads, arch.head_dim, tag),
          flush=True)

    if args.phase == "record":
        build_record(arch, smoke)
        return

    if args.phase == "equiv":
        refw = m8b.Walker(walker.store, arch, T_TOKENS)
        w1 = val[:1, :-1]
        h_ref = refw.walk(w1)
        h_new = walker.walk(w1)
        assert np.array_equal(h_ref, h_new), "NOT bit-exact (hidden)"
        hd_dig = hashlib.sha256(np.ascontiguousarray(h_new)
                                .tobytes()).hexdigest()
        head = walker.store.get(walker._n("embed"))
        lg = (h_new[0] @ head.T).astype(np.float32)
        del head
        lg_dig = hashlib.sha256(np.ascontiguousarray(lg)
                                .tobytes()).hexdigest()
        t0 = time.time()
        loss_ref = refw.loss(val)
        loss_new = walker.loss(val)
        wall = time.time() - t0
        assert loss_ref == loss_new, (loss_ref, loss_new)
        committed = (base.get("verdict", {}) or {}).get("loss_ref")
        EQUIV_JSON.write_text(json.dumps(dict(
            experiment="m125_attn_gate --phase equiv",
            checkpoint=str(CKPT), seed=SEED, t=T_TOKENS, smoke=smoke,
            hidden_bit_exact=True,
            hidden_sha256=hd_dig, logits_w0_sha256=lg_dig,
            loss_val_8win=loss_new,
            loss_ref_committed_mlx=committed,
            note="hooked walker with all hooks off vs the validated "
                 "m8b frugal Walker: final hidden array_equal on val "
                 "window 0, loss equal on all %d val windows; the "
                 "committed mlx loss_ref differs at the documented "
                 "numpy-vs-mlx fp32 drift level" % val.shape[0]),
            indent=1))
        print("equiv: hooked walker BIT-EXACT vs m8b frugal Walker "
              "(%d layers; hidden sha256 %s..; logits sha256 %s..)"
              % (arch.n_layers, hd_dig[:16], lg_dig[:16]))
        print("equiv: val loss (8 win, numpy) %.6f both walkers; "
              "committed mlx ref %s; %.0fs; peak RSS %.2f GB"
              % (loss_new, committed, wall, m8b.rss_gb()))
        print("JSON ->", EQUIV_JSON)
        return

    if args.phase == "stats":
        walker.rec = [dict() for _ in range(arch.n_layers)]
        t0 = time.time()
        walker.walk(cal[:, :-1])
        wall = time.time() - t0
        rows = walker.rec
        walker.rec = None
        summ = {
            s: dict(e8_min=min(r[s]["e8"] for r in rows),
                    e8_max=max(r[s]["e8"] for r in rows),
                    worst_ratio=max(r[s].get("ratio", 0.0)
                                    for r in rows))
            for s in TENSOR_E_SITES if all(s in r for r in rows)}
        outj = dict(
            meta=dict(experiment="m125_attn_gate --phase stats",
                      checkpoint=str(CKPT), seed=SEED, t=T_TOKENS,
                      cal_windows=int(cal.shape[0]),
                      smoke=smoke, wall_s=round(wall, 1),
                      box="[MEASURED WSL-BOX]" if not smoke
                      else "[SMOKE]",
                      note="range profiles on the fp reference forward; "
                           "e8 = ceil(log2(absmax/127)) per tensor; "
                           "per-head lists where head-structured; "
                           "scores/probs on the causal support only"),
            site_summary=summ, layers=rows)
        STATS_JSON.write_text(json.dumps(outj, indent=1))
        print("stats: %d layers in %.0fs; JSON -> %s; peak RSS %.2f GB"
              % (len(rows), wall, STATS_JSON, m8b.rss_gb()))
        return

    # attrib / widen need the stats exponents
    walker.exps = load_exps(arch)
    vsub = val[:args.take]
    committed = (base.get("verdict", {}) or {}).get("loss_ref")
    meta = dict(experiment="m125_attn_gate --phase " + args.phase,
                checkpoint=str(CKPT), seed=SEED, t=T_TOKENS,
                val_take=int(vsub.shape[0]),
                smoke=smoke, fE=FE, fP=FP,
                box="[MEASURED WSL-BOX, val subset]" if not smoke
                else "[SMOKE]",
                ref_full_committed_mlx=committed,
                note="first-order per-site attribution; FFN fp; "
                     "exponents frozen from the cal-window stats pass")
    print("val subset: %d of %d windows; committed mlx ref %s"
          % (vsub.shape[0], val.shape[0], committed), flush=True)

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
