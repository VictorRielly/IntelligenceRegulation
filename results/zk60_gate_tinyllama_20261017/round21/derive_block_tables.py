#!/usr/bin/env python3
"""[gate round 21, 2026-10-29] AN INDEPENDENT GATE-SIDE DERIVATION OF THE PUBLIC
BLOCK TABLES THE GATE TAKES FROM A CLASSIFIER CAPTURE, from the public T128
export, compared BYTE FOR BYTE with the capture.  NOT a privacy result.

    python3 derive_block_tables.py --capture DIR --export DIR --out JSON
                                   [--blocks 1,2,...] [--controls]

Gate rounds 19 / 20 TAKE fifteen public tables per R13 block stage (seventeen
arrays) from the capture and check their length, digest and structure, then
the terminal identity on them.  That they are the EXPORT's tables was attested
only by the token recorder's own `export_replay` (token r17, test-only).  This
script derives every one of them again, from the definitions in the native
code (READ: token frozen-r17 `accuracy_fold.rs`, `accuracy_act.rs`,
`accuracy_aligned.rs`, `accuracy_groups.rs`, `accuracy_tables.rs`,
`argument.rs` SC_QMM..SC_DMM / `rope_tables_at` / `table_values_exp_at` /
SC_DZC's gains, `argument_accuracy.rs` TAB / QZC, `trained_block.rs`
`pad_matrix` and the head map, `trained_accuracy.rs` `load_for_registry`,
zkp-core `mle.rs` `eq_table_msb`, `field.rs`), with its own arithmetic (no
token-lane code is imported or run), from:

* the export's per-layer arrays, each SHA-256-checked against its layer
  manifest, each manifest against `profile.json`, and `profile.json` against
  the digest the run's export names (2ba468f9...);
* the slot's own public challenges as the capture records them (the
  `definition_challenges` and the stage's LogUp challenges; gate round 20's
  replay re-derived every one of them from the transcript, 263,324 challenges,
  on the same bundle bytes, pinned here by the manifest's SHA-256s).

The seventeen arrays per block stage (slot: tables):
   5 fold(w_q)  6 fold(w_k)  7 fold(w_v)  10 fold(w_o)  11 fold(w_g)  12 fold(w_u)
  13 fold(w_d)  14 gamma_a, gamma_m  15 rope_cos@Q, rope_sin@Q
  16 rope_cos@Kv, rope_sin@Kv  18 group_column  19 exp_values, act3_values,
  act_support

The ACT3 rows are checked against FOUR SiLU sources: the export's raw `act`
words, a float64 transcription of the definition (`silu_table_for`), Sol's
reference formula (`reference_silu.py`, transcribed: that script writes into
Sol's tree and covers only the nine standard members, so it is not run), an
exact 60-digit Decimal evaluation, and the native tree's own reference vectors
`r13_vectors/silu_*.bin`.  The exp words are checked against
`exp_table_generate` (float64) and an exact evaluation.

Reads `arrays.bin` with pread (no mmap), so the store's pages are page cache,
not this process's RSS (O20-1).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import resource
import sys
import time
from decimal import Decimal, getcontext, ROUND_FLOOR

import numpy as np

P = (1 << 64) - (1 << 32) + 1            # zkp-core field.rs P
NONRESIDUE = 7                           # zkp-core field.rs NONRESIDUE (Fp2 = Fp[u]/(u^2 - 7))
TAG_EXP, TAG_ACT = 129, 134              # tables_attn.rs TAG_EXP / TAG_ACT
SILU_MEMBERS = [(-5, -13), (-4, -13), (-4, -12), (-3, -12), (-3, -11),
                (-2, -11), (-1, -11), (-1, -10), (-1, -9)]   # accuracy_tables.rs
SHIELD_MEMBER = (0, -8)                  # Registry::Shieldstral's extra member
EXPECTED_PROFILE_SHA = "2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0"
VECTORS = ("/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/frozen-r17/"
           "hashline/src/private_block/r13_vectors")
SLOT_NAMES = {5: "09Q matmul", 6: "09K matmul", 7: "09V matmul", 10: "12 Wo matmul", 11: "13G gate matmul",
              12: "13U up matmul", 13: "13D down matmul", 14: "03 D zero-check", 15: "04 Q zero-check",
              16: "05 KV zero-check", 18: "14 F zero-check", 19: "TAB table helper"}


# ---------------------------------------------------------------- the field
def fmul(a, b):
    return ((a[0] * b[0] + NONRESIDUE * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)


def fadd(a, b):
    return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)


def k(v):
    return (int(v) % P, 0)


def eq_table_msb(r):
    """eq(r, x) for x in {0,1}^n with r[0] the MOST significant bit of x"""
    t = [(1, 0)]
    for ri in r:
        om = ((1 - ri[0]) % P, (-ri[1]) % P)
        nt = []
        for e in t:
            nt.append(fmul(e, om))
            nt.append(fmul(e, ri))
        t = nt
    return t


def to_bytes(c0, c1):
    a = np.empty((len(c0), 2), dtype="<u8")
    a[:, 0] = c0
    a[:, 1] = c1
    return a.tobytes()


def signed_mod(v):
    """an int64 numpy array -> its canonical residues as uint64"""
    v = np.asarray(v, dtype=np.int64)
    out = v.astype(np.uint64)
    neg = v < 0
    out[neg] = np.uint64(P) - (-v[neg]).astype(np.uint64)
    return out


# ------------------------------------------------------------- the matrix folds
def limbs(weighted):
    """K Fp2 values -> a float64 (K, 8) matrix of their 16-bit limbs (c0 limbs 0..3, c1 limbs 0..3)"""
    a = np.array(weighted, dtype=np.uint64).reshape(-1, 2)
    out = np.empty((a.shape[0], 8), dtype=np.float64)
    for c in range(2):
        for j in range(4):
            out[:, 4 * c + j] = ((a[:, c] >> np.uint64(16 * j)) & np.uint64(0xFFFF)).astype(np.float64)
    return out


def combine(S):
    """exact integer limb sums (float64, |.| < 2^53) -> canonical (c0, c1) uint64 arrays"""
    if not np.all(np.abs(S) < 2.0 ** 52) or not np.array_equal(S, np.rint(S)):
        raise ValueError("a limb sum left the exact float64 range")
    Si = np.rint(S).astype(np.int64)
    res = []
    for c in range(2):
        acc = [0] * S.shape[0]
        for j in range(4):
            col = Si[:, 4 * c + j].tolist()
            sh = 1 << (16 * j)
            acc = [x + y * sh for x, y in zip(acc, col)]
        res.append(np.array([x % P for x in acc], dtype=np.uint64))
    return res


def fold_rows(W, weighted_of_out, inner_pad, imap, chunk=512):
    """argument.rs SC_QMM / KMM / VMM / WO (Axis::Rows): out[imap(i)] = sum_o weighted(o) W[o, i]"""
    to, ti = W.shape
    wl = limbs(weighted_of_out)
    S = np.zeros((ti, 8), dtype=np.float64)
    for o0 in range(0, to, chunk):
        S += W[o0:o0 + chunk].astype(np.float64).T @ wl[o0:o0 + chunk]
    c0s, c1s = combine(S)
    c0 = np.zeros(inner_pad, dtype=np.uint64)
    c1 = np.zeros(inner_pad, dtype=np.uint64)
    idx = np.array([imap(i) for i in range(ti)], dtype=np.int64)
    c0[idx], c1[idx] = c0s, c1s
    return c0, c1


def fold_cols(W, weighted_of_in, rows_pad, chunk=512):
    """argument.rs SC_GMM / UMM / DMM (Axis::Columns): out[r] = sum_j weighted(j) W[r, j]"""
    to, ti = W.shape
    wl = limbs(weighted_of_in)
    S = np.empty((to, 8), dtype=np.float64)
    for r0 in range(0, to, chunk):
        S[r0:r0 + chunk] = W[r0:r0 + chunk].astype(np.float64) @ wl
    c0s, c1s = combine(S)
    c0 = np.zeros(rows_pad, dtype=np.uint64)
    c1 = np.zeros(rows_pad, dtype=np.uint64)
    c0[:to], c1[:to] = c0s, c1s
    return c0, c1


# ------------------------------------------------------------- SiLU and exp
_EXACT_CACHE = {}


def silu_float64(e_in, e_out, shield):
    """accuracy_tables.rs silu_table_for, transcribed (float64, the same libm exp)"""
    import math
    if (e_in, e_out) in SILU_MEMBERS:
        step, ostep = 2.0 ** (e_in - 4), 2.0 ** e_out
        out = []
        for gate in range(-2048, 2048):
            x = gate * step
            value = x / (1.0 + math.exp(-x))
            out.append(int(max(-32767.0, min(32767.0, math.floor(value / ostep + 0.5)))))
        return out
    if shield and (e_in, e_out) == SHIELD_MEMBER:
        out = []
        for gate in range(-2048, 2048):
            x = gate / 16.0
            w = math.floor(256.0 * x / (1.0 + math.exp(-x)) + 0.5)
            if not (-32767 <= w <= 32767):
                raise ValueError("Shieldstral SiLU word exceeds signed16")
            out.append(int(w))
        return out
    raise ValueError(f"SiLU member {(e_in, e_out)} is not in the registry")


def silu_sol_formula(e_in, e_out):
    """Sol's reference_silu.py formula (nine standard members), transcribed without its file writes"""
    import math
    words = []
    for gate in range(-2048, 2048):
        x = gate * 2.0 ** (e_in - 4)
        value = math.floor(x / (1 + math.exp(-x)) / 2.0 ** e_out + 0.5)
        words.append(max(-32767, min(32767, value)))
    return words


def silu_exact(e_in, e_out, clamp):
    """exact (60-digit Decimal) floor(x sigma(x) / 2^e_out + 1/2) and the closest approach to a rounding tie"""
    key = (e_in, e_out, clamp)
    if key in _EXACT_CACHE:
        return _EXACT_CACHE[key]
    getcontext().prec = 60
    two = Decimal(2)
    step = two ** (e_in - 4)
    oscale = two ** (-e_out)
    half = Decimal("0.5")
    words, margin = [], Decimal(1)
    for gate in range(-2048, 2048):
        x = Decimal(gate) * step
        v = x / (1 + (-x).exp())
        y = v * oscale + half
        w = int(y.to_integral_value(rounding=ROUND_FLOOR))
        frac = y - w
        margin = min(margin, frac, 1 - frac)
        if clamp:
            w = max(-32767, min(32767, w))
        words.append(w)
    _EXACT_CACHE[key] = (words, float(margin))
    return _EXACT_CACHE[key]


def exp_float64(e_s, head_dim, f_e):
    """tables_attn.rs exp_table_generate, transcribed"""
    import math
    lam = 2.0 ** e_s / math.sqrt(head_dim)
    scale = 2.0 ** f_e
    return [int(math.floor(scale * math.exp(-d * lam) + 0.5)) for d in range(256)]


def exp_exact(e_s, head_dim, f_e):
    getcontext().prec = 60
    lam = Decimal(2) ** e_s / Decimal(head_dim).sqrt()
    scale = Decimal(2) ** f_e
    out, margin = [], Decimal(1)
    for d in range(256):
        y = scale * (-(Decimal(d) * lam)).exp() + Decimal("0.5")
        w = int(y.to_integral_value(rounding=ROUND_FLOOR))
        margin = min(margin, y - w, 1 - (y - w))
        out.append(w)
    return out, float(margin)


# ------------------------------------------------------------------ helpers
def sha256_file(path, chunk=8 << 20):
    h = hashlib.sha256()
    buf = bytearray(chunk)
    mv = memoryview(buf)
    with open(path, "rb", buffering=0) as fh:
        while True:
            n = fh.readinto(buf)
            if not n:
                break
            h.update(mv[:n])
    return h.hexdigest()


def mem():
    out = {"maxrss_gib": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 2 ** 20, 3)}
    try:
        with open("/proc/self/status") as fh:
            for line in fh:
                if line.split(":")[0] in ("VmRSS", "RssAnon", "RssFile", "VmHWM"):
                    out[line.split(":")[0]] = round(int(line.split()[1]) / 2 ** 20, 3)
    except OSError:
        pass
    return out


class Layer:
    """one export layer, every array SHA-256-checked against its manifest before use"""

    def __init__(self, export, entry, verify=True):
        self.dir = os.path.join(export, entry["dir"])
        mpath = os.path.join(self.dir, "manifest.json")
        mbytes = open(mpath, "rb").read()
        self.manifest_sha256 = hashlib.sha256(mbytes).hexdigest()
        if self.manifest_sha256 != entry["manifest_sha256"]:
            raise ValueError(f"{mpath}: manifest digest is not profile.json's")
        self.m = json.loads(mbytes)
        if self.m["layer"] != entry["layer"]:
            raise ValueError(f"{mpath}: the manifest is for another layer")
        self.index = entry["layer"]
        self.c = self.m["constants"]
        self.verified = {}
        if verify:
            for name, a in self.m["arrays"].items():
                got = sha256_file(os.path.join(self.dir, a["file"]))
                if got != a["sha256"]:
                    raise ValueError(f"{self.dir}/{a['file']}: SHA-256 is not the manifest's")
                self.verified[name] = got

    def arr(self, name):
        a = self.m["arrays"][name]
        dt = {"int8": np.int8, "int16": "<i2", "int64": "<i8"}[a["dtype"]]
        x = np.fromfile(os.path.join(self.dir, a["file"]), dtype=dt)
        if x.size != int(np.prod(a["shape"])):
            raise ValueError(f"{name}: size is not the manifest's shape")
        return x.reshape(a["shape"])


# --------------------------------------------------------------- the derivation
class Shape:
    def __init__(self, s):
        self.tokens, self.width, self.hidden = s["tokens"], s["width"], s["hidden"]
        self.q_heads, self.kv_heads, self.hd = s["q_heads"], s["kv_heads"], s["head_dim"]
        self.t_pad, self.d_pad, self.h_pad, self.f_pad = s["t_pad"], s["d_pad"], s["h_pad"], s["f_pad"]
        self.q_pad = self.h_pad * self.hd
        self.qw = self.q_heads * self.hd
        self.kvw = self.kv_heads * self.hd
        self.spg = self.h_pad // self.kv_heads

    def head_slot(self, h):
        group = self.q_heads // self.kv_heads
        return (h // group) * self.spg + (h % group)

    def qmap(self, j):
        return self.head_slot(j // self.hd) * self.hd + j % self.hd

    def true_head(self, sl):
        return sl < self.h_pad and sl % self.spg < self.q_heads // self.kv_heads


def accuracy_public(layer, sh, controls=None):
    """the verifier-derived R13 public data of one layer (AccuracyPublic): the gate fold multipliers, G,
    the scaled SiLU tables -- with the registry's checks (accuracy_groups / accuracy_aligned)"""
    controls = controls or {}
    c = layer.c
    base_in, base_out = c["silu_member"]
    sh_g, sh_h = c["sh_g"], c["sh_h"]
    groups = [tuple(int(v) for v in row) for row in layer.arr("silu_groups")]
    ids = [int(v) for v in layer.arr("silu_group_ids")]
    m_g = [int(v) for v in layer.arr("m_g")]
    raw = layer.arr("act").astype(np.int64)
    permitted = set(SILU_MEMBERS) | {SHIELD_MEMBER}
    findings = []
    if not (1 <= len(groups) <= 4) or len(ids) != sh.hidden or len(m_g) != sh.hidden:
        findings.append("group / channel array shapes")
    if (base_in, base_out) not in permitted or not (1 <= sh_g <= 8) or not (13 <= sh_h <= 16):
        findings.append("base member or shift outside the declared class")
    if any(g not in permitted for g in groups) or any(groups[i] >= groups[i + 1] for i in range(len(groups) - 1)):
        findings.append("registry members not unique / canonical")
    if any(i >= len(groups) for i in ids) or any(g not in ids for g in range(len(groups))) \
            or any(not (1 <= m <= 64) for m in m_g):
        findings.append("invalid group id, unused group or non-narrow gate multiplier")
    gate_shifts = [sh_g + 10 + (groups[i][0] - base_in) for i in ids]
    product_shifts = [sh_h - 8 - (groups[i][1] - base_out) for i in ids]
    G = max(max(gate_shifts), 17)
    if "G" in controls:
        G = controls["G"]
    if any(not (1 <= s <= 24) for s in gate_shifts) or G > 24 or any(not (0 <= s <= 13) for s in product_shifts):
        findings.append("effective shift outside the counted window")
    gfold = [m << (G - s) for m, s in zip(m_g, gate_shifts)]
    if any(g > 1 << 14 for g in gfold):
        findings.append("folded gate coefficient exceeds the no-wrap class")
    # the raw tables against the generators, and the scaled tables (accuracy_aligned.rs)
    silu = []
    scaled = []
    for gi, (e_in, e_out) in enumerate(groups):
        exported = raw[gi].tolist()
        f64 = silu_float64(e_in, e_out, shield=True)
        clamp = (e_in, e_out) in SILU_MEMBERS
        exact, margin = silu_exact(e_in, e_out, clamp)
        sol = silu_sol_formula(e_in, e_out) if clamp else None
        vec = np.fromfile(os.path.join(VECTORS, f"silu_{e_in}_{e_out}.bin"), dtype="<i2").tolist()
        rec = {"member": [e_in, e_out], "export_equals_float64_definition": exported == f64,
               "export_equals_exact_decimal": exported == exact,
               "export_equals_native_reference_vectors": exported == vec,
               "export_equals_sol_formula": (exported == sol) if sol is not None else "n/a (member (0,-8) not in Sol's script)",
               "closest_approach_to_a_rounding_tie": margin, "zero_row_is_0": exported[2048] == 0,
               "min": min(exported), "max": max(exported)}
        silu.append(rec)
        if not (rec["export_equals_float64_definition"] and rec["export_equals_exact_decimal"]
                and rec["export_equals_native_reference_vectors"] and sol in (None, exported) and exported[2048] == 0):
            findings.append(f"SiLU member {(e_in, e_out)}: a source disagrees")
        exponent = 24 - sh_h + (e_out - base_out)
        if not (3 <= exponent <= 16):
            findings.append("scaled-table exponent outside the Shieldstral class")
        words = f64 if "raw_bump" not in controls or gi != 0 else [w + (1 if i == 100 else 0) for i, w in enumerate(f64)]
        sw = [w * (1 << exponent) for w in words]
        if any(abs(v) > 32767 * (1 << 16) for v in sw):
            findings.append("scaled word outside the signed class")
        scaled.append(sw)
    return {"groups": groups, "ids": ids, "G": G, "gate_fold": gfold, "scaled": scaled, "silu": silu,
            "base": [base_in, base_out], "sh_g": sh_g, "sh_h": sh_h, "findings": findings}


def derive_stage(doc, layer, sh, acc, controls=None):
    """the seventeen arrays of one block stage, as (name, slot, table index, (c0, c1))"""
    controls = controls or {}
    args = doc["arguments"]
    out = []

    def pubs(slot):
        a = args[slot]
        if not a["name"].startswith(SLOT_NAMES[slot]):
            raise ValueError(f"slot {slot} is {a['name']!r}, not {SLOT_NAMES[slot]!r}")
        return [j for j, t in enumerate(a["tables"]) if t["kind"] == "public"]

    def rj(slot, n):
        dc = args[slot]["definition_challenges"]
        if "rj_from" in controls and controls["rj_from"][1] == slot:
            dc = args[controls["rj_from"][0]]["definition_challenges"]
        return [(int(x[0]), int(x[1])) for x in dc[-n:]]

    lg = lambda v: v.bit_length() - 1
    m = {n: [int(v) for v in layer.arr(n)] for n in ("m_q", "m_k", "m_v", "m_o", "m_u", "m_d")}
    if "m_q_bump" in controls:
        m["m_q"][0] += 1
    gfold = list(acc["gate_fold"])
    if "m_g_bump" in controls:
        gfold[0] += 1 << (acc["G"] - (acc["sh_g"] + 10 + (acc["groups"][acc["ids"][0]][0] - acc["base"][0])))

    def check_coeff(cs, W):
        if any(v > 1 << 14 for v in cs):
            raise ValueError("a fold coefficient exceeds 2^14")
        if (W == -128).any():
            raise ValueError("a weight is i8::MIN")

    # ---- the four attention matmuls, Axis::Rows (outputs x inputs)
    for slot, wname, mname, outer, ishq in ((5, "wq", "m_q", sh.q_pad, True), (6, "wk", "m_k", sh.kvw, False),
                                            (7, "wv", "m_v", sh.kvw, False)):
        W = layer.arr(wname)
        if wname == "wq" and "wq_bump" in controls:
            W = W.copy()
            W[0, 0] = W[0, 0] + (1 if W[0, 0] < 127 else -1)
        eq = eq_table_msb(rj(slot, lg(outer)))
        mm = m[mname]
        check_coeff(mm, W)
        omap = sh.qmap if ishq else (lambda o: o)
        weighted = [(eq[omap(o)][0] * mm[o] % P, eq[omap(o)][1] * mm[o] % P) for o in range(W.shape[0])]
        out.append((f"fold({wname})", slot, pubs(slot)[0], fold_rows(W, weighted, sh.d_pad, lambda i: i)))
        del W
    W = layer.arr("wo")                                  # (d, qw): rows the model axis, columns the query axis
    eq = eq_table_msb(rj(10, lg(sh.d_pad)))
    check_coeff(m["m_o"], W)
    weighted = [(eq[o][0] * m["m_o"][o] % P, eq[o][1] * m["m_o"][o] % P) for o in range(W.shape[0])]
    out.append(("fold(wo)", 10, pubs(10)[0], fold_rows(W, weighted, sh.q_pad, sh.qmap)))
    del W
    # ---- the three FFN matmuls, Axis::Columns (inputs x outputs)
    for slot, wname, cs, outs, rows_pad in ((11, "wg_t", gfold, sh.f_pad, sh.d_pad),
                                            (12, "wu_t", m["m_u"], sh.f_pad, sh.d_pad),
                                            (13, "wd_t", m["m_d"], sh.d_pad, sh.f_pad)):
        W = layer.arr(wname)
        eq = eq_table_msb(rj(slot, lg(outs)))
        check_coeff(cs, W)
        weighted = [(eq[j][0] * cs[j] % P, eq[j][1] * cs[j] % P) for j in range(W.shape[1])]
        name = {"wg_t": "fold(w_g)", "wu_t": "fold(w_u)", "wd_t": "fold(w_d)"}[wname]
        out.append((name, slot, pubs(slot)[0], fold_cols(W, weighted, rows_pad)))
        del W
    out = [(n.replace("fold(wq)", "fold(w_q)").replace("fold(wk)", "fold(w_k)").replace("fold(wv)", "fold(w_v)")
            .replace("fold(wo)", "fold(w_o)"), s, i, v) for n, s, i, v in out]
    # ---- the gains on Dom::D (SC_DZC): the padded vectors, repeated per token
    p14 = pubs(14)
    for nth, gname in ((0, "gamma_a"), (1, "gamma_m")):
        n = args[14]["tables"][p14[nth]]["len"]
        g = np.zeros(sh.d_pad, dtype=np.int64)
        g[:sh.width] = layer.arr(gname).astype(np.int64)
        x = np.arange(n, dtype=np.int64)
        c0 = signed_mod(g[x % sh.d_pad])
        out.append((gname, 14, p14[nth], (c0, np.zeros(n, dtype=np.uint64))))
    # ---- RoPE on Dom::Q and Dom::Kv (argument.rs rope_tables_at)
    cos = layer.arr("rope_cos").astype(np.int64).reshape(-1)
    sin = layer.arr("rope_sin").astype(np.int64).reshape(-1)
    if "sin_sign_flip" in controls:
        sin = -sin
    half = sh.hd // 2
    for slot, dom, heads in ((15, "Q", sh.h_pad), (16, "Kv", sh.kv_heads)):
        pp = pubs(slot)
        n = args[slot]["tables"][pp[0]]["len"]
        x = np.arange(n, dtype=np.int64)
        i, sl, t = x % sh.hd, (x // sh.hd) % heads, x // (sh.hd * heads)
        live = (t < sh.tokens) & (x < sh.t_pad * heads * sh.hd)
        if dom == "Q":
            live &= np.array([sh.true_head(int(s)) for s in range(heads)])[sl]
        at = np.where(live, t * half + i % half, 0)
        cv = np.where(live, cos[at], 0)
        sv = np.where(live, np.where(i < half, -sin[at], sin[at]), 0)
        z = np.zeros(n, dtype=np.uint64)
        out.append((f"rope_cos@{dom}", slot, pp[0], (signed_mod(cv), z)))
        out.append((f"rope_sin@{dom}", slot, pp[1], (signed_mod(sv), z.copy())))
    # ---- the FFN group-id column on Dom::F (accuracy_act::group_column)
    pp = pubs(18)
    n = args[18]["tables"][pp[0]]["len"]
    gid = np.zeros(sh.f_pad, dtype=np.int64)
    gid[:sh.hidden] = np.array(acc["ids"], dtype=np.int64)
    x = np.arange(n, dtype=np.int64)
    t, j = x // sh.f_pad, x % sh.f_pad
    col = np.where(t < sh.tokens, gid[j], 0)
    out.append(("group_column", 18, pp[0], (signed_mod(col), np.zeros(n, dtype=np.uint64))))
    # ---- the TAB slot: exp (table_values_exp_at), ACT3 and its support (accuracy_act::table)
    pp = pubs(19)
    beta = tuple(int(v) for v in doc["logup_challenges"][0])
    gamma = tuple(int(v) for v in doc["logup_challenges"][1])
    g_exp = (gamma[0] * TAG_EXP % P, gamma[1] * TAG_EXP % P)
    g_act = (gamma[0] * TAG_ACT % P, gamma[1] * TAG_ACT % P)
    n = args[19]["tables"][pp[1]]["len"]
    e = [int(v) for v in layer.arr("exp")]
    ev = [fadd(fadd(k(x_ % 256), fmul(beta, k(e[x_ % 256]))), g_exp) for x_ in range(n)]
    out.append(("exp_values", 19, pp[1], (np.array([v[0] for v in ev], dtype=np.uint64),
                                          np.array([v[1] for v in ev], dtype=np.uint64))))
    beta2 = fmul(beta, beta)
    zero = fadd(k(2048), g_act)
    comp = [zero] * n
    supp = [0] * n
    entries = len(acc["scaled"]) * 4096
    if not (4096 <= entries <= 16384) or entries > n:
        raise ValueError("one to four ACT tables must fit one row")
    for gi, words in enumerate(acc["scaled"]):
        gt = fmul(beta2, k(gi))
        for gate, w in enumerate(words):
            comp[gi * 4096 + gate] = fadd(fadd(fadd(k(gate), fmul(beta, k(w))), gt), g_act)
            supp[gi * 4096 + gate] = 1
    out.append(("act3_values", 19, pp[2], (np.array([v[0] for v in comp], dtype=np.uint64),
                                           np.array([v[1] for v in comp], dtype=np.uint64))))
    out.append(("act_support", 19, pp[4], (np.array(supp, dtype=np.uint64), np.zeros(n, dtype=np.uint64))))
    return out


def compare(fd, doc, derived):
    rows = []
    for name, slot, ti, (c0, c1) in derived:
        rec = doc["arguments"][slot]["tables"][ti]
        vals = rec.get("values")
        b = to_bytes(c0, c1)
        mine = hashlib.sha256(b).hexdigest()
        row = {"table": name, "slot": slot, "table_index": ti, "len": int(len(c0)), "len_recorded": rec["len"],
               "sha256_derived": mine, "sha256_recorded": rec["sha256"], "digest_equal": mine == rec["sha256"]}
        if isinstance(vals, dict):
            if vals["elem"] == "fp2":
                cap = os.pread(fd, vals["bytes"], vals["offset"])
                row["bytes_equal"] = (len(cap) == len(b) and cap == b)
            else:
                cap = os.pread(fd, vals["bytes"], vals["offset"])
                c0b = np.asarray(c0, dtype="<u8").tobytes()
                row["bytes_equal"] = cap == c0b and not np.any(c1)
            row["array_key_equal"] = vals["array"] == mine
            row["store"] = {"offset": vals["offset"], "bytes": vals["bytes"], "elem": vals["elem"]}
            del cap
        else:
            row["bytes_equal"] = None
        row["equal"] = bool(row["digest_equal"] and row["bytes_equal"] and row["len"] == row["len_recorded"])
        rows.append(row)
    return rows


def stage_gate_from_line(line):
    m = re.search(r"R13 gate denominator (\d+)", line)
    p = re.search(r"product shift (\d+)", line)
    return (int(m.group(1)) if m else None), (int(p.group(1)) if p else None)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--capture", required=True)
    ap.add_argument("--export", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--blocks", default="")
    ap.add_argument("--controls", action="store_true")
    ap.add_argument("--skip-store-hash", action="store_true")
    a = ap.parse_args(argv)
    t0 = time.time()
    rec = {"what": "gate round 21: an independent gate-side derivation of the 17 public block-stage arrays from the "
                   "T128 export, compared byte for byte with the capture [MEASURED]; NOT a privacy result",
           "capture": a.capture, "export": a.export, "script_sha256": sha256_file(os.path.abspath(__file__)),
           "privacy_acceptance": False}
    # ---- the export, pinned
    prof_path = os.path.join(a.export, "profile.json")
    prof_sha = sha256_file(prof_path)
    prof = json.load(open(prof_path))
    rec["export_profile_sha256"] = prof_sha
    rec["export_profile_is_the_runs"] = prof_sha == EXPECTED_PROFILE_SHA
    # ---- the capture, pinned by its manifest
    man = json.load(open(os.path.join(a.capture, "manifest.json")))
    rec["capture_manifest_sha256"] = sha256_file(os.path.join(a.capture, "manifest.json"))
    files = {f["file"]: f for f in man["files"]}
    run = json.load(open(os.path.join(a.capture, "run.json")))
    rec["run_json_sha256_ok"] = sha256_file(os.path.join(a.capture, "run.json")) == files["run.json"]["sha256"]
    store = os.path.join(a.capture, "arrays.bin")
    if not a.skip_store_hash:
        ts = time.time()
        rec["arrays_bin_sha256_ok"] = sha256_file(store) == files["arrays.bin"]["sha256"]
        rec["arrays_bin_hash_s"] = round(time.time() - ts, 1)
    sh = Shape(run["shape"])
    L = run["blocks"]
    lines = run["stage_lines"]
    layers = sorted(prof["layers"], key=lambda e: e["layer"])
    want = [int(x) for x in a.blocks.split(",") if x] or list(range(1, L + 1))
    rec["blocks_evaluated"] = want
    rec["mem_start"] = mem()
    fd = os.open(store, os.O_RDONLY)
    rec["stages"] = []
    all_ok = True
    for s in want:
        ts = time.time()
        sf = f"stage-{s:02d}.json"
        stage_ok = sha256_file(os.path.join(a.capture, sf)) == files[sf]["sha256"]
        doc = json.load(open(os.path.join(a.capture, sf)))
        if doc["stage_kind"] != "BLOCK" or doc["stage"] != s:
            raise ValueError(f"{sf} is not block stage {s}")
        layer = Layer(a.export, layers[s - 1])
        acc = accuracy_public(layer, sh)
        g_line, h_line = stage_gate_from_line(lines[s])
        derived = derive_stage(doc, layer, sh, acc)
        rows = compare(fd, doc, derived)
        ok = stage_ok and all(r["equal"] for r in rows) and not acc["findings"] and acc["G"] == g_line \
            and (h_line is None or h_line == acc["sh_h"])
        all_ok &= ok
        rec["stages"].append({
            "stage": s, "layer": layer.index, "stage_file_sha256_ok": stage_ok,
            "layer_manifest_sha256": layer.manifest_sha256, "layer_arrays_sha256_checked": len(layer.verified),
            "G_derived": acc["G"], "G_stage_line": g_line, "sh_h_layer": acc["sh_h"], "product_shift_stage_line": h_line,
            "groups": acc["groups"], "base_member": acc["base"], "silu": acc["silu"], "findings": acc["findings"],
            "tables": rows, "equal": sum(r["equal"] for r in rows), "of": len(rows),
            "entries": sum(r["len"] for r in rows), "ok": ok, "seconds": round(time.time() - ts, 2), "mem": mem()})
        print(f"stage {s:2d} layer {layer.index:2d}: {sum(r['equal'] for r in rows)}/{len(rows)} equal, G {acc['G']} "
              f"(line {g_line}), groups {len(acc['groups'])}, ok {ok}, {time.time() - ts:.1f}s, {mem()}", flush=True)
        if a.controls and s == want[0]:
            rec["controls"] = run_controls(fd, doc, a.export, layers, s, sh, rows)
        del derived, doc
    os.close(fd)
    # the exp words against their generator, once per distinct (e_s, f_e)
    exps = {}
    for s in want:
        lay = Layer(a.export, layers[s - 1], verify=False)
        key = (lay.c["exp_e_s"], lay.c["f_e"])
        if key not in exps:
            exported = [int(v) for v in lay.arr("exp")]
            f64 = exp_float64(key[0], sh.hd, key[1])
            ex, margin = exp_exact(key[0], sh.hd, key[1])
            exps[key] = {"e_s": key[0], "f_e": key[1], "layers": [], "export_equals_float64_generator": exported == f64,
                         "export_equals_exact": exported == ex, "closest_approach_to_a_rounding_tie": margin}
        exps[key]["layers"].append(lay.index)
    rec["exp_generators"] = list(exps.values())
    all_ok &= all(v["export_equals_float64_generator"] and v["export_equals_exact"] for v in exps.values())
    rec["summary"] = {
        "stages": len(rec["stages"]), "stages_ok": sum(st["ok"] for st in rec["stages"]),
        "arrays_equal": sum(st["equal"] for st in rec["stages"]), "arrays": sum(st["of"] for st in rec["stages"]),
        "entries_compared": sum(st["entries"] for st in rec["stages"]),
        "G_all_equal_stage_lines": all(st["G_derived"] == st["G_stage_line"] for st in rec["stages"]),
        "silu_members_checked": sorted({tuple(x["member"]) for st in rec["stages"] for x in st["silu"]}),
        "controls_fired": (all(c["fired"] for c in rec["controls"].values()) if "controls" in rec else None),
        "all_ok": bool(all_ok and rec["export_profile_is_the_runs"] and rec["run_json_sha256_ok"]
                       and rec.get("arrays_bin_sha256_ok", True)),
        "seconds": round(time.time() - t0, 1), "mem_end": mem()}
    with open(a.out, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
        fh.write("\n")
    print(json.dumps(rec["summary"], default=str))
    return 0 if rec["summary"]["all_ok"] and rec["summary"]["controls_fired"] in (None, True) else 1


def run_controls(fd, doc, export, layers, s, sh, honest_rows):
    """non-vacuity: each perturbation must break exactly the tables it touches"""
    honest = {r["table"] for r in honest_rows if r["equal"]}
    out = {}

    def differing(layer, acc, controls):
        rows = compare(fd, doc, derive_stage(doc, layer, sh, acc, controls))
        return sorted(r["table"] for r in rows if not r["equal"])

    lay = Layer(export, layers[s - 1], verify=False)
    acc = accuracy_public(lay, sh)
    folds = ["fold(w_d)", "fold(w_g)", "fold(w_k)", "fold(w_o)", "fold(w_q)", "fold(w_u)", "fold(w_v)"]
    cases = [
        ("C21-1 one weight of w_q moved by 1", dict(wq_bump=1), ["fold(w_q)"]),
        ("C21-2 one q multiplier + 1", dict(m_q_bump=1), ["fold(w_q)"]),
        ("C21-3 one folded gate coefficient + one unit", dict(m_g_bump=1), ["fold(w_g)"]),
        ("C21-4 fold(w_v) at slot 6's challenge point", dict(rj_from=(6, 7)), ["fold(w_v)"]),
        ("C21-5 the RoPE sin sign convention flipped", dict(sin_sign_flip=1), ["rope_sin@Kv", "rope_sin@Q"]),
    ]
    for label, controls, expect in cases:
        got = differing(lay, acc, controls)
        out[label] = {"differing": got, "expected": expect, "fired": got == expect}
    acc_raw = accuracy_public(lay, sh, {"raw_bump": 1})
    got = differing(lay, acc_raw, {})
    out["C21-6 one raw SiLU word of group 0 + 1"] = {"differing": got, "expected": ["act3_values"],
                                                      "fired": got == ["act3_values"]}
    acc_g = accuracy_public(lay, sh, {"G": acc["G"] + 1})
    got = differing(lay, acc_g, {})
    out["C21-7 G_k + 1 (the gate fold's common denominator)"] = {"differing": got, "expected": ["fold(w_g)"],
                                                                 "fired": got == ["fold(w_g)"]}
    other = s if s < len(layers) else s - 2
    lay2 = Layer(export, layers[other], verify=False)
    acc2 = accuracy_public(lay2, sh)
    got = differing(lay2, acc2, {})
    out[f"C21-8 the next layer's export ({layers[other]['layer']}) for stage {s}"] = {
        "differing": got, "expected_at_least": folds + ["gamma_a", "gamma_m"],
        "fired": set(folds + ["gamma_a", "gamma_m"]) <= set(got)}
    out["_honest_equal"] = sorted(honest)
    out = {kk: v for kk, v in out.items()}
    out.pop("_honest_equal")
    return out


if __name__ == "__main__":
    sys.exit(main())
