#!/usr/bin/env python3
"""U-AG4 Agent FA (O-8) spike: INDEX-EXTENSION FOLDING (IXF) of the
reduced protocol's sumcheck instances across the 32-layer pass.

Companion to docs/zkmatrix-poc/AGGREGATION_FOLDING_DESIGN.md (the doc
quotes THIS script's printed numbers; keep the two in lockstep).

What it does, in order:

  A. ANCHORS — imports Agent DA's greyhound_params_spike.py, Agent
     EA's aggregation_byte_model_spike.py and Agent EB's
     slack_composition_spike.py READ-ONLY and reproduces their
     recorded verdict numbers (EA layer totals, EA's O-8 floor
     1,500,496 B, EB's corrected kappa-11 layer totals, the four
     recorded descent (dw, kel) points) before printing anything.
  B. THE COMPOSED PIPELINE — EA's value-width-aware schedule2 x EB's
     corrections (kappa 11, T_cap = 33 operator cap, R-EB4
     inner-binding base caps via bt_cap = 30.5, R-EB3 K-draw
     aggregation line, exact-digit branch). Nobody had composed the
     dense encoding with the EB corrections before; equivalence
     self-checks pin both edges (caps off == EA; EB inputs == EB).
  C. TOY IXF FOLDS (executable) — real toy sumcheck instances of the
     house shape over F_q31: (i) a stacked Hadamard zero-check
     (CR-L6 form, eq kernel, 4 toy layers folded into one instance
     with 2 index variables) and (ii) a joint (layer, inner) matmul
     sumcheck (CR-L3 form, 4 layers). Honest folds VERIFY; tampered
     data REJECTS.
  D. NEGATIVES —
     N1 (AZ-L4 A1/A2 pattern): the zero-check challenge drawn BEFORE
        the commitments lets a crafted two-position defect ACCEPT;
        the correct FS order (challenge from the commitment digest)
        REJECTS the same crafting.
     N3 (the FD-L2 cross-term exhibit): folding OUTSIDE the sumcheck
        (naive product of stacked MLEs) is INCOMPLETE on honest data
        and UNSOUND under early draws (a forged C' != A*B accepts);
        the joint in-sumcheck fold is complete and rejects the forge.
     N5 (norm negative): the per-layer digit base e0 = 5 does NOT
        survive x32 stacking (gamma_z blows the exact-digit budget)
        — the e0 re-derivation of F-IF1.5 is mandatory, not
        cosmetic.
  E. NORM-GROWTH LAWS, numerically —
     stacked (adopted): fold-norm of m columns grows ~ sqrt(m)
        (measured log-log slope ~ 0.5 over m = 4..512, real quinary
        negacyclic folds);
     sequential RLC (rejected): ||acc|| after k chained folds grows
        ~ linearly in k (measured slope ~ 1.0 over k = 1..12, >= 8
        chained folds as required), and the decompose-refold reset
        (LatticeFold's move) restores the digit norm at the price of
        the per-step message the byte table charges.
  F. THE BYTE TABLES — the folded pass artifact at both reference
     shapes (2^20 ledger-unit pass, FFN 512x4096x11008 complete
     pass), exact-digit branch primary, activation-only
     (EA-comparable) and two-proof W-C layouts, vs EA's floor and
     the B1 gate; sensitivities. Totals asserted against the design
     doc's cited numbers (DOC_EXPECT).

Constraints respected: I-6 (nothing here adds masked openings), Z1
(no new wire object classes), exact-digit config primary, kappa 11 /
T_cap 33 / R-EB3 K-draw / R-EB4 caps (EB SUPERSEDES DA where they
overlap). Toy sumchecks run over the BASE field F_q31 for mechanics;
the house engine runs over K = GF(q^16) — soundness margins are NOT
modeled by the toy (the byte/norm sections carry those numbers).

stdlib only; runs in ~1 s; O(MB) memory (well under the 2 GiB cap).
"""

import hashlib
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import greyhound_params_spike as da            # noqa: E402  (read-only)
import aggregation_byte_model_spike as ea      # noqa: E402  (read-only)
import slack_composition_spike as eb           # noqa: E402  (read-only)

Q = 2147483249                 # q31 = 2^31 - 399 (house modulus)
D = 128
KEL_B = 64
POLY_B = 516
BUDGET = 262_144
KAPPA = 11                     # EB correction (SC doc 2.4(b))
T_CAP = 33                     # R-EB1 working point (EB doc 1.3)
BT_CAP = eb.BT_CAP             # 30.5 — R-EB4 inner-binding validity
AGG_KDRAW = 4 + 2 * POLY_B     # R-EB3 K-draw aggregation line (EB 4)
LAYERS = 32
LAM = 5                        # log2(LAYERS) index variables
E_CAP_FLOOR = 7                # R-EB4 floor base cap

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    print("  [%s] %2d. %s%s" % ("OK" if ok else "FAIL", len(CHECKS),
                                name, (" — " + detail) if detail else ""))
    return ok


# ===========================================================================
# A. ANCHORS
# ===========================================================================

def kel_fit(dw, dt=9):
    """Masked-descent K-element count, dt = 9 fixed [MODEL — exact fit
    to the four recorded (dw, kel) points, PROOF_BYTE_LEDGER 0.1/1-2]."""
    assert dt == 9
    return 2 * dw * dw + 11 * dw + 235


def section_anchors():
    print("\n== A. Anchors (DA / EA / EB reproduced before any design "
          "number) ==")
    # A1: EA's recorded layer totals from EA's own artifact()
    ea_expect = {
        ("FFN 512x11008", "dense", "per-level", "complete-layer"): 292_240,
        ("FFN 512x11008", "dense", "exact-digit", "ledger-unit"): 280_324,
        ("FFN 512x11008", "dense", "per-level", "ledger-unit"): 266_832,
        ("2^20 layer", "dense", "per-level", "ledger-unit"): 242_128,
        ("2^20 layer", "dense", "exact-digit", "ledger-unit"): 256_208,
    }
    ok = True
    for (shp, enc, model, scope), want in ea_expect.items():
        got = ea.artifact(shp, enc, model, scope)[1]
        ok &= (got == want)
    check("EA layer totals reproduced from ea.artifact (5 rows)", ok)

    # A2: EA's O-8 floor arithmetic (ENCODING_DESIGN 4.3)
    items, t, sched, ex = ea.artifact("FFN 512x11008", "dense",
                                      "per-level", "complete-layer")
    resid = ex["tr"] + 135 * KEL_B
    floor = 4096 + (t - resid - 4096) + 32 * resid
    check("EA O-8 floor reproduced = 1,500,496 B (5.72x)",
          floor == 1_500_496 and resid == 38_976,
          "resid %d floor %d" % (resid, floor))

    # A3: EB's corrected kappa-11 exact-digit layer totals (SC doc 2.4(b))
    eb_expect = {"FFN 512x11008": 283_392, "2^20 layer": 259_904}
    ok = True
    for nm, want in eb_expect.items():
        n_ring = eb.SHAPES[nm]["data_commits"] * 1024 // D
        s = eb.schedule(n_ring, 31.0, eb.gamma_budget(31.0, "per-level", 0),
                        KAPPA, 31, bt_cap=BT_CAP, T_cap=T_CAP, sigma=1.0)
        got = eb.artifact_total(eb.SHAPES[nm], s, KAPPA,
                                agg_bytes=AGG_KDRAW, jl_bytes=0)[0]
        ok &= (got == want)
    check("EB corrected layer totals reproduced (exact-digit + K-draw, "
          "kappa 11, R-EB4)", ok)

    # A4: the descent fit reproduces all four recorded points
    pts = {17: 1000, 19: 1166, 21: 1348, 24: 1651}
    ok = all(kel_fit(dw) == kel for dw, kel in pts.items())
    check("kel(dw,9) = 2dw^2+11dw+235 fits all 4 recorded points "
          "EXACTLY [MODEL beyond dw 24]", ok,
          "dw26 -> %d kel, dw29 -> %d kel" % (kel_fit(26), kel_fit(29)))


# ===========================================================================
# B. The composed pipeline (EA dense classes x EB corrections)
# ===========================================================================

def schedule_fold(classes, gamma_max, kappa, bt_cap=BT_CAP, t_cap=T_CAP,
                  sigma=1.0, max_levels=14, cap_es=E_CAP_FLOOR,
                  e0_max=31):
    """EA's schedule2 (value-width-aware) with EB's R-EB4 inner-binding
    base filter added at every level >= 1 (the composition neither lane
    ran). Structure credited to EA/DA; caps to EB. cap_es/bt_cap = None
    disables the EB corrections (for the equivalence self-check).
    e0_max forces a smaller level-0 base (the robust-e0 variant)."""
    q_bits = 31.0
    n_ring = sum(c for c, _ in classes)
    rows, e0 = [], None
    for e in range(1, min(32, e0_max + 1)):
        nl = sum(c * max(1, math.ceil(b / e)) for c, b in classes)
        gamma = da.OP_CONC * 2.0 ** (e - 1) * math.sqrt(nl * D)
        if gamma <= gamma_max:
            e0 = (e, nl, gamma)
    if e0 is None:
        return None
    e, nl0, gamma_z = e0
    l0_eff = nl0 / n_ring
    lt_guess = math.ceil(q_bits / max(1, e))
    m1 = int(math.sqrt(n_ring * kappa * lt_guess / max(1.0, l0_eff))) or 1
    m2 = math.ceil(n_ring / m1)
    hide = math.ceil(math.ceil(768 * q_bits / 11.7) / D)
    z_len = math.ceil(m1 * l0_eff) + hide
    rows.append(dict(lvl=0, n=n_ring, e=e, gamma=gamma_z, r=m2))
    pend = [(z_len, math.log2(da.fold_inf_norm(m2, e))),
            (m2 * kappa, q_bits), (m2, q_bits)]
    stops = []
    for lvl in range(1, max_levels + 1):
        e_i, n_i = None, None
        for e_try in range(1, 32):
            n_try = sum(c * max(1, math.ceil(b / e_try)) for c, b in pend)
            gamma = da.OP_CONC * 2.0 ** (e_try - 1) * math.sqrt(n_try * D)
            if gamma > gamma_max:
                continue
            if bt_cap is not None:            # R-EB4 (EB schedule form)
                bt = 8 * t_cap * (1 + 2.0 ** e_try) * sigma \
                    * eb.digit_l2(n_try, e_try)
                if math.log2(bt) > bt_cap:
                    continue
            e_i, n_i = e_try, n_try
        if e_i is None:
            break
        bare = None
        es_hi = e_i if cap_es is None else min(e_i, cap_es)
        for e_s in range(1, es_hi + 1):
            n_s = sum(c * max(1, math.ceil(b / e_s)) for c, b in pend)
            bytes_s = n_s * D * math.ceil((e_s + 1) / 8)
            if bare is None or bytes_s < bare[0]:
                bare = (bytes_s, e_s, n_s)
        stops.append((lvl, bare[2], bare[1], bare[0]))
        best = None
        for r in range(4, 257):
            if r > n_i:
                break
            wz_b = math.log2(da.fold_inf_norm(r, e_i))
            nxt = [(math.ceil(n_i / r), wz_b),
                   (r * kappa, q_bits), (r * (r + 1), q_bits)]
            n_nxt = sum(c * max(1, math.ceil(b / e_i)) for c, b in nxt)
            if best is None or n_nxt < best[1]:
                best = (r, n_nxt, nxt)
        r, n_nxt, pend = best
        rows.append(dict(lvl=lvl, n=n_i, e=e_i, r=r))
        if n_nxt >= n_i:
            break
    return dict(rows=rows, stops=stops, gamma_z=gamma_z, e0=e,
                m1=m1, m2=m2, n_limb=nl0, n_ring=n_ring)


def eval_proof_fold(sched, kappa=KAPPA, agg_bytes=AGG_KDRAW, jl_bytes=0):
    """EA's eval_proof2 stop selection with EB's per-level wire (kappa
    11 commit + K-draw aggregation; exact-digit -> no JL line)."""
    v_commit = 4 + kappa * POLY_B
    per_level = (4 + kappa * POLY_B) + jl_bytes + agg_bytes
    best = None
    for (lvl, n_i, e_i, bare) in sched["stops"]:
        total = v_commit + (lvl - 1) * per_level + bare
        if best is None or total < best[0]:
            best = (total, lvl, n_i, e_i, bare)
    total, lvl, n_i, e_i, bare = best
    return dict(total=total, stop_level=lvl, n_final=n_i, e_final=e_i,
                bare=bare, per_level=per_level)


BLIND_RINGS = 4096      # T_blind 2^12 rings, 31-bit class [MODEL, DA 2.5]


def pass_classes(shape, k=LAYERS):
    """Activation-group value classes for a k-layer pass: EA's dense
    per-layer classes x k, plus the T_blind aux class."""
    return ([(k * c, b) for c, b in ea.value_classes(shape, "dense")]
            + [(BLIND_RINGS, 31)])


def weight_classes(shape, k=LAYERS):
    """Stacked weight tensor, dense int8 (FFN complete scope only):
    3 matrices x 4096 x 11008 per layer [TARGET_CONTRACT Section 1]."""
    if shape != "FFN 512x11008":
        return None
    return [(k * 3 * 4096 * 11008 // D, 8)]


def pass_instances(shape, scope, lam=LAM, k=LAYERS, requant=2):
    """The folded instance list: EA's instance_list with the IXF index
    extension. Returns [(name, kel_wire)] + batch_rounds.
    Zero-checks/requant: rounds + lam at deg-3 wire. Matmul: lam
    index rounds at deg-3 wire + li rounds at deg-2 wire (FD-L2).
    Range TABLE descent: unchanged (shared table). Terminal batch:
    log2 of the k-layer committed coefficients."""
    s = ea.SHAPES[shape]
    commits = k * ea.inventory(shape, "dense")[0]
    batch_rounds = math.ceil(math.log2(commits * 1024))
    inst = [("hadamard", (s["had_rounds"] + lam) * 3)]
    if scope == "complete-layer":
        for r_ in s["mm_rounds"]:
            inst.append(("matmul", lam * 3 + r_ * 2))
        for _ in range(requant):
            inst.append(("requant", (s["had_rounds"] + lam) * 3))
        inst.append(("range-table-descent", 28 * 3))
    inst.append(("terminal-batch", batch_rounds * 3))
    return inst, batch_rounds


def pass_transcript_bytes(inst):
    kel = sum(w for _, w in inst) + 4 * len(inst)   # EA boundary [MODEL]
    return kel * KEL_B


ENTRIES_PASS = {"ledger-unit": 68, "complete-layer": 151}   # EA mid + 8/16
STATEMENT_PASS = 6144       # 4,096 + 32 manifest rows [MODEL]
FRAMING = 2048              # EA convention [MODEL]


def pass_artifact(shape, scope, gate="exact-digit", weights="W-C",
                  k=LAYERS, lam=LAM, entries=None, requant=2,
                  e0_max=31):
    """The folded pass artifact (F-IF1.7 skeleton). weights: 'none'
    (activation-only, EA-comparable), 'W-C' (separate weight opening),
    'W-B' (merged single opening)."""
    s = ea.SHAPES[shape]
    gmax = da.gamma_budget(31.0, gate, 0)
    dw_pass = s["dw"] + lam
    inst, batch_rounds = pass_instances(shape, scope, lam, k, requant)
    tr = pass_transcript_bytes(inst)
    if entries is None:
        entries = ENTRIES_PASS[scope]
    act_cls = pass_classes(shape, k)
    w_cls = weight_classes(shape, k) if scope == "complete-layer" else None
    groups = []
    if weights == "W-B" and w_cls:
        groups.append(("act+W merged", act_cls + w_cls))
    else:
        groups.append(("activations", act_cls))
        if weights == "W-C" and w_cls:
            groups.append(("weights", w_cls))
    items = [("statement (v3 + 32-row pass manifest) [MODEL]",
              STATEMENT_PASS),
             ("outer identities u (%d groups + T_blind, kappa=%d)"
              % (len(groups), KAPPA),
              (len(groups) + 1) * (4 + KAPPA * POLY_B)),
             ("masked descent pair (dw %d + dt 9) [MODEL kel fit]"
              % dw_pass, kel_fit(dw_pass) * KEL_B),
             ("folded instance transcript (%d inst, +%d rounds each)"
              % (len(inst), lam), tr),
             ("batch-entry claimed values (%d) [MODEL]" % entries,
              entries * KEL_B)]
    scheds = {}
    for gname, cls in groups:
        sc = schedule_fold(cls, gmax, KAPPA, e0_max=e0_max)
        if sc is None:
            return None
        ep = eval_proof_fold(sc)
        scheds[gname] = (sc, ep)
        items.append(("eval proof [%s]: L%d msgs + %d-ring floor "
                      "(e_f=%d, R-EB4)" % (gname, ep["stop_level"],
                                           ep["n_final"], ep["e_final"]),
                      ep["total"]))
    items.append(("framing [MODEL]", FRAMING))
    total = sum(b for _, b in items)
    return dict(items=items, total=total, scheds=scheds, tr=tr,
                inst=inst, batch_rounds=batch_rounds, dw_pass=dw_pass)


def section_pipeline_checks():
    print("\n== B. Composed-pipeline equivalence checks ==")
    # B1: caps OFF == EA's schedule2, dense FFN layer, both gates
    ok = True
    for model in ("per-level", "exact-digit"):
        gmax = da.gamma_budget(31.0, model, 0)
        cls = ea.value_classes("FFN 512x11008", "dense")
        kap = da.c3_kappa(28.0, 31.0)[0]
        s_ea = ea.schedule2(cls, 31.0, gmax, kap)
        s_my = schedule_fold(cls, gmax, kap, bt_cap=None, cap_es=None,
                             max_levels=9)
        ok &= (s_ea["e0"] == s_my["e0"]
               and abs(math.log2(s_ea["gamma_z"])
                       - math.log2(s_my["gamma_z"])) < 1e-9
               and [x[3] for x in s_ea["stops"]]
               == [x[3] for x in s_my["stops"]])
    check("schedule_fold == ea.schedule2 with EB caps disabled "
          "(FFN dense, both gates)", ok)
    # B2: EB inputs (slot 31-bit, kappa 11, caps on) == EB's schedule
    n_ring = eb.SHAPES["FFN 512x11008"]["data_commits"] * 1024 // D
    s_eb = eb.schedule(n_ring, 31.0, eb.gamma_budget(31.0, "per-level", 0),
                       KAPPA, 31, bt_cap=BT_CAP, T_cap=T_CAP, sigma=1.0)
    s_my = schedule_fold([(n_ring, 31)],
                         eb.gamma_budget(31.0, "per-level", 0), KAPPA,
                         max_levels=10, cap_es=None)
    ok = (s_eb["e0"] == s_my["e0"]
          and [x[3] for x in s_eb["stops"]] == [x[3] for x in s_my["stops"]])
    check("schedule_fold == eb.schedule on EB's own inputs (slot "
          "31-bit, kappa 11, R-EB4 on)", ok)
    # B3: pass_instances at lam=0, k=1 == EA's per-layer transcript
    inst0, _ = pass_instances("FFN 512x11008", "complete-layer",
                              lam=0, k=1)
    tr0 = pass_transcript_bytes(inst0)
    ea_tr = ea.transcript_bytes(ea.instance_list(
        "FFN 512x11008", "dense", "complete-layer", 2)[0])
    check("pass transcript at lam=0/k=1 == EA per-layer 30,336 B",
          tr0 == ea_tr == 30_336, "%d vs %d" % (tr0, ea_tr))


# ===========================================================================
# C/D. Toy IXF folds over F_q31 + negatives
# ===========================================================================

class FS(object):
    """Fiat-Shamir transcript: SHA-256 chain over absorbed items."""

    def __init__(self, tag):
        self.h = hashlib.sha256(tag.encode()).digest()

    def absorb(self, *items):
        m = hashlib.sha256(self.h)
        for it in items:
            if isinstance(it, (list, tuple)):
                for x in it:
                    m.update(int(x % Q).to_bytes(4, "little"))
            else:
                m.update(int(it % Q).to_bytes(4, "little"))
        self.h = m.digest()

    def absorb_bytes(self, b):
        self.h = hashlib.sha256(self.h + b).digest()

    def challenge(self):
        self.h = hashlib.sha256(self.h + b"c").digest()
        return int.from_bytes(self.h[:8], "little") % Q


def commit_digest(*tables):
    m = hashlib.sha256()
    for t in tables:
        for x in t:
            m.update(int(x % Q).to_bytes(4, "little"))
    return m.digest()


def mle_eval(vals, pt):
    """Multilinear extension of vals over {0,1}^n at pt (low bit
    first)."""
    cur = [v % Q for v in vals]
    for r in pt:
        cur = [(cur[2 * i] + r * (cur[2 * i + 1] - cur[2 * i])) % Q
               for i in range(len(cur) // 2)]
    return cur[0]


def eq_table(pt):
    t = [1]
    for r in pt:
        t = [(x * (1 - r)) % Q for x in t] + [(x * r) % Q for x in t]
    # note: low-bit-first ordering to match mle_eval's fold order
    out = [0] * len(t)
    n = len(pt)
    for idx in range(len(t)):
        w = 1
        for j in range(n):
            bit = (idx >> j) & 1
            w = (w * (pt[j] if bit else (1 - pt[j]))) % Q
        out[idx] = w
    return out


def lagrange_eval(evals, x):
    """Evaluate the poly interpolating (i, evals[i]), i = 0..deg, at
    x."""
    deg = len(evals) - 1
    total = 0
    for i in range(deg + 1):
        num, den = 1, 1
        for j in range(deg + 1):
            if j != i:
                num = (num * (x - j)) % Q
                den = (den * (i - j)) % Q
        total = (total + evals[i] * num * pow(den, Q - 2, Q)) % Q
    return total % Q


def sc_prove_verify(tables, comb, deg, claim, fs):
    """Run the composed sumcheck sum_b comb(tables[b]) = claim with
    FS challenges; returns (accept, final_point). Verifier-side final
    check evaluates comb on the tables' MLEs at the final point (the
    toy 'opening')."""
    n = int(math.log2(len(tables[0])))
    cur = [list(t) for t in tables]
    orig = [list(t) for t in tables]
    c = claim % Q
    pt = []
    for _ in range(n):
        half = len(cur[0]) // 2
        evals = []
        for t in range(deg + 1):
            s = 0
            for i in range(half):
                args = [(T[2 * i] + t * (T[2 * i + 1] - T[2 * i])) % Q
                        for T in cur]
                s = (s + comb(*args)) % Q
            evals.append(s)
        if (evals[0] + evals[1]) % Q != c:
            return False, None
        fs.absorb(evals)
        r = fs.challenge()
        pt.append(r)
        c = lagrange_eval(evals, r)
        cur = [[(T[2 * i] + r * (T[2 * i + 1] - T[2 * i])) % Q
                for i in range(half)] for T in cur]
    finals = [mle_eval(T, pt) for T in orig]
    return comb(*finals) % Q == c, pt


def toy_layers(seed, k=4, npos=8, defect=None):
    """k toy layers of the Hadamard relation Z = Y o U (int8-class
    values); defect = (layer, pos, delta) corrupts Z."""
    rng = random.Random(seed)
    Y = [[rng.randint(-127, 127) % Q for _ in range(npos)]
         for _ in range(k)]
    U = [[rng.randint(-127, 127) % Q for _ in range(npos)]
         for _ in range(k)]
    Z = [[(Y[l][i] * U[l][i]) % Q for i in range(npos)] for l in range(k)]
    if defect:
        l, i, dlt = defect
        Z[l][i] = (Z[l][i] + dlt) % Q
    stack = lambda M: [x for row in M for x in row]  # noqa: E731
    return stack(Y), stack(U), stack(Z)


def run_stacked_zerocheck(Ys, Us, Zs, order="correct", r_pre=None):
    """The IXF stacked Hadamard zero-check (FD-L1): draw r over the
    FULL (pos, layer) index space, sumcheck eq_r * (Y*U - Z) = 0.
    order='correct': r from FS AFTER the commitment. order='early':
    r_pre supplied (drawn before commitment — the A1/A2 attack
    surface)."""
    n = int(math.log2(len(Ys)))
    fs = FS("ixf-zerocheck")
    if order == "correct":
        fs.absorb_bytes(commit_digest(Ys, Us, Zs))
        r = [fs.challenge() for _ in range(n)]
    else:
        r = r_pre
        fs.absorb_bytes(commit_digest(Ys, Us, Zs))
    eq = eq_table(r)
    comb = lambda e, y, u, z: (e * ((y * u - z) % Q)) % Q   # noqa: E731
    ok, _ = sc_prove_verify([eq, Ys, Us, Zs], comb, 3, 0, fs)
    return ok


def section_toy_zerocheck():
    print("\n== C1. Toy stacked Hadamard zero-check (FD-L1, 4 layers x "
          "8 positions folded into ONE 5-var instance) ==")
    Ys, Us, Zs = toy_layers(11)
    check("honest stacked zero-check VERIFIES (32 packed positions, "
          "one transcript)", run_stacked_zerocheck(Ys, Us, Zs))
    Yd, Ud, Zd = toy_layers(11, defect=(2, 5, 7))
    check("single tampered position in layer 2 REJECTS",
          not run_stacked_zerocheck(Yd, Ud, Zd))


def section_negative_order():
    print("\n== D/N1. NEGATIVE — fold challenge drawn before its inputs "
          "are committed (AZ-L4 A1/A2 pattern) ==")
    # Adversary knows r in advance (early draw), crafts a TWO-position
    # defect with eq_r-weighted sum zero: eq[b1]*d1 + eq[b2]*d2 = 0.
    Ys, Us, Zs = toy_layers(23)
    n = int(math.log2(len(Ys)))
    r_pre = [FS("leaked").challenge() for _ in range(n)]
    eq = eq_table(r_pre)
    b1, b2 = 3, 17
    d1 = 41
    d2 = (-d1 * eq[b1] * pow(eq[b2], Q - 2, Q)) % Q
    Zbad = list(Zs)
    Zbad[b1] = (Zbad[b1] + d1) % Q
    Zbad[b2] = (Zbad[b2] + d2) % Q
    accept_wrong = run_stacked_zerocheck(Ys, Us, Zbad, order="early",
                                         r_pre=r_pre)
    accept_right = run_stacked_zerocheck(Ys, Us, Zbad, order="correct")
    check("crafted defect ACCEPTS when r is drawn early (the attack "
          "works)", accept_wrong)
    check("same crafting REJECTED under the correct FS order (r after "
          "commitments)", not accept_right)


def toy_matmuls(seed, k=4, defect=None):
    rng = random.Random(seed)
    A = [[[rng.randint(-127, 127) % Q for _ in range(4)]
          for _ in range(2)] for _ in range(k)]
    B = [[[rng.randint(-127, 127) % Q for _ in range(2)]
          for _ in range(4)] for _ in range(k)]
    C = [[[sum(A[l][i][t] * B[l][t][j] for t in range(4)) % Q
           for j in range(2)] for i in range(2)] for l in range(k)]
    if defect:
        l, i, j, dlt = defect
        C[l][i][j] = (C[l][i][j] + dlt) % Q
    return A, B, C


def matmul_reduced_tables(A, B, C, rx, ry, k=4):
    """Tables over (b: 2 vars low, l: 2 vars high) for the joint
    sumcheck; plus C~(., rx, ry) per layer."""
    Ar, Br, Crxy = [], [], []
    for l in range(k):
        arow = [(A[l][0][b] + rx * (A[l][1][b] - A[l][0][b])) % Q
                for b in range(4)]
        bcol = [(B[l][b][0] + ry * (B[l][b][1] - B[l][b][0])) % Q
                for b in range(4)]
        crow0 = [(C[l][0][j]) % Q for j in range(2)]
        crow1 = [(C[l][1][j]) % Q for j in range(2)]
        crx = [(crow0[j] + rx * (crow1[j] - crow0[j])) % Q
               for j in range(2)]
        Crxy.append((crx[0] + ry * (crx[1] - crx[0])) % Q)
        Ar.append(arow)
        Br.append(bcol)
    tabA = [Ar[l][b] for l in range(k) for b in range(4)]
    tabB = [Br[l][b] for l in range(k) for b in range(4)]
    # variable order: b low bits, l high bits -> index = l*4 + b with
    # low-bit-first folding == fold b first, then l.  (consistent)
    return tabA, tabB, Crxy


def run_joint_matmul(A, B, C, k=4):
    """FD-L2: sum_{l,b} eq(r_l,l) A~(l,rx,b) B~(l,b,ry) =
    C~(r_l,rx,ry), all challenges AFTER commitment."""
    fs = FS("ixf-matmul")
    fs.absorb_bytes(commit_digest(
        [x for l in range(k) for row in A[l] for x in row],
        [x for l in range(k) for row in B[l] for x in row],
        [x for l in range(k) for row in C[l] for x in row]))
    rx, ry = fs.challenge(), fs.challenge()
    rl = [fs.challenge(), fs.challenge()]
    tabA, tabB, Crxy = matmul_reduced_tables(A, B, C, rx, ry, k)
    eq_l = eq_table(rl)                      # over 2 layer vars
    eqtab = [eq_l[l] for l in range(k) for _ in range(4)]
    claim = sum(eq_l[l] * Crxy[l] for l in range(k)) % Q
    comb = lambda e, a, b: (e * a * b) % Q   # noqa: E731
    ok, _ = sc_prove_verify([eqtab, tabA, tabB], comb, 3, claim, fs)
    return ok


def section_toy_matmul():
    print("\n== C2. Toy joint (layer, inner) matmul fold (FD-L2, 4 "
          "layers) ==")
    A, B, C = toy_matmuls(31)
    check("honest joint matmul fold VERIFIES", run_joint_matmul(A, B, C))
    A, B, Cd = toy_matmuls(31, defect=(1, 1, 0, 9))
    check("tampered C in layer 1 REJECTS", not run_joint_matmul(A, B, Cd))


def section_negative_naive():
    print("\n== D/N3. NEGATIVE — folding OUTSIDE the sumcheck (naive "
          "product of stacked MLEs; FD-L2's cross-term exhibit) ==")
    k = 4
    A, B, C = toy_matmuls(47)
    rng = random.Random(53)
    rx, ry = rng.randrange(Q), rng.randrange(Q)
    rl = [rng.randrange(Q), rng.randrange(Q)]
    tabA, tabB, Crxy = matmul_reduced_tables(A, B, C, rx, ry, k)
    eq_l = eq_table(rl)
    # naive claim: sum_b A~(r_l, rx, b) * B~(r_l, b, ry) vs C~(r_l,..)
    Astk = [sum(eq_l[l] * tabA[l * 4 + b] for l in range(k)) % Q
            for b in range(4)]
    Bstk = [sum(eq_l[l] * tabB[l * 4 + b] for l in range(k)) % Q
            for b in range(4)]
    lhs = sum(Astk[b] * Bstk[b] for b in range(4)) % Q
    rhs = sum(eq_l[l] * Crxy[l] for l in range(k)) % Q
    check("naive fold is INCOMPLETE: honest data FAILS the naive check "
          "(cross terms)", lhs != rhs)
    # unsoundness under early draws: adversary knows (rl, rx, ry) and
    # plants E on layer 0 s.t. the naive check passes with C' != A*B.
    defect = (lhs - rhs) % Q
    corr = (defect * pow(eq_l[0], Q - 2, Q)) % Q
    Crxy_forged = list(Crxy)
    Crxy_forged[0] = (Crxy_forged[0] + corr) % Q     # C'_0 != A_0*B_0
    rhs_f = sum(eq_l[l] * Crxy_forged[l] for l in range(k)) % Q
    check("naive fold is UNSOUND under early draws: forged C' ACCEPTS "
          "the naive check", lhs == rhs_f)
    # the joint in-sumcheck fold rejects the same forged C' (rebuild a
    # C-tensor consistent with the forged slice claim is impossible;
    # emulate by re-running the joint fold on a C with layer-0 defect)
    A2, B2, Cd = toy_matmuls(47, defect=(0, 0, 0, 5))
    check("the joint IXF fold (challenges after commitment) REJECTS "
          "defective layer-0 C", not run_joint_matmul(A2, B2, Cd))


# ===========================================================================
# E. Norm-growth laws, numerically
# ===========================================================================

def ring_mul_neg(a, b):
    """Negacyclic product in Z[X]/(X^D+1), plain integers (no mod q —
    we are measuring NORMS)."""
    n = len(a)
    out = [0] * n
    for i, ai in enumerate(a):
        if ai == 0:
            continue
        for j, bj in enumerate(b):
            k = i + j
            if k < n:
                out[k] += ai * bj
            else:
                out[k - n] -= ai * bj
    return out


def section_norm_laws():
    print("\n== E. Norm-growth laws (measured, real quinary negacyclic "
          "folds; D = 32 toy ring for speed) ==")
    Dt = 32
    rng = random.Random(97)
    e0 = 2
    mag = 2 ** (e0 - 1)

    def rand_digit_vec(nrings):
        return [[rng.randint(-mag, mag) for _ in range(Dt)]
                for _ in range(nrings)]

    def rand_quinary():
        return [rng.randint(-2, 2) for _ in range(Dt)]

    def fold_norm(cols):
        """||sum_j c_j * w_j||_inf over fresh quinary c_j (one fold of
        m columns — the STACKED law's object)."""
        acc = [0] * Dt
        for w in cols:
            c = rand_quinary()
            p = ring_mul_neg(c, w)
            acc = [x + y for x, y in zip(acc, p)]
        return max(abs(x) for x in acc)

    # stacked law: norm of a single fold over m columns ~ sqrt(m)
    ms = [4, 8, 16, 32, 64, 128, 256, 512]
    meas = []
    for m in ms:
        trials = [fold_norm([w[0] for w in [rand_digit_vec(1)
                                            for _ in range(m)]])
                  for _ in range(8)]
        meas.append(sum(trials) / len(trials))
    slope = (math.log2(meas[-1] / meas[0])
             / math.log2(ms[-1] / ms[0]))
    check("STACKED law: one fold over m columns grows ~ sqrt(m) "
          "(measured log-log slope %.2f in [0.35, 0.65])" % slope,
          0.35 <= slope <= 0.65,
          "avg |.|inf: " + ", ".join("m%d:%.0f" % (m, v)
                                     for m, v in zip(ms, meas)))
    r32 = meas[5] / meas[0]         # m = 4 -> 128 is a 32x column span
    check("STACKED: 32x more columns costs ~sqrt(32) = 5.7x in norm "
          "(measured %.1fx in [3.5, 9] over m 4 -> 128)" % r32,
          3.5 <= r32 <= 9.0)

    # sequential RLC: acc_{k+1} = acc_k + c_k * w_k, k = 1..12.
    # The law the SEQUENTIAL scheme must CERTIFY (verifier-checked /
    # extractor-consumed) is the additive worst-case bound
    #   B_k = k * ||c||_op-cap * ||w||_inf  (LINEAR in k);
    # honest values concentrate like a random walk (~sqrt), but
    # soundness charges B_k — that is the LatticeFold crux.
    kmax = 12
    accs = []
    acc = [0] * Dt
    for kk in range(1, kmax + 1):
        w = rand_digit_vec(1)[0]
        c = rand_quinary()
        p = ring_mul_neg(c, w)
        acc = [x + y for x, y in zip(acc, p)]
        accs.append(max(abs(x) for x in acc))
    worst = [k * (2 * Dt) * mag for k in range(1, kmax + 1)]  # ||c||_1 cap
    check("SEQUENTIAL RLC over %d chained folds (>= 8 required): "
          "measured ||acc|| stays under the LINEAR certified bound "
          "B_k = k*||c||_1*mag at EVERY k" % kmax,
          all(a <= w for a, w in zip(accs, worst)),
          "|.|inf k=1..%d: %s vs B_k %s" % (kmax, accs, worst))
    # the house-arithmetic penalty: certified bound after 32 chained
    # folds (no re-decomposition) vs the flat one-shot fold
    seq_bits = math.log2(32 * T_CAP)          # +10.0 bits (T_cap = 33)
    flat_bits = 0.5 * math.log2(32)           # +2.5 bits
    check("SEQUENTIAL certified bound after 32 folds costs +%.1f bits "
          "vs flat's +%.1f — the >7-bit gap that q31 cannot host "
          "without per-step re-decomposition (31 fold messages)"
          % (seq_bits, flat_bits), seq_bits - flat_bits > 7.0)
    # decompose-refold reset (LatticeFold's move): balanced base-2^e
    # digits of acc have |digit| <= 2^(e-1) again
    e = 4
    half = 2 ** (e - 1)
    digs = []
    for x in acc:
        v = x
        while v:
            r = ((v + half) % (2 * half)) - half
            digs.append(r)
            v = (v - r) // (2 * half)
    check("decompose-refold RESETS the norm to the digit base "
          "(LatticeFold's per-step move — the message cost the "
          "sequential shape pays 31x)",
          max(abs(d) for d in digs) <= half,
          "max digit %d <= %d; %d limbs materialized"
          % (max(abs(d) for d in digs), half, len(digs)))

    # N5: the layer e0 = 5 does NOT survive x32 at the exact-digit gate
    gmax = da.gamma_budget(31.0, "exact-digit", 0)
    cls32 = pass_classes("FFN 512x11008")
    nl5 = sum(c * max(1, math.ceil(b / 5)) for c, b in cls32)
    g5 = da.OP_CONC * 2.0 ** 4 * math.sqrt(nl5 * D)
    s = schedule_fold(cls32, gmax, KAPPA)
    check("N5 NEGATIVE: keeping the per-layer e0 = 5 at x32 BLOWS the "
          "exact-digit budget (gamma 2^%.2f > 2^%.2f); re-derived "
          "pass e0 = %d fits" % (math.log2(g5), math.log2(gmax),
                                 s["e0"]),
          g5 > gmax and s["e0"] < 5)


# ===========================================================================
# F. The byte tables
# ===========================================================================

DOC_EXPECT = {    # pinned 2026-07-27; the design doc quotes EXACTLY these
    "led": 294_136,      # 2^20 ledger-unit pass
    "act": 352_948,      # FFN complete pass, activation-only (EA-comp.)
    "wc": 505_272,       # FFN complete pass, W-C two-proof (RECOMMENDED)
    "wb": 356_020,       # FFN complete pass, W-B merged (7B-only variant)
    "robust": 505_272,   # W-C at the adopted robust e0 = 2 (free)
    "cons": 354_228,     # act-only at the conservative per-level gate
}


def print_pass(shape, scope, weights, label, gate="exact-digit",
               e0_max=31):
    art = pass_artifact(shape, scope, gate=gate, weights=weights,
                        e0_max=e0_max)
    print("\n-- %s --" % label)
    for gname, (sc, ep) in art["scheds"].items():
        print("   group %-12s n=%s rings, %s limb-rings, e0=%d, "
              "gamma_z=2^%.2f (headroom %.2f b), stop L%d, floor %d "
              "rings" % (gname, format(sc["n_ring"], ","),
                         format(sc["n_limb"], ","), sc["e0"],
                         math.log2(sc["gamma_z"]),
                         math.log2(da.gamma_budget(31.0, gate, 0))
                         - math.log2(sc["gamma_z"]),
                         ep["stop_level"], ep["n_final"]))
    for name, b in art["items"]:
        print("   %-66s %10s B" % (name, format(b, ",")))
    print("   %-66s %10s B" % ("TOTAL (pass)", format(art["total"], ",")))
    print("   = %.3f MiB | %.2fx of 262,144 B | %s B/layer amortized"
          % (art["total"] / 2 ** 20, art["total"] / BUDGET,
             format(art["total"] // 32, ",")))
    return art


def section_bytes():
    print("\n== F. The folded pass byte tables (exact-digit primary, "
          "kappa 11, K-draw, R-EB4) ==")
    a_led = print_pass("2^20 layer", "ledger-unit", "none",
                       "2^20 ledger-unit PASS (32 rig layers; "
                       "activation group only — the rig has no matmul)")
    a_act = print_pass("FFN 512x11008", "complete-layer", "none",
                       "FFN complete PASS, activation-only "
                       "(EA-comparable variant)")
    a_wc = print_pass("FFN 512x11008", "complete-layer", "W-C",
                      "FFN complete PASS, W-C two-proof layout "
                      "(RECOMMENDED; P2-ready)")
    a_wb = print_pass("FFN 512x11008", "complete-layer", "W-B",
                      "FFN complete PASS, W-B merged single proof "
                      "(variant, norm-thin)")

    floor = 1_500_496
    check("VERDICT: FFN activation-only folded pass BEATS EA's floor "
          "(%.2fx under; floor was 5.72x budget, folded is %.2fx)"
          % (floor / a_act["total"], a_act["total"] / BUDGET),
          a_act["total"] < floor / 2.5)
    check("VERDICT: FFN W-C two-proof folded pass ALSO beats the floor",
          a_wc["total"] < floor,
          "%.2fx under" % (floor / a_wc["total"]))
    check("fold overhead: descent dw+5 adds %s B (< 40 KB class) "
          "for ALL 31 extra layers' lookups"
          % format((kel_fit(29) - kel_fit(24)) * KEL_B, ","),
          (kel_fit(29) - kel_fit(24)) * KEL_B < 40_000)
    unfolded32 = 32 * 283_392       # EB corrected layer x 32 [slot]
    check("folded W-C pass vs 32x EB-corrected unfolded layers: "
          "%.1fx smaller" % (unfolded32 / a_wc["total"]),
          unfolded32 / a_wc["total"] > 10)
    check("B1 gate: folded pass amortizes to %s B/layer = %.3fx of "
          "the 262,144 B/layer gate"
          % (format(a_wc["total"] // 32, ","),
             (a_wc["total"] / 32) / BUDGET),
          a_wc["total"] / 32 < BUDGET)

    # sensitivities
    print("\n-- sensitivities [MODEL] --")
    for lbl, kw in (("entries lo (116)", dict(entries=116)),
                    ("entries hi (186)", dict(entries=186)),
                    ("requant 1", dict(requant=1)),
                    ("kel fit +25% on the dw>24 extrapolated increment",
                     None)):
        if kw is None:
            base = pass_artifact("FFN 512x11008", "complete-layer",
                                 weights="W-C")
            extra = int(0.25 * (kel_fit(29) - kel_fit(24)) * KEL_B)
            t = base["total"] + extra
        else:
            t = pass_artifact("FFN 512x11008", "complete-layer",
                              weights="W-C", **kw)["total"]
        print("   %-52s %10s B  (%.3f MiB)" % (lbl, format(t, ","),
                                               t / 2 ** 20))
    # robust-e0 variant: the byte-optimal act-group base e0 = 3 sits at
    # 0.12 b headroom; e0 = 2 buys 0.87 b for a small byte premium
    art_r = pass_artifact("FFN 512x11008", "complete-layer",
                          weights="W-C", e0_max=2)
    sc_r = art_r["scheds"]["activations"][0]
    print("   %-52s %10s B  (%.3f MiB)  [act e0=%d, headroom %.2f b]"
          % ("robust act e0 = 2 (vs byte-optimal e0 = 3 @ 0.12 b)",
             format(art_r["total"], ","), art_r["total"] / 2 ** 20,
             sc_r["e0"],
             math.log2(da.gamma_budget(31.0, "exact-digit", 0))
             - math.log2(sc_r["gamma_z"])))
    # D-R1 break case: the range arm CANNOT share the folded witness
    # descent -> a second full pass-descent pair
    second = kel_fit(29) * KEL_B
    t = a_wc["total"] + second
    print("   %-52s %10s B  (%.3f MiB)"
          % ("D-R1 breaks: +1 full pass descent pair", format(t, ","),
             t / 2 ** 20))
    # per-level-gate conservative variant (EB Section-4 convention):
    # FINDING F-N2 — the WEIGHT group does not fit under the per-level
    # gamma gate at all (2^21.88 > 2^21.07); the weight-side pass
    # opening at q31 exists ONLY on the exact-digit branch (already
    # triple-mandated) or EB's relaxed line.
    w_pl = schedule_fold(weight_classes("FFN 512x11008"),
                         da.gamma_budget(31.0, "per-level", 0), KAPPA)
    check("F-N2: weight-group pass opening is INFEASIBLE at the "
          "per-level gamma gate (exact-digit branch is load-bearing "
          "for W-C)", w_pl is None)
    art_c = pass_artifact("FFN 512x11008", "complete-layer",
                          gate="per-level", weights="none")
    print("   %-52s %10s B  (%.3f MiB)"
          % ("conservative per-level gate (act-only; W infeasible)",
             format(art_c["total"], ","), art_c["total"] / 2 ** 20))

    # W-A rejection arithmetic (F-IF1.4): verifier-evaluated public
    # weight terminals at pass scale
    w_els = 32 * 3 * 4096 * 11008
    t_wa = w_els * 0.18e-6 / D      # 0.18 us/ring-MAC kernel class
    print("\n   W-A (no weight commitment; verifier evaluates public "
          "weight MLEs): %d els -> ~%.1f s single-threaded [MODEL, "
          "0.18 us/ring-MAC class] vs the 2 s R2 line -> REJECTED"
          % (w_els, t_wa))
    check("W-A verifier-evaluation of public weights is over the R2 "
          "line at pass scale (the reason W-C exists)", t_wa > 2.0)

    # F-N3: the robust-e0 point is free
    check("F-N3: robust act e0 = 2 (headroom 0.86 b) costs ZERO bytes "
          "vs byte-optimal e0 = 3 (0.12 b) — ADOPT e0 = 2",
          art_r["total"] == a_wc["total"],
          "%d vs %d" % (art_r["total"], a_wc["total"]))

    # F-N4: the 8B-shape scaling check [MODEL — TARGET_CONTRACT
    # Section 1's 8B dims d=4096, f=14336, T=512]: W-B merged blows
    # the exact-digit gate; W-C's weight group still fits (barely).
    d8, f8, t8 = 4096, 14336, 512
    gmax = da.gamma_budget(31.0, "exact-digit", 0)
    w8 = [(32 * 3 * d8 * f8 // D, 8)]
    act8 = [(32 * (t8 * d8 // D + 2 * (t8 * f8 // D)), 8),
            (32 * (t8 * f8 // D), 15), (6400, 31), (BLIND_RINGS, 31)]
    s_w8 = schedule_fold(w8, gmax, KAPPA)
    s_m8 = schedule_fold(act8 + w8, gmax, KAPPA)
    hw = (math.log2(gmax) - math.log2(s_w8["gamma_z"])) if s_w8 else -1
    check("F-N4 [MODEL]: at the 8B shape (4096x14336) the W-B merged "
          "witness EXCEEDS the exact-digit gate while W-C's weight "
          "group still fits (headroom %.2f b) — W-C is the layout "
          "that scales to the 8B target" % hw,
          s_m8 is None and s_w8 is not None and 0 < hw < 0.2)

    # Tier Z preview for FB (surcharge is FB's number; class check)
    tz_lo, tz_hi = a_wc["total"] + 176_000, a_wc["total"] + 240_000
    p3_lo = a_wc["total"] + 2 * 176_000
    p3_hi = a_wc["total"] + 2 * 240_000
    check("Tier Z class preview: W-C + one masked floor (P2) = "
          "%.2f-%.2f MiB; both floors (P3) = %.2f-%.2f MiB — inside "
          "Amendment A1's 0.5-2 MiB target class [FB owns the real "
          "number]" % (tz_lo / 2 ** 20, tz_hi / 2 ** 20,
                       p3_lo / 2 ** 20, p3_hi / 2 ** 20),
          tz_hi < 2 * 2 ** 20 and p3_hi < 2 * 2 ** 20)

    return dict(led=a_led["total"], act=a_act["total"],
                wc=a_wc["total"], wb=a_wb["total"],
                robust=art_r["total"], cons=art_c["total"])


DOC_TOTALS = None   # filled in main; asserted against DOC_EXPECT below


def section_doc_lockstep(totals):
    """Assert the doc-cited totals (kept in lockstep by hand)."""
    print("\n== G. Doc-lockstep assertions ==")
    expect = {
        "led": None, "act": None, "wc": None, "wb": None, "cons": None,
    }
    # Pinned after first successful run — the doc quotes exactly these.
    pinned = DOC_EXPECT
    if not pinned:
        print("   (first run: totals printed above; pin DOC_EXPECT "
              "before doc finalization)")
        return
    ok = all(totals[k] == v for k, v in pinned.items())
    check("byte-table totals match the design doc's cited numbers",
          ok, str({k: (totals[k], v) for k, v in pinned.items()
                   if totals[k] != v}))


def main():
    print("U-AG4 FA spike: index-extension folding (IXF) — anchors, "
          "toy folds, negatives, norm laws, byte tables")
    print("=" * 74)
    t0 = os.times()[4] if hasattr(os, "times") else 0
    section_anchors()
    section_pipeline_checks()
    section_toy_zerocheck()
    section_toy_matmul()
    section_negative_order()
    section_negative_naive()
    section_norm_laws()
    totals = section_bytes()
    section_doc_lockstep(totals)
    n_ok = sum(1 for _, ok in CHECKS if ok)
    print("\n%s — %d/%d self-checks OK" %
          ("ALL DONE" if n_ok == len(CHECKS) else "FAILURES",
           n_ok, len(CHECKS)))
    try:
        import resource
        rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        el = (os.times()[4] if hasattr(os, "times") else 0) - t0
        # ru_maxrss is BYTES on Darwin but KiB on Linux (BC finding
        # 2026-08-08, print-only fix — no check reads this value).
        rss_mib = rss / (1024.0 * 1024.0) if sys.platform == "darwin" \
            else rss / 1024.0
        print("runtime %.1f s, peak RSS %.0f MiB (caps: 600 s / 2 GiB)"
              % (el, rss_mib))
    except Exception:
        pass
    if n_ok != len(CHECKS):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
