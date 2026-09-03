#!/usr/bin/env python3
"""[UPERF3-AE] m8b_mistral_attn_gate.py — the ATTENTION-site
qualification gate for Mistral-7B-v0.1 (round 12 lane AE, rung 1):
the CC pattern (scripts/m8b_gemma4_attn_gate.py) / the PP pattern
(scripts/m125_attn_gate.py) transplanted to the hf adapter of
scripts/m8b_int8_calibration.py (all imported, never edited).

WHY: the hash-line full-layer statement (hashline/src/attention.rs)
needs MEASURED per-site exponents and classes for Mistral-7B, in the
form PP produced for the 125M model (results/m125_attn_at_o1.json).
The 125M and Gemma gates found the attention compute core int8-clean
and the residual stream the one poisoned site (widened to int16); this
gate asks the same question of the 7B checkpoint the 32x512 FFN proof
was about.

Phases (as the PP gate; every phase is a separate foreground run):
  --phase equiv   the precondition: this hooked walker with all hooks
                  off is BIT-EXACT vs the validated m8b hf Walker on a
                  val window (final-hidden array_equal, logits sha256)
                  and loss-equal on the --take val subset
                  -> results/m8b_mistral_attn_equiv.json
  --phase stats   one fp walk over the calibration windows collecting
                  per-layer per-site range profiles (absmax/p999/p9999,
                  per-head where head-structured)
                  -> results/m8b_mistral_attn_stats.json
  --phase attrib  the fp forward (FFN fp) with quantize-dequant at ONE
                  attention site at a time at the stats exponents;
                  first-order loss delta per site on the val subset
                  (--take 2). RESUMABLE: --sites a,b runs a subset and
                  MERGES into the JSON -> results/m8b_mistral_attn_attrib.json
  --phase widen   int16 (e-8) singles at --sites + the composed
                  stack_wide row (merging) -> results/m8b_mistral_attn_widen.json
  --phase record  the AT-O1 table the statement consumes
                  -> results/m8b_mistral_attn_at_o1.json

Sites at Mistral-7B (hf arch: pre-norm two-norm sandwich, RoPE
rotate-half theta 1e4, GQA H 32 / H_kv 8, d 4096, d_h 128, scale
hd**-0.5, NO QK-norm; sliding window 4096 > T so plain causal):
  Wattn   wq/wk/wv/wo int8 per-tensor (weight anchor)
  Wnorm   attn_norm + mlp_norm GAMMAS int8 per-tensor (NEW vs CC/PP,
          which kept the gammas fp: the hash-line statement commits
          the gammas as int8 weights of the norm gadget)
  xattn   attn_norm output = the attention seam input        [xn8]
  q, k    raw projections, pre-rope                            [q8/k8]
  v       raw v projection                                     [v8]
  scores  THE RAW q.k logits (scaling 1.0 at the hook — the design
          memo's convention: 1/sqrt(d_h) lives in the exp member's
          decay, never in a shift; the 125M gate quantized the SCALED
          logits, which at d_h 64 is the same exponent + 3; at d_h 128
          only the raw form is an integer statement), quantized on
          the causal support, then scaled for the fp path   [s8]
  exps    exp(s - max) at fixed-point fE=9, round-half-up      [E]
  probs   softmax weights at fixed-point fP=9, FLOOR           [P]
  ctx     probs @ V head outputs                               [o8]
  ao      o_proj output                                        [ao8]
  xres    the residual stream after the attention add         [xres1]
qr/kr (post-rope maxes) recorded as stats.

Scales/windows: results/m8b_int8_calibration_wsl.json's (checkpoint,
seed 1337, the FineWeb sample tokenized with `tokenizers`, 8 cal + 8 val
disjoint windows of T=512). --tokens-cache caches the tokenized stream
as .npy in the scratch dir (the sampler is a deterministic function of
the stream). Labels: [MEASURED WSL-BOX] on the val subset; deltas are
first-order (the real chain compounds); 'all_int8' composes every
attention site (FFN fp) as the upper anchor.
"""

import argparse
import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import m125_int8_calibration as m125     # noqa: E402  (primitives, never edited)
import m8b_int8_calibration as m8b       # noqa: E402  (imported, never edited)

BASELINE_JSON = ROOT / "results" / "m8b_int8_calibration_wsl.json"
EQUIV_JSON = ROOT / "results" / "m8b_mistral_attn_equiv.json"
STATS_JSON = ROOT / "results" / "m8b_mistral_attn_stats.json"
ATTRIB_JSON = ROOT / "results" / "m8b_mistral_attn_attrib.json"
WIDEN_JSON = ROOT / "results" / "m8b_mistral_attn_widen.json"
ATO1_JSON = ROOT / "results" / "m8b_mistral_attn_at_o1.json"

FE = 9   # exp table output frac bits (spec 2.5)
FP = 9   # softmax P frac bits (spec 2.5)
POISON_NATS = 0.10

TENSOR_E_SITES = ("xattn", "q", "k", "v", "scores", "ctx", "ao", "xres")
ALL_SITES = ("Wattn", "Wnorm", "xattn", "q", "k", "v", "scores", "exps",
             "probs", "ctx", "ao", "xres")


# --------------------------------------------------------------------------
# quantize-dequant primitives (the gates' conventions, verbatim)
# --------------------------------------------------------------------------

def deq8(x, e):
    q = np.clip(np.round(x / (2.0 ** e)), -127, 127)
    return q * (2.0 ** e)


def deq16(x, e8):
    e = np.asarray(e8) - 8
    q = np.clip(np.floor(x / (2.0 ** e) + 0.5), -32767, 32767)
    return q * (2.0 ** e)


def fixp(x, f, mode):
    s = 2.0 ** f
    q = np.floor(x * s + 0.5) if mode == "round" else np.floor(x * s)
    return q / s


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
# the hooked walker (subclass of the validated hf Walker; parent untouched)
# --------------------------------------------------------------------------

class AttnGateWalker(m8b.Walker):
    """m8b.Walker (hf arch) with per-site range-stat recording and
    quantize-dequant at declared attention sites. With rec=None and no
    sites the forward is op-identical to the parent (--phase equiv)."""

    def __init__(self, store, arch, t_max):
        super().__init__(store, arch, t_max)
        self.rec = None
        self.sites = frozenset()
        self.wide = frozenset()
        self.perhead = frozenset()
        self.exps = None
        self._li = None

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
        """s: the RAW (unscaled, unmasked) q.k logits of head h."""
        if "scores" not in self.sites:
            return s
        ex = self.exps[self._li]
        e = (ex["scores_head"][h] if "scores" in self.perhead
             and "scores_head" in ex else ex["scores"])
        return deq16(s, e) if "scores" in self.wide else deq8(s, e)

    def _quant_w(self, lw, names):
        lw = dict(lw)
        for wname in names:
            W = lw[wname]
            e = m125.pow2_exp_for(float(np.abs(W).max()))
            lw[wname] = deq8(W.astype(np.float64), e).astype(np.float32)
        return lw

    def _attention(self, xn, lw):
        a = self.arch
        B, T, _ = xn.shape
        hd, H, Hk = a.head_dim, a.heads, a.kv_heads
        rep = H // Hk
        scale = hd ** -0.5
        rec = self.rec[self._li] if self.rec is not None else None
        xn = self._apply("xattn", xn)                 # HOOK: seam input
        if "Wattn" in self.sites:
            lw = self._quant_w(lw, ("wq", "wk", "wv", "wo"))
        flat = xn.reshape(B * T, -1)
        q = (flat @ lw["wq"].T).reshape(B, T, H, hd)
        k = (flat @ lw["wk"].T).reshape(B, T, Hk, hd)
        v = (flat @ lw["wv"].T).reshape(B, T, Hk, hd)
        q = self._apply("q", q, (1, 1, H, 1))          # HOOK: q/k/v
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
                qr_mx = np.maximum(qr_mx, np.abs(qb).max(axis=(0, 2)))
                kr_mx = np.maximum(kr_mx, np.abs(kb).max(axis=(0, 2)))
            for h in range(H):
                s_raw = qb[:, h] @ kb[:, h // rep].T      # RAW logits
                if rec is not None:
                    sc_h[h].append(np.abs(s_raw[tri]).astype(np.float32))
                s_raw = self._apply_scores(s_raw, h)      # HOOK: s8 (raw)
                s = s_raw * scale + mask
                s = s - s.max(axis=-1, keepdims=True)
                e = np.exp(s)
                e = self._apply("exps", e)                # HOOK: E
                w = e / e.sum(axis=-1, keepdims=True)
                w = self._apply("probs", w)               # HOOK: P
                if rec is not None:
                    pr_h[h].append(w[tri].astype(np.float32))
                out[b, :, h] = w @ v[b, :, h // rep]
        out = self._apply("ctx", out, (1, 1, H, 1))       # HOOK: ctx
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
            allp = np.concatenate([np.concatenate(pr_h[h]) for h in range(H)])
            spr = _prof(alls)
            spr["e8"] = m125.pow2_exp_for(spr["absmax"])
            spr["e8_scaled"] = m125.pow2_exp_for(spr["absmax"] * scale)
            spr["convention"] = "RAW q.k (scaling 1.0 at the hook)"
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
        ao = self._apply("ao", ao)                        # HOOK: ao
        if rec is not None:
            _site_stats(rec, "ao", ao, d_axis=True)
        return ao

    def walk(self, tokens, ffn_override=None, collect=None):
        a = self.arch
        B, T = tokens.shape
        emb = self.store.get(self._n("embed"))
        x = emb[tokens.reshape(-1)].reshape(B, T, a.d).astype(np.float32)
        del emb
        for l in range(a.n_layers):
            self._li = l
            lw = self.load_layer(l)
            if "Wnorm" in self.sites:
                lw = self._quant_w(lw, ("attn_norm", "mlp_norm"))
            if self.rec is not None:
                for nm in ("attn_norm", "mlp_norm"):
                    g = lw[nm]
                    self.rec[l][nm] = dict(absmax=float(np.abs(g).max()),
                                           e8=m125.pow2_exp_for(float(np.abs(g).max())),
                                           min=float(g.min()), max=float(g.max()))
            xn = m8b.rmsnorm(x, lw["attn_norm"], a.eps)
            x = x + self._attention(xn, lw).reshape(B, T, a.d)
            x = self._apply("xres", x)                    # HOOK: xres
            if self.rec is not None:
                _site_stats(self.rec[l], "xres", x, d_axis=True)
            xin = m8b.rmsnorm(x, lw["mlp_norm"], a.eps)
            if ffn_override is not None:
                z = ffn_override(l, xin, lw)
            else:
                flat = xin.reshape(B * T, a.d)
                gate = flat @ lw["w_gate"].T
                up = flat @ lw["w_up"].T
                sa = gate / (1.0 + np.exp(-gate))
                h = sa * up
                z = (h @ lw["w_down"].T).reshape(B, T, a.d)
                if collect is not None:
                    collect(l, dict(x=xin, gate=gate, up=up, a=sa, h=h, z=z))
                del gate, up, sa, h
            x = x + z
            del lw
        fw = self.store.get(self._n("final_norm"))
        return m8b.rmsnorm(x, fw, a.eps)


# --------------------------------------------------------------------------
# setup
# --------------------------------------------------------------------------

def setup(args):
    base = json.loads(BASELINE_JSON.read_text())
    ckpt = base["checkpoint"]
    arch = m8b.arch_hf(ckpt)
    if args.max_layers:
        arch.n_layers = min(arch.n_layers, args.max_layers)
    store = m8b.TensorStore(ckpt)
    t = base["dims"]["t"]
    walker = AttnGateWalker(store, arch, t)
    cache = Path(args.tokens_cache) if args.tokens_cache else None
    if cache is not None and cache.exists():
        toks = np.load(cache, mmap_mode="r")
        print("token stream: cached %s (%d tokens)" % (cache, len(toks)), flush=True)
    else:
        class A:
            text = str(Path.home() / "models" / "fineweb-edu" / "sample_text.txt")
            tokens = None
            cal_seqs = 8
            val_seqs = 8
        A.t = t
        toks = m8b.load_token_stream(A, ckpt)
        if cache is not None:
            np.save(cache, np.asarray(toks, dtype=np.int32))
    cal, val = m8b.token_batches(toks, base["seed"], 8, 8, t)
    return base, arch, walker, cal, val, t


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


def load_results(path):
    if path.exists():
        return json.loads(path.read_text())
    return None


def run_one(walker, vsub, label, sites, wide=(), perhead=(), out=None,
            results=None, ref_sub=None, meta=None):
    walker.sites = frozenset(sites)
    walker.wide = frozenset(wide)
    walker.perhead = frozenset(perhead)
    t0 = time.time()
    loss = walker.loss(vsub)
    d = None if ref_sub is None else loss - ref_sub
    results[label] = dict(loss=loss, delta_vs_fp_subset=d,
                          sites=sorted(sites), wide=sorted(wide),
                          perhead=sorted(perhead),
                          wall_s=round(time.time() - t0, 1))
    print("  %-16s loss %.4f  delta %s  (%.0fs, RSS %.2f GB)"
          % (label, loss, ("%+8.4f" % d) if d is not None else "    ref ",
             time.time() - t0, m8b.rss_gb()), flush=True)
    out.write_text(json.dumps(dict(meta=meta, results=results), indent=1))
    walker.sites = frozenset()
    walker.wide = frozenset()
    walker.perhead = frozenset()
    return loss


# --------------------------------------------------------------------------
# the record phase
# --------------------------------------------------------------------------

def build_record(arch, smoke, t):
    st = json.loads(STATS_JSON.read_text())
    at = json.loads(ATTRIB_JSON.read_text())["results"]
    wd = (json.loads(WIDEN_JSON.read_text())["results"] if WIDEN_JSON.exists() else {})
    classes, verdicts = {}, {}
    for s in ALL_SITES:
        d = at.get(s, {}).get("delta_vs_fp_subset")
        if d is None:
            continue
        poisoned = d >= POISON_NATS
        cls = "int16" if poisoned else "int8"
        if s in ("exps", "probs"):
            f = FE if s == "exps" else FP
            cls = ("fixp%d+8" % f) if poisoned else ("fixp%d" % f)
        classes[s] = cls
        verdicts[s] = dict(int8_delta_nats=d,
                           verdict="POISONED (widened class)" if poisoned else "CLEAN at int8",
                           widen_delta_nats=wd.get(s + "16", {}).get("delta_vs_fp_subset"))
    wrho = FE + int(math.log2(t))
    layers = []
    for row in st["layers"]:
        li = row["layer"]
        ent = dict(layer=li)
        for s in TENSOR_E_SITES:
            if s in row:
                ent[s] = dict(e8=row[s]["e8"], cls=classes.get(s, "int8"))
                if "e8_head" in row[s]:
                    ent[s]["e8_head"] = row[s]["e8_head"]
        for s in ("qr", "kr", "attn_norm", "mlp_norm"):
            if s in row:
                ent[s] = dict(e8=row[s]["e8"])
        eS = row["scores"]["e8"]
        ent["scores"]["e8_scaled"] = row["scores"].get("e8_scaled")
        ent["exp_member"] = dict(family="exp-neg-table-v1", eS_raw=eS,
                                 d_h=arch.head_dim, fE=FE,
                                 key="(exp-neg, eS_raw %d, d_h %d, fE %d)" % (eS, arch.head_dim, FE))
        ent["probs"] = dict(cls=classes.get("probs", "fixp%d" % FP), **row.get("probs", {}))
        layers.append(ent)
    members = sorted(set(r["exp_member"]["eS_raw"] for r in layers))
    outj = dict(
        meta=dict(experiment="m8b_mistral_attn_gate --phase record (AT-O1)",
                  checkpoint=st["meta"]["checkpoint"], seed=st["meta"]["seed"], t=t,
                  d_h=arch.head_dim, fE=FE, fP=FP, wrho=wrho, smoke=smoke,
                  poison_threshold_nats=POISON_NATS,
                  score_convention="RAW q.k at the hook (eS_raw keys the exp member; "
                                   "e8_scaled = the d_h^-0.5-scaled exponent beside it)",
                  note="the Mistral-7B attention exponent table for the hash-line full-layer "
                       "statement: per-site per-layer absmax-derived power-of-two exponents from "
                       "the cal-window stats pass; classes from the first-order attrib (+widen) "
                       "verdicts; exp members keyed (eS_raw, d_h, fE); wrho = fE + log2(T)"),
        site_verdicts=verdicts, distinct_eS_raw=members, n_exp_members=len(members),
        layers=layers)
    ATO1_JSON.write_text(json.dumps(outj, indent=1))
    print("AT-O1 record -> %s" % ATO1_JSON)
    print("site classes: %s" % json.dumps(classes))
    print("distinct eS_raw values (exp members needed): %s (%d members over %d layers)"
          % (members, len(members), len(layers)))
    for v in ("CLEAN at int8", "POISONED (widened class)"):
        names = [s for s in ALL_SITES if verdicts.get(s, {}).get("verdict") == v]
        print("  %s: %s" % (v, ", ".join(names) if names else "(none)"))


# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--phase", required=True,
                    choices=["equiv", "stats", "attrib", "widen", "record"])
    ap.add_argument("--take", type=int, default=2)
    ap.add_argument("--sites", default=None, help="comma list (attrib subset / widen targets)")
    ap.add_argument("--stack", action="store_true", help="widen: also run the composed stack_wide row")
    ap.add_argument("--all-int8", action="store_true", help="attrib: also run the composed all_int8 row")
    ap.add_argument("--cal-take", type=int, default=8, help="stats: calibration windows to walk")
    ap.add_argument("--max-layers", type=int, default=None, help="truncate the stack (SMOKE ONLY)")
    ap.add_argument("--tokens-cache", default=None, help=".npy cache of the tokenized stream")
    args = ap.parse_args()

    base, arch, walker, cal, val, t = setup(args)
    smoke = bool(args.max_layers)
    tag = " ** SMOKE (truncated) — results are not the model's **" if smoke else ""
    print("m8b_mistral_attn_gate --phase %s: %s, %d layers, d %d, H %d/%d, d_h %d, T %d%s"
          % (args.phase, arch.tag, arch.n_layers, arch.d, arch.heads, arch.kv_heads,
             arch.head_dim, t, tag), flush=True)

    if args.phase == "record":
        build_record(arch, smoke, t)
        return

    if args.phase == "equiv":
        refw = m8b.Walker(walker.store, arch, t)
        w1 = val[:1, :-1]
        t0 = time.time()
        h_ref = refw.walk(w1)
        t_walk = time.time() - t0
        h_new = walker.walk(w1)
        assert np.array_equal(h_ref, h_new), "NOT bit-exact (hidden)"
        hd_dig = hashlib.sha256(np.ascontiguousarray(h_new).tobytes()).hexdigest()
        head = walker.store.get(walker._n("lm_head"))
        lg = (h_new[0] @ head.T).astype(np.float32)
        del head
        lg_dig = hashlib.sha256(np.ascontiguousarray(lg).tobytes()).hexdigest()
        vsub = val[:args.take]
        t0 = time.time()
        loss_ref = refw.loss(vsub)
        loss_new = walker.loss(vsub)
        wall = time.time() - t0
        assert loss_ref == loss_new, (loss_ref, loss_new)
        EQUIV_JSON.write_text(json.dumps(dict(
            experiment="m8b_mistral_attn_gate --phase equiv",
            checkpoint=base["checkpoint"], seed=base["seed"], t=t, smoke=smoke,
            hidden_bit_exact=True, hidden_sha256=hd_dig, logits_w0_sha256=lg_dig,
            loss_val_subset=loss_new, val_take=int(vsub.shape[0]),
            loss_ref_committed_8win=base["verdict"]["loss_ref"],
            one_window_walk_s=round(t_walk, 1),
            note="hooked walker with all hooks off vs the validated m8b hf Walker: final hidden "
                 "array_equal on val window 0, loss equal on the val subset"), indent=1))
        print("equiv: hooked walker BIT-EXACT vs m8b hf Walker (%d layers; hidden sha256 %s..; "
              "logits sha256 %s..)" % (arch.n_layers, hd_dig[:16], lg_dig[:16]))
        print("equiv: val loss (%d win) %.6f both walkers; committed 8-win ref %.6f; one-window "
              "walk %.0fs; subset losses %.0fs; peak RSS %.2f GB"
              % (vsub.shape[0], loss_new, base["verdict"]["loss_ref"], t_walk, wall, m8b.rss_gb()))
        print("JSON ->", EQUIV_JSON)
        return

    if args.phase == "stats":
        walker.rec = [dict() for _ in range(arch.n_layers)]
        csub = cal[:args.cal_take]
        t0 = time.time()
        walker.walk(csub[:, :-1])
        wall = time.time() - t0
        rows = walker.rec
        walker.rec = None
        summ = {s: dict(e8_min=min(r[s]["e8"] for r in rows), e8_max=max(r[s]["e8"] for r in rows),
                        worst_ratio=max(r[s].get("ratio", 0.0) for r in rows))
                for s in TENSOR_E_SITES if all(s in r for r in rows)}
        outj = dict(
            meta=dict(experiment="m8b_mistral_attn_gate --phase stats", checkpoint=base["checkpoint"],
                      seed=base["seed"], t=t, cal_windows=int(csub.shape[0]), smoke=smoke,
                      wall_s=round(wall, 1), box="[MEASURED WSL-BOX NT]" if not smoke else "[SMOKE]",
                      score_convention="RAW q.k (scaling 1.0 at the hook); e8_scaled beside it",
                      note="range profiles on the fp reference forward; e8 = ceil(log2(absmax/127)) "
                           "per tensor; per-head lists where head-structured; scores/probs on the "
                           "causal support only; attn_norm/mlp_norm = the gamma vectors"),
            site_summary=summ, layers=rows)
        STATS_JSON.write_text(json.dumps(outj, indent=1))
        print("stats: %d layers, %d cal windows in %.0fs; JSON -> %s; peak RSS %.2f GB"
              % (len(rows), csub.shape[0], wall, STATS_JSON, m8b.rss_gb()))
        return

    walker.exps = load_exps(arch)
    vsub = val[:args.take]
    meta = dict(experiment="m8b_mistral_attn_gate --phase " + args.phase,
                checkpoint=base["checkpoint"], seed=base["seed"], t=t,
                val_take=int(vsub.shape[0]), smoke=smoke, fE=FE, fP=FP,
                box="[MEASURED WSL-BOX NT, val subset]" if not smoke else "[SMOKE]",
                ref_full_committed_8win=base["verdict"]["loss_ref"],
                note="first-order per-site attribution; FFN fp; exponents frozen from the "
                     "cal-window stats pass; phases merge into the JSON across runs")
    print("val subset: %d of %d windows; committed 8-win ref %.4f"
          % (vsub.shape[0], val.shape[0], base["verdict"]["loss_ref"]), flush=True)

    if args.phase == "attrib":
        prev = load_results(ATTRIB_JSON)
        results = prev["results"] if prev and not smoke else {}
        if "none" in results:
            ref_sub = results["none"]["loss"]
            print("  %-16s loss %.4f  (cached)" % ("none", ref_sub))
        else:
            ref_sub = run_one(walker, vsub, "none", (), out=ATTRIB_JSON, results=results, meta=meta)
        meta["ref_subset"] = ref_sub
        site_list = args.sites.split(",") if args.sites else list(ALL_SITES)
        for s in site_list:
            if s in results:
                print("  %-16s (cached) delta %+8.4f" % (s, results[s]["delta_vs_fp_subset"]))
                continue
            run_one(walker, vsub, s, (s,), out=ATTRIB_JSON, results=results, ref_sub=ref_sub, meta=meta)
        if args.all_int8 and "all_int8" not in results:
            run_one(walker, vsub, "all_int8", ALL_SITES, out=ATTRIB_JSON, results=results,
                    ref_sub=ref_sub, meta=meta)
        print("JSON ->", ATTRIB_JSON)
        print("peak RSS %.2f GB" % m8b.rss_gb())
        return

    assert args.sites, "--phase widen needs --sites site1,site2,..."
    mat = args.sites.split(",")
    prevA = json.loads(ATTRIB_JSON.read_text())["results"]
    ref_sub = prevA["none"]["loss"]
    meta["ref_subset"] = ref_sub
    prev = load_results(WIDEN_JSON)
    results = prev["results"] if prev and not smoke else {}
    for s in mat:
        if s + "16" in results:
            print("  %-16s (cached) delta %+8.4f" % (s + "16", results[s + "16"]["delta_vs_fp_subset"]))
            continue
        run_one(walker, vsub, s + "16", (s,), wide=(s,), out=WIDEN_JSON, results=results,
                ref_sub=ref_sub, meta=meta)
    if args.stack:
        run_one(walker, vsub, "stack_wide", ALL_SITES, wide=mat, out=WIDEN_JSON, results=results,
                ref_sub=ref_sub, meta=meta)
    print("JSON ->", WIDEN_JSON)
    print("peak RSS %.2f GB" % m8b.rss_gb())


if __name__ == "__main__":
    main()
