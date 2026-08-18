#!/usr/bin/env python3
"""m8b_scaling_model.py — U-PERF3 lane R: the COUNTED structure of the
composed FFN pass at an arbitrary (layers, T, d, f) shape, replicating the
engine's own public counters (ring_matmul.rs bk_pair_specs / bk_build_groups,
descent_fold::plan_pair_trees / pair_depth, gkr_masked::masked_transcript_totals,
eval_proof::plan_schedule) in Python so the 8B shape can be counted BEFORE
the rig can load it (bf_load_layer needs the export; M125_EXP is a 12-row
const).

Self-check: at (12, 512, 768, 2048) with the M125 exponent table this
reproduces `table-descent expect 12 512` — act n0 7,854,476 (aux 31,116),
weight n0 3,538,944, the ten pairs' depths / l / bytes (TOTAL 1,083,456 B),
schedules 9 levels floor 915 e7 (act) / 8 levels floor 939 e7 (weight) —
run with `--check` (asserts them). Every number printed by this script is
[COUNTED] given its inputs; the 8B exponent table is [ASSUMED] until the
Mac calibration lands (`--exps <manifest.json>` reads the real one).

Usage:
  python3 scripts/m8b_scaling_model.py --check
  python3 scripts/m8b_scaling_model.py --shape 32 512 4096 14336 [--exps manifest.json]
  python3 scripts/m8b_scaling_model.py --shape 32 16 4096 14336
"""

import argparse
import json
import math
import sys

D = 128                       # ring dimension (aux_ntt_core::D)
Q31 = 2_147_483_249           # ring::Q8 = 2^31 - 399
KAPPA = 11                    # eval_proof::KAPPA_AGG
FLOOR_E_MAX = 7               # eval_proof::FLOOR_E_MAX
OP_CONC = 20.79               # digits::OP_CONC
LEVEL_WIRE_BYTES = 4 + KAPPA * (4 + D * 4)   # 5,680
K9_MAX_LEAVES = 1 << 25       # kfield::K9_MAX_LEAVES (audited packed-table cap)
KEL_BYTES = 64                # one K-element on the wire

# BC's calibrated 125M exponents (ring_matmul.rs M125_EXP): (eX, eGate, eA, eUp, eH, eZ); eW = -9.
M125_EXP = [
    (-3, -3, -3, -3, 0, 1),
    (-2, -4, -4, -3, 0, -1),
    (-2, -3, -3, -2, 2, 1),
    (-2, -3, -3, -4, -1, -1),
    (-2, -4, -4, -4, -2, -1),
    (-2, -3, -3, -3, -1, -3),
    (-2, -3, -3, -3, 0, -3),
    (-2, -3, -3, -3, -1, -3),
    (-2, -3, -3, -3, 0, -2),
    (-2, -3, -3, -3, 0, -2),
    (-2, -3, -3, -2, 0, 0),
    (-2, -3, -3, -2, 0, 1),
]

# ---------------------------------------------------------------------------
# digits.rs

def alphabet(e0):
    if e0 == 1:
        return (-1, 1)
    half = 1 << (e0 - 1)
    return (-half, half - 1)


def representable(e0, l):
    lo, hi = alphabet(e0)
    base = 1 << e0
    geo = (base ** l - 1) // (base - 1)
    return lo * geo, hi * geo


def derive_l0(mn, mx, e0):
    l = 1
    while True:
        lo, hi = representable(e0, l)
        if lo <= mn and mx <= hi:
            return l
        l += 1
        assert l <= 64


def gamma_max_exact(q):
    return (q / 8.0) / 58.8


def acc_bits(inner):
    """Signed bits of sum of `inner` products of symmetric int8: floor(log2(inner*127^2)) + 2."""
    m = inner * 127 * 127
    return int(math.floor(math.log2(m))) + 2


# ---------------------------------------------------------------------------
# eval_proof.rs planner (plan_schedule), replicated

def limbs_for_bound(bound, e):
    l = 1
    while True:
        lo, hi = representable(e, l)
        if lo <= -bound and bound <= hi:
            return l
        l += 1
        assert l <= 64


def fold_coeff_bound(r, e_in):
    var = 2.0 * r * D * (2.0 / 3.0) * (4.0 ** (e_in - 1))
    conc = 1.3 * math.sqrt(var)
    bits = int(math.ceil(math.log2(conc))) + 2
    return 1 << min(bits, 62)


def adaptive_base(n_rings, q):
    gmax = gamma_max_exact(q)
    e = 1
    while e < FLOOR_E_MAX:
        gamma = OP_CONC * (2.0 ** e) * math.sqrt(n_rings * D)
        if gamma > gmax:
            break
        e += 1
    gamma_e = OP_CONC * (2.0 ** (e - 1)) * math.sqrt(n_rings * D)
    assert gamma_e <= gmax, "H-gate-ed fails even at e = 1"
    return e


def adaptive_base_opt(n_rings, q):
    """adaptive_base that returns None where the Rust one PANICS (gate fails
    even at e = 1) — the built planner asserts inside its r search loop, so
    ONE infeasible candidate (r = 2 at a big n0) kills the whole derivation
    (what-breaks item W-4)."""
    gmax = gamma_max_exact(q)
    e = 1
    while e < FLOOR_E_MAX:
        gamma = OP_CONC * (2.0 ** e) * math.sqrt(n_rings * D)
        if gamma > gmax:
            break
        e += 1
    gamma_e = OP_CONC * (2.0 ** (e - 1)) * math.sqrt(n_rings * D)
    if gamma_e > gmax:
        return None
    return e


PLANNER_PANICS = []   # (n_in, e_in, r, reason) recorded by plan_level


def plan_level(n_in, e_in, r, q):
    """Returns the LevelPlan dict, or None if the built planner would panic at
    this candidate (recorded in PLANNER_PANICS): the memo's tolerant variant
    skips infeasible r values instead."""
    chunk = -(-n_in // r)
    e_next = 2
    for _ in range(8):
        l_z = limbs_for_bound(fold_coeff_bound(r, e_in), e_next)
        l_t = limbs_for_bound((q - 1) // 2, e_next)
        l_h = l_t
        n_pairs = r * (r + 1) // 2
        n_out = chunk * l_z + r * KAPPA * l_t + n_pairs * l_h
        e_ok = adaptive_base_opt(n_out, q)
        if e_ok is None:
            PLANNER_PANICS.append((n_in, e_in, r, "adaptive_base: fold norm exceeds the gate even at e0 = 1 (n_out %d)" % n_out))
            return None
        if e_ok < 2:
            PLANNER_PANICS.append((n_in, e_in, r, "plan_level: interior witness too large for a balanced base (n_out %d)" % n_out))
            return None
        if e_ok <= e_next:
            e_final = min(e_next, e_ok)
            l_z = limbs_for_bound(fold_coeff_bound(r, e_in), e_final)
            l_t = limbs_for_bound((q - 1) // 2, e_final)
            l_h = l_t
            n_out = chunk * l_z + r * KAPPA * l_t + n_pairs * l_h
            return dict(n_in=n_in, e_in=e_in, r=r, chunk=chunk, e_next=e_final,
                        l_z=l_z, l_t=l_t, l_h=l_h, n_pairs=n_pairs, n_out=n_out)
        e_next = e_ok
    raise RuntimeError("base fixed point diverged")


def plan_schedule(n0, e0, q, strict=True):
    """Returns (levels, floor_rings, floor_e, headrooms_bits, gate_ok).
    strict=False records a level-0 gate failure instead of raising (the
    8B what-breaks reading)."""
    gmax = gamma_max_exact(q)
    levels, headrooms = [], []
    n, e = n0, e0
    gate_ok = True
    while True:
        assert e <= FLOOR_E_MAX
        gamma = OP_CONC * (2.0 ** (e - 1)) * math.sqrt(n * D)
        headrooms.append(math.log2(gmax) - math.log2(gamma))
        if gamma > gmax:
            gate_ok = False
            if strict:
                raise AssertionError("gamma_z 2^%.2f exceeds the exact-digit gate 2^%.2f (row H-gate-ed) at level %d"
                                     % (math.log2(gamma), math.log2(gmax), len(levels)))
        best = None
        for r in range(2, min(n, 64) + 1):
            lp = plan_level(n, e, r, q)
            if lp is None:
                continue
            if best is None or lp["n_out"] < best["n_out"]:
                best = lp
        if best is None:
            return levels, n, e, headrooms, False
        bytes_now = n * D
        bytes_next = LEVEL_WIRE_BYTES + best["n_out"] * D
        if best["n_out"] >= n or bytes_next >= bytes_now:
            return levels, n, e, headrooms, gate_ok
        n, e = best["n_out"], best["e_next"]
        levels.append(best)


# ---------------------------------------------------------------------------
# gkr_masked.rs transcript arithmetic + descent_fold.rs planning

def sc_degrees(n_bvars, child_masked):
    d = [3] * n_bvars
    if child_masked:
        d[0] = 5
    d.append(2)
    return d


def masked_transcript_shape(depth, n_extra):
    rounds = kel = 0
    for j in range(1, depth):
        degs = sc_degrees(j + n_extra, j <= depth - 2)
        rounds += len(degs)
        kel += sum(d + 1 for d in degs)
    return rounds, kel


def masked_transcript_totals(depth, n_extra, n_inst):
    rounds, kel = masked_transcript_shape(depth, n_extra)
    kel += 4 * n_inst
    kel += (depth - 1) * 6
    kel += 2 * (depth - 2)
    return rounds, kel


def mask_coeff_counts(depth, n_extra):
    g = sum(1 + sum(sc_degrees(j + n_extra, j <= depth - 2)) for j in range(1, depth))
    r = 12 * (depth - 2) if depth >= 2 else 0
    return g, r


def next_pow2(n):
    return 1 if n <= 1 else 1 << (n - 1).bit_length()


def block_pow(rows, cols):
    fp = rows * next_pow2(cols)
    assert rows & (rows - 1) == 0, "row count must be a power of two"
    assert fp & (fp - 1) == 0
    return fp.bit_length() - 1


def pair_depth(shapes):
    return max(block_pow(r, c) for r, c in shapes) + 2


def plan_pair_trees(shapes, depth):
    n = 1 << depth
    half = n // 2
    order = sorted(range(len(shapes)), key=lambda i: -block_pow(*shapes[i]))
    cursors = []
    blocks = []
    for mi in order:
        fp = 1 << block_pow(*shapes[mi])
        placed = False
        for ti, cur in enumerate(cursors):
            if cur[0] + fp <= half - 4:
                blocks.append((mi, ti, cur[0])); cur[0] += fp; placed = True; break
            if half + cur[1] + fp <= n - 4:
                blocks.append((mi, ti, half + cur[1])); cur[1] += fp; placed = True; break
        if not placed:
            ti = len(cursors)
            cursors.append([fp, 0])
            blocks.append((mi, ti, 0))
            assert fp <= half - 4, "member footprint exceeds tree half"
    n_real = len(cursors)
    l = next_pow2(n_real)
    return dict(depth=depth, l=l, n_real=n_real, e_bits=l.bit_length() - 1, blocks=blocks)


# ---------------------------------------------------------------------------
# The pass inventory (bk_pair_specs / bg_entry_class / bk_build_groups)

ENTRIES = ["X", "WgT", "WuT", "WdT", "Gacc", "Rg", "g8", "a8", "Uacc", "Ru", "u8",
           "H", "Rh", "h8", "Dacc", "Rd", "z"]
PAIR_IDS = ["silu-m3", "silu-m4", "nrw-88", "nrw-z"] + ["rem-w%d" % w for w in range(5, 11)]
TROWS = [256, 256, 256, 256, 32, 64, 128, 256, 512, 1024]


def layer_rows(exps, e_w):
    """(eX,eGate,eA,eUp,eH,eZ) -> shifts (g,u,h,z) as bf_load_layer derives them."""
    e_x, e_g, e_a, e_u, e_h, e_z = exps
    return (e_g - e_x - e_w, e_u - e_x - e_w, e_h - e_a - e_u, e_z - e_h - e_w)


def entry_shape(name, t, d, f):
    if name == "X" or name in ("Dacc", "Rd", "z"):
        return (t, d)
    if name in ("WgT", "WuT"):
        return (d, f)
    if name == "WdT":
        return (f, d)
    return (t, f)


def entry_l0(name, exps, shifts, d, f, honest_acc_bits=True):
    """(e0, l0) as bg_entry_class derives it from bf_entry_typing. The rig
    hard-codes Gacc/Uacc 25 bits and Dacc 26 bits (the 125M inner dims);
    honest_acc_bits=True uses acc_bits(inner) (what the 8B statement needs)."""
    e_x, e_g, e_a, e_u, e_h, e_z = exps
    sh_g, sh_u, sh_h, sh_z = shifts
    if name in ("WgT", "WuT", "WdT"):
        return (1, 8)
    def sym(bits):
        return derive_l0(-(1 << (bits - 1)) + 1, (1 << (bits - 1)) - 1, 2)
    def asym(bits):
        return derive_l0(-(1 << (bits - 1)), (1 << (bits - 1)) - 1, 2)
    def uns(bits):
        return derive_l0(0, (1 << bits) - 1, 2)
    gu_bits = acc_bits(d) if honest_acc_bits else 25
    dn_bits = acc_bits(f) if honest_acc_bits else 26
    return {
        "X": (2, sym(8)), "a8": (2, sym(8)),
        "g8": (2, asym(8)), "u8": (2, asym(8)), "h8": (2, asym(8)), "z": (2, asym(8)),
        "Gacc": (2, sym(gu_bits)), "Uacc": (2, sym(gu_bits)),
        "Dacc": (2, asym(dn_bits)),
        "H": (2, asym(15)),
        "Rg": (2, uns(sh_g)), "Ru": (2, uns(sh_u)), "Rh": (2, uns(sh_h)), "Rd": (2, uns(sh_z)),
    }[name]


def n_digit_rings(rows, cols, l0):
    assert (rows * cols) % D == 0, "no-tail discipline"
    return (rows * cols) // D * l0


def count_pass(layers, t, d, f, exps_rows, e_w=-9, honest_acc_bits=True, verbose=True, act_groups=1):
    """The whole counted structure. exps_rows: per-layer (eX,eGate,eA,eUp,eH,eZ)."""
    assert len(exps_rows) == layers
    out = {}
    lr = t.bit_length() - 1
    lam = (layers - 1).bit_length()
    slots = 1 << lam
    # --- groups (pass tensors) ---
    n_w = n_a = 0
    n_vr_w = n_vr_a = 0
    per_entry = {}
    shifts_all = []
    for li in range(layers):
        exps = exps_rows[li]
        sh = layer_rows(exps, e_w)
        shifts_all.append(sh)
        for name in ENTRIES:
            rows, cols = entry_shape(name, t, d, f)
            e0, l0 = entry_l0(name, exps, sh, d, f, honest_acc_bits)
            ndr = n_digit_rings(rows, cols, l0)
            per_entry[name] = (rows, cols, e0, l0)
            if name in ("WgT", "WuT", "WdT"):
                n_w += ndr; n_vr_w += rows * cols // D
            else:
                n_a += ndr; n_vr_a += rows * cols // D
    # --- pairs (bk_pair_specs) ---
    members = [[] for _ in PAIR_IDS]
    silu_of = [None] * len(PAIR_IDS)
    width_violations = []
    silu_members = set()
    for li in range(layers):
        e_x, e_g, e_a, e_u, e_h, e_z = exps_rows[li]
        sh_g, sh_u, sh_h, sh_z = shifts_all[li]
        pid = 0 if e_g == -3 else 1
        silu_of[pid] = (e_g, e_a)
        silu_members.add((e_g, e_a))
        members[pid].append((li, "g8", (t, f)))
        for e in ("u8", "h8"):
            members[2].append((li, e, (t, f)))
        members[3].append((li, "z", (t, d)))
        for e, w, shp in (("Rg", sh_g, (t, f)), ("Ru", sh_u, (t, f)), ("Rh", sh_h, (t, f)), ("Rd", sh_z, (t, d))):
            if not (5 <= w <= 10):
                width_violations.append((li, e, w))
                continue
            members[4 + (w - 5)].append((li, e, shp))
    pairs = []
    total_pair_bytes = 0
    total_rounds = 0
    tree_leaves = 0          # sum over real trees of 2^depth (packed leaf elements)
    n_real_trees = 0
    peak_pair = None
    aux_rings = 0
    ceiling_worst = 0.0
    for pid, mem in enumerate(members):
        if not mem:
            continue
        shapes = [m[2] for m in mem]
        depth = pair_depth(shapes)
        plan = plan_pair_trees(shapes, depth)
        t_rows = TROWS[pid]
        dt = t_rows.bit_length() - 1 + 1
        rw, kw = masked_transcript_totals(depth, plan["e_bits"], plan["l"])
        rt, kt = masked_transcript_totals(dt, plan["e_bits"], plan["l"])
        pbytes = KEL_BYTES * (kw + kt)
        total_pair_bytes += pbytes
        total_rounds += rw + rt
        tree_leaves += plan["n_real"] * (1 << depth)
        n_real_trees += plan["n_real"]
        # per-tree multiset (LKP-2 ceiling)
        used = [0] * plan["n_real"]
        for (mi, ti, base) in plan["blocks"]:
            used[ti] += shapes[mi][0] * shapes[mi][1]
        ceiling_worst = max(ceiling_worst, max(used) * 64 / Q31)
        # aux tensors (bk_build_groups)
        m_cols = -(-(plan["n_real"] * t_rows) // D) * D
        l0_m = derive_l0(0, max(used), 2)
        gw_c, rw_c = mask_coeff_counts(depth, plan["e_bits"])
        gt_c, rt_c = mask_coeff_counts(dt, plan["e_bits"])
        bl_kel = plan["n_real"] * 16
        wm_kel = -(-(gw_c + rw_c) // 8) * 8
        tm_kel = -(-(gt_c + rt_c) // 8) * 8
        l0_q = derive_l0(-((Q31) // 2), (Q31) // 2, 2)
        aux_here = (n_digit_rings(1, m_cols, l0_m) + n_digit_rings(bl_kel, 16, l0_q)
                    + n_digit_rings(wm_kel, 16, l0_q) + n_digit_rings(tm_kel, 16, l0_q))
        aux_rings += aux_here
        u_bytes = plan["n_real"] * (1 << depth) * 64
        row = dict(name=PAIR_IDS[pid], members=len(mem), n_real=plan["n_real"], l=plan["l"],
                   pads=plan["l"] - plan["n_real"], depth=depth, dt=dt, bytes=pbytes,
                   rounds=rw + rt, U_bytes=u_bytes, ceiling_frac=max(used) * 64 / Q31,
                   max_used=max(used))
        pairs.append(row)
        if peak_pair is None or u_bytes > peak_pair["U_bytes"]:
            peak_pair = row
    n_a_total = n_a + aux_rings
    # --- schedules ---
    del PLANNER_PANICS[:]
    n_a_group = -(-n_a_total // act_groups)
    lv_a, fl_a, fe_a, hr_a, ok_a = plan_schedule(n_a_group, 2, Q31, strict=False)
    panics_a = list(PLANNER_PANICS)
    del PLANNER_PANICS[:]
    lv_w, fl_w, fe_w, hr_w, ok_w = plan_schedule(n_w, 1, Q31, strict=False)
    panics_w = list(PLANNER_PANICS)
    # --- claim layer ---
    lcp_f = (f - 1).bit_length()
    lcp_d = (d - 1).bit_length()
    zc_nf_vars = lr + lcp_f + lam
    zc_nd_vars = lr + lcp_d + lam
    lk_gu = (d - 1).bit_length()
    lk_dn = (f - 1).bit_length()
    def mm_kel(lk):
        return 1 + 3 * lk + 4 * lam + 3
    def zc_kel(n_pos, is_rq):
        return 1 + (3 * n_pos if is_rq else 4 * n_pos) + 4 * lam + (5 if is_rq else 4)
    inst_kel = (mm_kel(lk_gu) * 2 + mm_kel(lk_dn) + zc_kel(lr + lcp_f, False)
                + zc_kel(lr + lcp_f, True) * 3 + zc_kel(lr + lcp_d, True))
    # --- bytes ---
    def group_bytes(levels, floor_rings):
        return 11_360 + 8_260 + LEVEL_WIRE_BYTES * (len(levels) - 1) + (4 + D * floor_rings)
    stmt_bytes = int(26_103 * layers / 12)      # [MODEL] serialized v4 statement (+P0 mode section) ~ linear in layers
    publics = 64 * 2 * layers
    art = stmt_bytes + inst_kel * 64 + publics + total_pair_bytes + group_bytes(lv_w, fl_w) + act_groups * group_bytes(lv_a, fl_a)
    out.update(dict(
        layers=layers, t=t, d=d, f=f, lam=lam, slots=slots,
        n_w=n_w, n_a=n_a, aux_rings=aux_rings, n_a_total=n_a_total, n_vr_w=n_vr_w, n_vr_a=n_vr_a,
        pairs=pairs, total_pair_bytes=total_pair_bytes, total_rounds=total_rounds,
        tree_leaves=tree_leaves, n_real_trees=n_real_trees, peak_pair=peak_pair,
        width_violations=width_violations, silu_members=sorted(silu_members),
        sched_a=(len(lv_a), fl_a, fe_a, hr_a[0], ok_a, lv_a), sched_w=(len(lv_w), fl_w, fe_w, hr_w[0], ok_w, lv_w),
        act_groups=act_groups, n_a_group=n_a_group, panics_a=panics_a, panics_w=panics_w,
        zc_nf_vars=zc_nf_vars, zc_nd_vars=zc_nd_vars, lk_gu=lk_gu, lk_dn=lk_dn, inst_kel=inst_kel,
        artifact=art, stmt_bytes=stmt_bytes, group_bytes=(group_bytes(lv_w, fl_w), group_bytes(lv_a, fl_a)),
        macs=layers * t * d * f * 3, weights=layers * 3 * d * f, per_entry=per_entry,
        ceiling_worst=ceiling_worst,
    ))
    if verbose:
        print_report(out)
    return out


def gb(x):
    return x / 1e9


def print_report(o):
    L, t, d, f = o["layers"], o["t"], o["d"], o["f"]
    print("=" * 78)
    print("shape %d layers x T %d x d %d x f %d  (lambda %d, slots %d)  MACs %.3g  int8 weights %.3g"
          % (L, t, d, f, o["lam"], o["slots"], o["macs"], o["weights"]))
    print("=" * 78)
    print("groups: weight n0 = %s digit rings (%s value rings); act n0 = %s (+ aux %s = %s; %s value rings)"
          % (f"{o['n_w']:,}", f"{o['n_vr_w']:,}", f"{o['n_a']:,}", f"{o['aux_rings']:,}", f"{o['n_a_total']:,}", f"{o['n_vr_a']:,}"))
    print("  w0 flat i8 store: weight %.1f GB + act %.1f GB = %.1f GB (n0 x 128 B)"
          % (gb(o["n_w"] * 128), gb(o["n_a_total"] * 128), gb((o["n_w"] + o["n_a_total"]) * 128)))
    if o["act_groups"] > 1:
        print("  act group SPLIT into %d groups of %s digit rings each [MODEL: the multi-group fix, W-3]" % (o["act_groups"], f"{o['n_a_group']:,}"))
    for gname, key, pk in (("act", "sched_a", "panics_a"), ("weight", "sched_w", "panics_w")):
        nl, fl, fe, hr0, ok, lv = o[key]
        r0 = lv[0]["r"] if lv else 0
        ch0 = lv[0]["chunk"] if lv else 0
        n1 = lv[0]["n_out"] if lv else 0
        print("  %s schedule: %d levels, floor %d rings e%d; level-0 gamma headroom %+.2f bits -> %s; level-0 r %d chunk %s; level-1 witness %s rings"
              % (gname, nl, fl, fe, hr0, "OK" if ok else "**level-0 H-gate-ed FAILS (planner panics: gamma > gamma_max)**", r0, f"{ch0:,}", f"{n1:,}"))
        if o[pk]:
            n_in, e_in, r, why = o[pk][0]
            print("    ** the BUILT planner also panics inside its r search (first at r = %d of n_in %s, e_in %d): %s — %d infeasible candidates skipped here [tolerant-planner reading]"
                  % (r, f"{n_in:,}", e_in, why, len(o[pk])))
        if lv:
            print("    level-0 A matrix (kappa x chunk rings, 1 KiB/ring boxed): %.1f GB; boxed level-1 witness %.1f GB"
                  % (gb(KAPPA * ch0 * 1064), gb(n1 * 1064)))
    print("claim layer: zero-check tables 2^%d (nf: Had, rq-g/u/h) and 2^%d (nd: rq-d) K-elements = %.1f / %.1f GB packed each (K9 cap 2^25 = %.1f GB)"
          % (o["zc_nf_vars"], o["zc_nd_vars"], gb((1 << o["zc_nf_vars"]) * 64), gb((1 << o["zc_nd_vars"]) * 64), gb(K9_MAX_LEAVES * 64)))
    print("  matmul instances: lk gate/up %d, down %d; instance transcript %d kel = %s B"
          % (o["lk_gu"], o["lk_dn"], o["inst_kel"], f"{o['inst_kel'] * 64:,}"))
    print("descent pairs (%d real trees; sum 2^depth over real trees = %s leaf elements; %s rounds; %s B):"
          % (o["n_real_trees"], f"{o['tree_leaves']:,}", f"{o['total_rounds']:,}", f"{o['total_pair_bytes']:,}"))
    for p in o["pairs"]:
        print("  %8s: %3d member cols -> %3d trees (l = %3d, pads %2d) depth %d / dt %d -> %s B; U = %.1f GB (1.75U = %.1f GB); LKP-2 %.0f%%"
              % (p["name"], p["members"], p["n_real"], p["l"], p["pads"], p["depth"], p["dt"], f"{p['bytes']:,}",
                 gb(p["U_bytes"]), gb(1.75 * p["U_bytes"]), 100 * p["ceiling_frac"]))
    if o["width_violations"]:
        print("  ** remainder widths OUTSIDE the built band 5..=10 (bk_pair_specs asserts): %s" % o["width_violations"][:8])
    print("  SiLU members present: %s (frozen registry: (-3,-3), (-4,-4))" % o["silu_members"])
    print("artifact [COUNTED]: statement ~%s + instances %s + publics %s + pairs %s + weight group %s + act group %s = %s B = %.3f MiB"
          % (f"{o['stmt_bytes']:,}", f"{o['inst_kel'] * 64:,}", f"{64 * 2 * L:,}", f"{o['total_pair_bytes']:,}",
             f"{o['group_bytes'][0]:,}", f"{o['group_bytes'][1]:,}", f"{o['artifact']:,}", o["artifact"] / 2**20))
    print("BfLayer as i64: weights %.1f GB + acts %.1f GB = %.1f GB (int8/i32 per class: %.1f GB)"
          % (gb(o["weights"] * 8), gb(L * (10 * t * f + 4 * t * d) * 8), gb(o["weights"] * 8 + L * (10 * t * f + 4 * t * d) * 8),
             gb(o["weights"] + L * (t * f * (2 * 4 + 8 * 1) + t * d * (1 * 4 + 3 * 1)))))


def load_exps(path, layers):
    m = json.load(open(path))
    rows = []
    for r in m["layers"]:
        rows.append((r["eX"], r["eGate"], r["eA"], r["eUp"], r["eH"], r["eZ"]))
    e_w = m["layers"][0].get("eW", -9)
    assert len(rows) >= layers, "manifest has %d layers" % len(rows)
    return rows[:layers], e_w


def check_125m():
    o = count_pass(12, 512, 768, 2048, M125_EXP, e_w=-9, honest_acc_bits=False, verbose=False)
    assert o["n_w"] == 3_538_944, o["n_w"]
    assert o["n_a_total"] == 7_854_476, o["n_a_total"]
    assert o["aux_rings"] == 31_116, o["aux_rings"]
    assert o["total_pair_bytes"] == 1_083_456, o["total_pair_bytes"]
    assert o["sched_a"][0] == 9 and o["sched_a"][1] == 915 and o["sched_a"][2] == 7, o["sched_a"][:3]
    assert o["sched_w"][0] == 8 and o["sched_w"][1] == 939 and o["sched_w"][2] == 7, o["sched_w"][:3]
    assert o["group_bytes"] == (179_576, 182_184), o["group_bytes"]
    assert o["artifact"] == 1_509_911, o["artifact"]
    names = [(p["name"], p["members"], p["n_real"], p["l"], p["depth"], p["dt"], p["bytes"]) for p in o["pairs"]]
    want = [("silu-m3", 10, 5, 8, 22, 9, 118_336), ("silu-m4", 2, 1, 1, 22, 9, 92_480),
            ("nrw-88", 24, 12, 16, 22, 9, 129_856), ("nrw-z", 12, 6, 8, 21, 9, 111_360),
            ("rem-w5", 4, 2, 2, 22, 6, 91_776), ("rem-w6", 7, 3, 4, 22, 7, 102_336),
            ("rem-w7", 10, 3, 4, 22, 8, 105_472), ("rem-w8", 17, 8, 8, 22, 9, 118_336),
            ("rem-w9", 7, 3, 4, 22, 10, 112_512), ("rem-w10", 3, 2, 2, 21, 11, 100_992)]
    assert names == want, names
    assert o["zc_nf_vars"] == 24 and o["inst_kel"] == 579, (o["zc_nf_vars"], o["inst_kel"])
    print("check_125m: OK — act n0 7,854,476 (aux 31,116), weight n0 3,538,944, ten pairs 1,083,456 B, "
          "schedules 9/915/e7 + 8/939/e7, zc tables 2^24, instances 579 kel, groups 179,576 / 182,184 B, artifact 1,509,911 B: the engine's counters reproduce")
    return o


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--shape", nargs=4, type=int, metavar=("LAYERS", "T", "D", "F"))
    ap.add_argument("--exps", help="manifest.json with per-layer eX/eGate/eA/eUp/eH/eZ (else the M125 rows, cycled) [ASSUMED]")
    ap.add_argument("--ew", type=int, default=-9, help="uniform weight exponent when no manifest (default -9)")
    ap.add_argument("--rig-acc-bits", action="store_true", help="use the rig's hard-coded 25/26 accumulator bits instead of acc_bits(inner)")
    ap.add_argument("--act-groups", type=int, default=1, help="model the act group split into k commitment groups (the W-3 fix)")
    a = ap.parse_args()
    if a.check:
        check_125m()
        count_pass(12, 512, 768, 2048, M125_EXP, e_w=-9, honest_acc_bits=False)
    if a.shape:
        L, t, d, f = a.shape
        if a.exps:
            rows, e_w = load_exps(a.exps, L)
            print("[exponent table from %s]" % a.exps)
        else:
            rows = [M125_EXP[i % 12] for i in range(L)]
            e_w = a.ew
            print("[exponent table ASSUMED: the M125 rows cycled over %d layers, eW = %d]" % (L, e_w))
        count_pass(L, t, d, f, rows, e_w=e_w, honest_acc_bits=not a.rig_acc_bits, act_groups=a.act_groups)
    if not a.check and not a.shape:
        ap.print_help()


if __name__ == "__main__":
    main()
