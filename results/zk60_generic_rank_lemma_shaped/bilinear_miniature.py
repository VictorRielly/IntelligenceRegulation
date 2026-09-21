#!/usr/bin/env python3
"""A FAITHFUL MINIATURE of the repaired bilinear attention slots, with TWO
key-value group bits, and the generic-rank objects computed on it exactly.

WHY A MINIATURE, AND WHAT IS SCALED DOWN.  The question the memo has to
answer is whether the two claims of a repaired bilinear slot — two claims on
two planes of the SAME commitment `A`, raised at evaluation points that SHARE
the summed group coordinates `rho_g` (and, in `SC_PV`, the source-token
coordinates too) — are still linearly independent of each other and of every
other claim on `A`, for generic challenges.  That question is about the
CLAIM-FUNCTIONAL matrix and about the commitment's non-data block.  Neither
depends on the size of a domain: it depends on the coordinate lists, on which
challenge sits where, on the reserved-pair schedule and on the column-weight
keys.  So the miniature keeps ALL of those exactly as `argument.rs:1126-1187`
writes them and shrinks only the axis lengths.

  SCALED DOWN : tokens, head dimension, row width `n`, pad count `Q`, the
                number of opened columns, the number of planes and claims.
  NOT SCALED  : `lkv = 2` key-value group bits (the 125M value); the four
                coordinate lists, axis by axis; `Coord::Rho` vs
                `Coord::Fixed` at every position; the two extension rounds
                and which factor each masks; `build_claim`'s
                `(cd, cm, cm*U)` shape; `zpart_weights`' two branches;
                first-occurrence grouping by column-weight key; `zk_rhos`'
                draw order; the Goldilocks field and `Fp2 = Fp[U]/(U^2-7)`.

WHAT IS COMPUTED.
  1. the four claims' row weights and column-weight keys, and the grouping;
  2. `k0 = rank(gens) - rank(gens | non-data rows)` — the tool's quantity;
  3. the factorised determinant `prod Norm(lambda*cm) * wedge(prox pair)`
     against the direct determinant of the chosen minor;
  4. a BRUTE-FORCE disclosed dimension over the whole linear view (claim
     values, every group vector, the proximity vector, the opened columns),
     with no reduction at all:
         disclosed = rank(view) - rank(view restricted to the coordinates
                                       outside the hidden data rectangle);
  5. the same with a publicly-known-zero sub-rectangle (grouped heads with
     padded head slots);
  6. controls, including the PRE-REPAIR schedule.

NOTHING HERE IS A PRIVACY CLAIM.  It is exact linear algebra on a model.
"""
from __future__ import annotations
import json, os, random, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fieldlib import (P, ONE, ZERO, U, f2add, f2sub, f2mul, f2neg, norm, wedge,
                      rand_f2, eq_table_msb, rank_fp, rank_split, det_fp)

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- geometry
LT = 1      # log2 tokens
LKV = 2     # log2 key-value heads  == the 125M value; the WHOLE point
LHJ = 1     # log2 query heads within a group
LDH = 1     # log2 head dimension
LH = LKV + LHJ
LOG_N = 3   # log2 of the commitment's row width
N = 1 << LOG_N
QPAD = 8    # the pad count == the number of opened columns (condition O-3)
NCOL = 4    # distinct opened columns actually used in the brute force
INV_RATE = 4
NN = N * INV_RATE

LOG_Q = LT + LH + LDH      # Dom::Q  = (t, head slot, c)
LOG_KV = LT + LKV + LDH    # Dom::Kv = (j, group, c)
LOG_S = LH + LT + LT       # Dom::S  = (head slot, t, s)

PLANES = [("A_QR8", LOG_Q), ("A_KR8", LOG_KV), ("A_P", LOG_S), ("A_V8", LOG_KV)]


def layout():
    """A row-aligned plane cursor, as `layout.rs`' `a_off` is."""
    off, rows_of, offs = 0, {}, {}
    for name, lg in PLANES:
        offs[name] = off
        rows_of[name] = (1 << lg) // N
        off += (1 << lg)
    data_rows = off // N
    return offs, rows_of, data_rows


OFFS, PROWS, DATA_ROWS = layout()
N_CLAIMS = 4
MASK_BASE = DATA_ROWS
PROX = MASK_BASE + 2 * N_CLAIMS
ROWS = PROX + 2


# ---------------------------------------------------- zkp-core/src/pcs.rs
def zpart_weights(offset, log_size, coef, point, rows=ROWS, log_cols=LOG_N):
    """Port of `zkp-core/src/pcs.rs:860-900`, including the four asserts at
    `:867, 876, 883, 894` that make `part_rows` exact."""
    n = 1 << log_cols
    row_w = [ZERO] * rows
    ls = log_size
    if not point:
        if ls >= log_cols:
            assert offset % n == 0                      # pcs.rs:867
            r0 = offset // n
            for i in range(1 << (ls - log_cols)):
                row_w[r0 + i] = f2add(row_w[r0 + i], coef)
            key = ((), 0, n)
        else:
            r0, c0 = offset // n, offset % n
            assert c0 + (1 << ls) <= n                  # pcs.rs:876
            row_w[r0] = f2add(row_w[r0], coef)
            key = ((), c0, 1 << ls)
    else:
        assert len(point) == ls                         # pcs.rs:881
        if ls >= log_cols:
            assert offset % n == 0                      # pcs.rs:883
            lr = ls - log_cols
            r0 = offset // n
            for i, e in enumerate(eq_table_msb(point[:lr])):
                row_w[r0 + i] = f2add(row_w[r0 + i], f2mul(coef, e))
            key = (tuple(point[lr:]), 0, n)
        else:
            r0, c0 = offset // n, offset % n
            assert c0 + (1 << ls) <= n                  # pcs.rs:894
            row_w[r0] = f2add(row_w[r0], coef)
            key = (tuple(point), c0, 1 << ls)
    return row_w, key


def zkey_weights(key, log_cols=LOG_N):
    """`pcs.rs:902-915`."""
    n = 1 << log_cols
    col_w = [ZERO] * n
    tail, c0, ln = key
    if not tail:
        for c in range(c0, c0 + ln):
            col_w[c] = ONE
    else:
        eq_c = eq_table_msb(list(tail))
        for i in range(ln):
            col_w[c0 + i] = eq_c[i]
    return col_w


def claim_weights(claim, rows=ROWS, log_cols=LOG_N):
    """A claim is a list of parts; every part must share one column key
    (`pcs.rs:925`).  Returns (row weights, key)."""
    rw, key = zpart_weights(*claim[0], rows=rows, log_cols=log_cols)
    for p in claim[1:]:
        rw2, key2 = zpart_weights(*p, rows=rows, log_cols=log_cols)
        assert key2 == key, "zk claim: parts with different column weights"
        rw = [f2add(a, b) for a, b in zip(rw, rw2)]
    return rw, key


def group_zclaims(claims, rows=ROWS, log_cols=LOG_N):
    """`pcs.rs:917-941`: first-occurrence grouping by column key."""
    keys, groups = [], []
    for c in claims:
        rw, key = claim_weights(c, rows, log_cols)
        if key in keys:
            groups[keys.index(key)][1].append(rw)
        else:
            keys.append(key)
            groups.append((zkey_weights(key, log_cols), [rw]))
    return groups


# ---------------------------------------------- hashline/.../argument.rs
def build_claim(offset, log, point, cd, cm, mask_row, log_cols=LOG_N):
    """`argument.rs:264-278`: one data part then the reserved pair, the pair
    at `(cm, cm*U)` over `logm = min(log, log_cols)` coordinates."""
    n = 1 << log_cols
    logm = min(log, log_cols)
    c0 = offset % n if log < log_cols else 0
    tail = point[log - logm:]
    parts = [(offset, log, cd, list(point))]
    for k, u in enumerate([ONE, U]):
        parts.append(((mask_row + k) * n + c0, logm, f2mul(cm, u), list(tail)))
    return parts


def coords_score(rg_is_rho: bool):
    """`argument.rs:1126-1160` (SC_SCORE).  Returns, for each of the two
    private factors, a coordinate list as a list of ('rho', k) / ('fix', tag)
    entries, in the order the Rust writes them.

    `rg_is_rho=False` is the PRE-REPAIR schedule of finding S19-F1: the group
    bits were FIXED coordinates `r_h[..lkv]` of both factors instead of
    shared summed variables.  Kept as a control.
    """
    rg = [("rho", k) for k in range(LKV)] if rg_is_rho else \
         [("fix", ("r_h", k)) for k in range(LKV)]
    off = LKV if rg_is_rho else 0
    r_hj = [("fix", ("r_h", LKV + k)) for k in range(LHJ)]
    r_t = [("fix", ("r_t", k)) for k in range(LT)]
    r_j = [("fix", ("r_j", k)) for k in range(LT)]
    tq = [("rho", off + k) for k in range(LDH)]
    tk = [("rho", off + k) for k in range(LDH)]
    cq = r_t + rg + r_hj + tq          # A_QR8 on Dom::Q
    ck = r_j + rg + tk                 # A_KR8 on Dom::Kv
    return [("A_QR8", cq, 0), ("A_KR8", ck, 1)], (LKV if rg_is_rho else 0) + LDH


def coords_pv(rg_is_rho: bool):
    """`argument.rs:1162-1187` (SC_PV)."""
    rg = [("rho", k) for k in range(LKV)] if rg_is_rho else \
         [("fix", ("r_h", k)) for k in range(LKV)]
    off = LKV if rg_is_rho else 0
    r_hj = [("fix", ("r_h", LKV + k)) for k in range(LHJ)]
    r_t = [("fix", ("r_t", k)) for k in range(LT)]
    r_i = [("fix", ("r_i", k)) for k in range(LDH)]
    tp = [("rho", off + k) for k in range(LT)]
    cp = rg + r_hj + r_t + tp          # A_P on Dom::S
    cv = tp + rg + r_i                 # A_V8 on Dom::Kv
    return [("A_P", cp, 0), ("A_V8", cv, 1)], (LKV if rg_is_rho else 0) + LT


def instantiate(rng, repaired=True, force_same_key=False, share_pair=False,
                zero_cm=None, zero_lambda_group=None, dependent_prox=False,
                same_fixed=False, boolean_rho_g=False):
    """Draw one generic instance and build every object of the lemma."""
    fixed = {}
    for tag, ln in (("r_h", LH), ("r_t", LT), ("r_j", LT), ("r_i", LDH)):
        for k in range(ln):
            fixed[(tag, k)] = rand_f2(rng)
    fixed2 = dict(fixed) if same_fixed else {}
    if not same_fixed:
        for tag, ln in (("r_h", LH), ("r_t", LT), ("r_j", LT), ("r_i", LDH)):
            for k in range(ln):
                fixed2[(tag, k)] = rand_f2(rng)

    slots = []
    for which, (lists, nmain) in enumerate(
            (coords_score(repaired), coords_pv(repaired))):
        rho = [rand_f2(rng) for _ in range(nmain)]
        if boolean_rho_g and repaired:
            for k in range(LKV):
                rho[k] = (rng.randrange(2), 0)
        e = [rand_f2(rng) for _ in range(2)]          # two extension rounds
        slots.append((lists, rho, e, fixed if which == 0 else fixed2))

    claims, meta = [], []
    site = 0
    for (lists, rho, e, fx) in slots:
        # `argument.rs:407` cd = prod (1 - e_k)
        cd = ONE
        for x in e:
            cd = f2mul(cd, f2sub(ONE, x))
        for (plane, coords, ext_round) in lists:
            # `argument.rs:411` cm = e[r] * prod_{k>r} (1 - e_k)
            cm = e[ext_round]
            for x in e[ext_round + 1:]:
                cm = f2mul(cm, f2sub(ONE, x))
            if zero_cm is not None and site == zero_cm:
                cm = ZERO
            point = []
            for kind, v in coords:
                point.append(rho[v] if kind == "rho" else fx[v])
            log = dict(PLANES)[plane]
            mask_row = MASK_BASE + 2 * site
            if share_pair and site == 1:
                mask_row = MASK_BASE          # the forbidden shared pair
            claims.append(build_claim(OFFS[plane], log, point, cd, cm, mask_row))
            meta.append(dict(plane=plane, site=site, cm=cm, cd=cd,
                             ext_round=ext_round, point=point, mask_row=mask_row))
            site += 1

    if force_same_key:
        # make claims 0 and 1 share a column key by giving claim 1 claim 0's
        # tail; a control, not a thing the code can do
        rw0, key0 = claim_weights(claims[0])
        pl, log = "A_KR8", LOG_KV
        tail = list(key0[0])
        pt = [rand_f2(rng) for _ in range(log - len(tail))] + tail
        claims[1] = build_claim(OFFS[pl], log, pt, meta[1]["cd"], meta[1]["cm"],
                                meta[1]["mask_row"])
        meta[1]["point"] = pt

    groups = group_zclaims(claims)
    # `pcs.rs:943-966` zk_rhos: lambdas per group in first-occurrence order,
    # then `rows` proximity draws
    lambdas, rhos = [], []
    for gi, (cw, members) in enumerate(groups):
        lam = [rand_f2(rng) for _ in members]
        if zero_lambda_group == gi:
            lam = [ZERO] * len(members)
        lambdas.append(lam)
        rho_g = [ZERO] * ROWS
        for rw, l in zip(members, lam):
            for i in range(ROWS):
                if rw[i] != ZERO:
                    rho_g[i] = f2add(rho_g[i], f2mul(l, rw[i]))
        rhos.append(rho_g)
    prox = [rand_f2(rng) for _ in range(ROWS)]
    if dependent_prox:
        prox[PROX + 1] = f2mul(prox[PROX], (rng.randrange(P), 0))
    rhos.append(prox)
    return dict(claims=claims, meta=meta, groups=groups, lambdas=lambdas,
                rhos=rhos, prox=prox)


# -------------------------------------------------------------- the view
def realify(vec_f2):
    return [x[0] for x in vec_f2], [x[1] for x in vec_f2]


def generators(inst):
    g = []
    for v in inst["rhos"]:
        re, im = realify(v)
        g.append(re)
        g.append(im)
    return g


def k0_of(inst):
    g = generators(inst)
    nd = list(range(MASK_BASE, ROWS))
    full = rank_fp(g)
    on_nd = rank_fp([[r[i] for i in nd] for r in g])
    return full, on_nd, full - on_nd, len(g)


def factorised_minor(inst):
    """Choose one member claim per group plus the proximity pair, order the
    generator rows Re/Im per group then Re/Im of prox, and compare the direct
    determinant with `prod Norm(lambda*cm) * wedge(prox pair)`."""
    cols, factors = [], []
    used = set()
    for gi, (cw, members) in enumerate(inst["groups"]):
        # the first member of the group, by first-occurrence order
        for ci, c in enumerate(inst["claims"]):
            rw, key = claim_weights(c)
            if key == _key_of(inst, gi) and ci not in used:
                used.add(ci)
                m = inst["meta"][ci]
                cols += [m["mask_row"], m["mask_row"] + 1]
                lam = inst["lambdas"][gi][members.index(rw)] \
                    if rw in members else inst["lambdas"][gi][0]
                factors.append(f2mul(lam, m["cm"]))
                break
    cols += [PROX, PROX + 1]
    g = generators(inst)
    sub = [[r[c] for c in cols] for r in g]
    if len(sub) != len(cols):
        return None
    direct = det_fp(sub)
    pred = 1
    for f in factors:
        pred = (pred * norm(f)) % P
    pred = (pred * wedge(inst["prox"][PROX], inst["prox"][PROX + 1])) % P
    return direct, pred, cols


def _key_of(inst, gi):
    seen = []
    for c in inst["claims"]:
        _, key = claim_weights(c)
        if key not in seen:
            seen.append(key)
    return seen[gi]


# -------------------------------------------- the column functionals E_j
def two_adic_root(k):
    g = 7
    return pow(g, (P - 1) >> k, P)


def column_functionals(ncol, seed):
    """`zkp-core/src/pcs.rs::encode_row_zk` in closed form:
       E_j[msg s] = (x^n - 1) / (n (x w_n^{-s} - 1)),  E_j[pad k] = (x^n-1) x^k,
       x_j = 7 * w_nn^j."""
    w_nn = two_adic_root(NN.bit_length() - 1)
    w_n = pow(w_nn, INV_RATE, P)
    rng = random.Random(seed)
    idx = sorted(rng.sample(range(NN), ncol))
    out = []
    ninv = pow(N, P - 2, P)
    for j in idx:
        x = (7 * pow(w_nn, j, P)) % P
        zx = (pow(x, N, P) - 1) % P
        assert zx != 0, "Z_n(x_j) = 0 — the coset meets the subgroup"
        row = []
        for s in range(N):
            den = (x * pow(w_n, (N - s) % N, P) - 1) % P
            assert den != 0
            row.append((zx * ninv % P) * pow(den, P - 2, P) % P)
        xk = 1
        for _ in range(QPAD):
            row.append(zx * xk % P)
            xk = xk * x % P
        out.append(row)
    return idx, out


def brute_force_disclosed(inst, cols, hidden_rows=None, hidden_msg=None):
    """No reduction: build every Fp functional of the verifier's linear view
    and split the coordinates into (observed-but-not-hidden | hidden).

    Coordinates are X[i][t], i over `ROWS`, t over `N` message positions then
    `QPAD` pad positions.  The hidden rectangle is `hidden_rows` x
    `hidden_msg` (default: all data rows, all message positions).
    """
    W = N + QPAD
    hidden_rows = list(range(DATA_ROWS)) if hidden_rows is None else hidden_rows
    hidden_msg = list(range(N)) if hidden_msg is None else hidden_msg
    hidden = {(i, t) for i in hidden_rows for t in hidden_msg}
    order = [(i, t) for i in range(ROWS) for t in range(W) if (i, t) not in hidden]
    n_first = len(order)
    order += [(i, t) for i in range(ROWS) for t in range(W) if (i, t) in hidden]
    pos = {c: k for k, c in enumerate(order)}
    ncoord = len(order)

    funcs = []
    # (a) the individual claim values:  value = sum_{i,s} rw[i] cw[s] X[i][s]
    for c in inst["claims"]:
        rw, key = claim_weights(c)
        cw = zkey_weights(key)
        re = [0] * ncoord
        im = [0] * ncoord
        for i in range(ROWS):
            if rw[i] == ZERO:
                continue
            for s in range(N):
                if cw[s] == ZERO:
                    continue
                co = f2mul(rw[i], cw[s])
                re[pos[(i, s)]] = (re[pos[(i, s)]] + co[0]) % P
                im[pos[(i, s)]] = (im[pos[(i, s)]] + co[1]) % P
        funcs.append(re)
        funcs.append(im)
    # (b)(c) every group vector and the proximity vector, in full
    for v in inst["rhos"]:
        for t in range(W):
            re = [0] * ncoord
            im = [0] * ncoord
            for i in range(ROWS):
                if v[i] == ZERO:
                    continue
                re[pos[(i, t)]] = v[i][0]
                im[pos[(i, t)]] = v[i][1]
            funcs.append(re)
            funcs.append(im)
    # (d) each opened column, one Fp value per row
    for ej in cols:
        for i in range(ROWS):
            f = [0] * ncoord
            for t in range(W):
                f[pos[(i, t)]] = ej[t]
            funcs.append(f)
    rf, ra = rank_split(funcs, n_first)
    return dict(functionals=len(funcs), coordinates=ncoord,
                hidden=len(hidden), rank_observed_block=rf, rank_all=ra,
                disclosed=ra - rf)


# ------------------------------------------------------------------ main
def main():
    global QPAD
    t0 = time.time()
    rep = []
    w = rep.append
    w("A FAITHFUL MINIATURE OF THE REPAIRED BILINEAR SLOTS (lkv = 2)")
    w("field: Goldilocks p = 2^64 - 2^32 + 1, Fp2 = Fp[U]/(U^2 - 7)")
    w(f"geometry: lt={LT} lkv={LKV} lhj={LHJ} ldh={LDH} -> "
      f"log(Dom::Q)={LOG_Q} log(Dom::Kv)={LOG_KV} log(Dom::S)={LOG_S}; "
      f"row width n={N}, pads Q={QPAD}, inv_rate={INV_RATE}")
    w(f"commitment: {DATA_ROWS} data rows, {N_CLAIMS} reserved pairs at "
      f"{MASK_BASE}..{PROX-1}, proximity pair ({PROX},{PROX+1}), "
      f"{ROWS} rows in all")
    w("")
    w("A. THE CLAIM SCHEDULE AND ITS GROUPING, ten seeds")
    w("-" * 74)
    hdr = (f"  {'seed':>5}{'claims':>8}{'groups':>8}{'gens':>6}"
           f"{'rank(gens)':>12}{'on non-data':>13}{'k0':>5}"
           f"{'det == product':>16}")
    w(hdr)
    summary = {"k0": set(), "groups": set(), "det_ok": True}
    for seed in range(10):
        rng = random.Random(1000 + seed)
        inst = instantiate(rng)
        full, nd, k0, ng = k0_of(inst)
        fm = factorised_minor(inst)
        ok = fm is not None and fm[0] == fm[1] and fm[0] != 0
        summary["k0"].add(k0)
        summary["groups"].add(len(inst["groups"]))
        summary["det_ok"] &= ok
        w(f"  {seed:>5}{len(inst['claims']):>8}{len(inst['groups']):>8}"
          f"{ng:>6}{full:>12}{nd:>13}{k0:>5}{('yes' if ok else 'NO'):>16}")
    w(f"  -> groups {sorted(summary['groups'])}, k0 {sorted(summary['k0'])}, "
      f"factorisation exact on all ten: {summary['det_ok']}")
    w("")

    w("B. ARE THE TWO SHARED-COORDINATE CLAIMS IN DIFFERENT OPENING GROUPS?")
    w("-" * 74)
    rng = random.Random(4242)
    inst = instantiate(rng)
    keys = []
    for ci, c in enumerate(inst["claims"]):
        rw, key = claim_weights(c)
        keys.append(key)
        m = inst["meta"][ci]
        nz = [i for i in range(ROWS) if rw[i] != ZERO]
        ndz = [i for i in nz if i >= MASK_BASE]
        w(f"  claim {ci} {m['plane']:<6} ext_round {m['ext_round']}  pair "
          f"({m['mask_row']},{m['mask_row']+1})  nonzero rows {len(nz)} "
          f"(non-data: {ndz})  key tail len {len(key[0])} c0 {key[1]} len {key[2]}")
    w(f"  distinct keys: {len({str(k) for k in keys})} of {len(keys)}  -> "
      f"{len(inst['groups'])} opening groups")
    w("  the shared coordinates: SC_SCORE's two factors both carry rho(0..2) "
      "(the group bits);")
    w("  SC_PV's two factors both carry rho(0..2) AND rho(2..3) (the source "
      "tokens).")
    w("  Every claim's weights on the non-data rows sit on its OWN pair and "
      "nowhere else,")
    w("  which is what makes the shared point invisible to the non-data "
      "block.")
    w("")

    w("C. ADVERSARIAL CHALLENGE REGIMES (the shared coordinates driven to "
      "collide)")
    w("-" * 74)
    regimes = []
    for name, mk in (
        ("uniform", lambda r: instantiate(r)),
        ("both slots drawing the SAME fixed challenges",
         lambda r: instantiate(r, same_fixed=True)),
        ("the group coordinates rho_g driven to BOOLEAN values",
         lambda r: instantiate(r, boolean_rho_g=True)),
        ("pre-repair schedule (group bits FIXED in both factors)",
         lambda r: instantiate(r, repaired=False)),
        ("the two bilinear claims forced into ONE opening group",
         lambda r: instantiate(r, force_same_key=True)),
        ("one cm = 0 (the zero-mask-challenge refusal disabled)",
         lambda r: instantiate(r, zero_cm=0)),
        ("one group's lambdas all 0",
         lambda r: instantiate(r, zero_lambda_group=0)),
        ("the proximity pair Fp-dependent",
         lambda r: instantiate(r, dependent_prox=True)),
        ("two claims SHARING one reserved pair (audit_claims forbids)",
         lambda r: instantiate(r, share_pair=True)),
    ):
        ks, gs = set(), set()
        for seed in range(5):
            i2 = mk(random.Random(7000 + seed))
            full, nd, k0, ng = k0_of(i2)
            ks.add(k0)
            gs.add(len(i2["groups"]))
        regimes.append((name, sorted(gs), sorted(ks)))
        w(f"  {name}")
        w(f"      groups {sorted(gs)}   k0 {sorted(ks)}")
    w("")

    w("D. BRUTE FORCE: the disclosed dimension of the WHOLE linear view")
    w("-" * 74)
    w("   no reduction; disclosed = rank(view) - rank(view on the "
      "coordinates outside")
    w("   the hidden data rectangle).  Coordinates: "
      f"{ROWS} rows x ({N} message + {QPAD} pad).")
    idx, cols = column_functionals(NCOL, 99)
    w(f"   opened columns: {idx} (distinct {len(set(idx))} <= Q = {QPAD})")
    bf_rows = []
    for seed in range(3):
        rng = random.Random(2000 + seed)
        inst = instantiate(rng)
        r = brute_force_disclosed(inst, cols)
        bf_rows.append(r)
        w(f"   seed {seed}: {r['functionals']} functionals, "
          f"{r['coordinates']} coordinates, hidden {r['hidden']}, "
          f"rank(observed block) {r['rank_observed_block']}, "
          f"rank(all) {r['rank_all']}  ->  DISCLOSED {r['disclosed']}")
    w("   control: the same view with ONE reserved pair shared by two claims")
    rng = random.Random(2000)
    inst = instantiate(rng, share_pair=True)
    rc = brute_force_disclosed(inst, cols)
    w(f"     -> DISCLOSED {rc['disclosed']}  "
      f"(rank(all) {rc['rank_all']}, observed block {rc['rank_observed_block']})")
    w("   control: the same view with one cm = 0")
    rng = random.Random(2000)
    inst = instantiate(rng, zero_cm=0)
    rz = brute_force_disclosed(inst, cols)
    w(f"     -> DISCLOSED {rz['disclosed']}")
    w("   control: the same view with an Fp-DEPENDENT proximity pair")
    rng = random.Random(2000)
    inst = instantiate(rng, dependent_prox=True)
    rd = brute_force_disclosed(inst, cols)
    w(f"     -> DISCLOSED {rd['disclosed']}")
    w("   control: the two bilinear claims forced into ONE opening group "
      "(a 2-member group)")
    rng = random.Random(2000)
    inst = instantiate(rng, force_same_key=True)
    rg = brute_force_disclosed(inst, cols)
    w(f"     -> DISCLOSED {rg['disclosed']}  (groups "
      f"{len(inst['groups'])}, so Step 7's per-group argument is exercised "
      "at m = 2)")
    w("   control: one opened column MORE than the pad budget "
      f"({QPAD+1} distinct columns against {QPAD} pads)")
    idx2, cols2 = column_functionals(QPAD + 1, 31)
    rng = random.Random(2000)
    inst = instantiate(rng)
    rp = brute_force_disclosed(inst, cols2)
    w(f"     -> DISCLOSED {rp['disclosed']}  (H-pad broken: "
      f"{len(set(idx2))} distinct columns)")
    w("")
    w("D'. THE SAME BRUTE FORCE AT n != Q — the shaped case the toy could "
      "not show")
    w("-" * 74)
    w("   at the toy n = Q = 256 and the two halves of a published vector "
      "have equal")
    w("   length; at rung-G n = 1,024 and at 125M n = 16,384, against "
      "Q = 256 either way.")
    keep = QPAD
    for q, d in ((4, 4), (4, 3), (2, 2)):
        QPAD = q
        idx3, cols3 = column_functionals(d, 55)
        for seed in range(2):
            inst = instantiate(random.Random(3000 + seed))
            r = brute_force_disclosed(inst, cols3)
            w(f"   n = {N}, Q = {q}, {len(set(idx3))} distinct opened "
              f"columns, seed {seed}: {r['functionals']} functionals, "
              f"{r['coordinates']} coordinates  ->  DISCLOSED "
              f"{r['disclosed']}")
        # and the budget control at this Q
        idx4, cols4 = column_functionals(q + 1, 57)
        inst = instantiate(random.Random(3000))
        rb = brute_force_disclosed(inst, cols4)
        w(f"   n = {N}, Q = {q}, {len(set(idx4))} distinct columns (one OVER "
          f"the budget)  ->  DISCLOSED {rb['disclosed']}")
    QPAD = keep
    w("")

    w("E. GROUPED HEADS: a plane that is PUBLICLY ZERO on its padded slots")
    w("-" * 74)
    w("   the hidden rectangle shrinks to the SUPPORTED positions; the view "
      "is unchanged.")
    # A_QR8 occupies rows 0..3.  Under the head permutation the padded head
    # slots are the last `slots_per_kv_group - q_heads/kv_heads` of each
    # group's block; in this miniature take half of each row publicly zero.
    hidden_rows = list(range(DATA_ROWS))
    hidden_msg = list(range(N // 2))            # half of every row is public 0
    rng = random.Random(2000)
    inst = instantiate(rng)
    rfull = brute_force_disclosed(inst, cols)
    rsub = brute_force_disclosed(inst, cols, hidden_rows, hidden_msg)
    w(f"   hidden = the whole data rectangle : {rfull['hidden']} coordinates,"
      f" DISCLOSED {rfull['disclosed']}")
    w(f"   hidden = the SUPPORTED positions  : {rsub['hidden']} coordinates,"
      f" DISCLOSED {rsub['disclosed']}")
    w("   control: with one shared reserved pair the two figures SEPARATE,")
    inst = instantiate(random.Random(2000), share_pair=True)
    cfull = brute_force_disclosed(inst, cols)
    csub = brute_force_disclosed(inst, cols, hidden_rows, hidden_msg)
    w(f"     whole rectangle {cfull['disclosed']}, supported positions "
      f"{csub['disclosed']}  -> the smaller space can only disclose LESS, "
      "never more")
    w("")
    w(f"[elapsed {time.time()-t0:.1f} s]")
    out = "\n".join(rep) + "\n"
    sys.stdout.write(out)
    with open(os.path.join(HERE, "bilinear_miniature.txt"), "w") as fh:
        fh.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
