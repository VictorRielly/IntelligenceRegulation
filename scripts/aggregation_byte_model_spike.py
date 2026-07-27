#!/usr/bin/env python3
"""U-AG3 Agent EA (D-1 + O-2) spike: the RECONCILED aggregation byte model
— DA's layout skeleton x DB's instance list x the D-1 encoding decision.

Companion to docs/zkmatrix-poc/AGGREGATION_ENCODING_DESIGN.md (the design
doc quotes THIS script's printed numbers; keep the two in lockstep).

What it does, in order:

  1. SELF-CHECKS part A — inherits Agent DA's 15 anchor checks by
     importing scripts/greyhound_params_spike.py (read-only; that file
     is NOT edited) and re-running them, then REPRODUCES DA's six
     recorded verdict totals (AGGREGATION_PARAMS_DESIGN.md 5.2/6.1)
     from DA's own functions — the config-overlap cross-check R-8
     asked for. Any drift fails loudly.
  2. SELF-CHECKS part B — dense-inventory arithmetic against
     PROOF_BYTE_LEDGER.md's derivation rules, and the regression that
     the value-width-aware norm chain (schedule2) reduces EXACTLY to
     DA's schedule when the value classes collapse to one 31-bit
     class.
  3. D-1 norm-chain re-derivation: level-0 digit base e0 and the full
     adaptive-base recursion at the DENSE encoding of Y/UP/Z —
     committed coefficients are VALUES (8-bit X/Y/UP, 15-bit Z,
     31-bit aux), not slot-idempotent spans (31-bit) — vs the
     slot-form baseline; plus the compounded-reading check at dense
     (export to EB/O-7).
  4. O-2 reconciled artifact model, at TWO statement scopes:
       - "ledger-unit": the PROOF_BYTE_LEDGER Section 1/2 statement
         (one activation tensor, SiLU lookup + Hadamard arm A — the
         18.59 GiB baseline's unit and the unit DA's tables priced);
       - "complete-layer": TARGET_CONTRACT Section 1's workload
         (3 matmuls + Hadamard + SiLU + requant edges + range arm —
         DB Section 10.1's instance list; R1's honest target).
     and at THREE encodings:
       - "slot (DA as-priced)": DA's own rows, reproduced — INCOMPLETE
         under DB's reduction (the R-2 violation: value claims have
         no dense object to run on); shown as the baseline only;
       - "slot+image": the as-drawn slot layout COMPLETED per
         AGGREGATION_CLAIM_REDUCTION 6.3 — dense value copies of
         Y/UP/Z committed alongside the packed forms, one
         packing-image sumcheck per packed tensor, +2 terminals each;
       - "dense": the D-1 recommendation — Y/UP/Z committed densely,
         slot form nowhere.
     DB's transcript is priced per instance (replacing DA's single
     batch-merge [MODEL] line — the terminal batch sumcheck IS the
     one point-family merge; keeping both double-counts it).
     Sensitivities, 32-layer pass numbers, the O-8 floor, verifier /
     prover / knowledge-error deltas, EB/EC exports.

Numbers only from: greyhound_params_spike.py (house/ring constants,
level machinery — 15-anchor-checked), PROOF_BYTE_LEDGER.md (inventory,
unit costs, budget), AGGREGATION_CLAIM_REDUCTION.md 6.3/10.1/10.2
(packing-image price, instance list, entry counts, transcript band),
AGGREGATION_PARAMS_DESIGN.md 2/5 (layout, skeleton), TARGET_CONTRACT.md
1-2 (shapes, int8 quantization — the value-width source). Landing
constants not from those sources are printed with a [MODEL] tag.

stdlib only; runs in well under a second; O(1) memory.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Agent DA's spike is imported READ-ONLY: constants + level machinery +
# its self-check battery. Formulas reused are cited to it; nothing is
# redefined unless the dense model NEEDS a different formula (schedule2
# below, with the difference stated).
import greyhound_params_spike as da  # noqa: E402

BUDGET = da.BUDGET          # 262,144 B (PROOF_BYTE_LEDGER.md Section 3)
KEL_B = da.KEL_B            # 64 B canonical K-element
POLY_B = da.POLY_B          # 516 B
D = da.D
LOG2Q = 31.0

checks = []


def check(name, ok, detail=""):
    checks.append((name, ok, detail))
    if not ok:
        print("  [FAIL] %s %s" % (name, detail))
    return ok


# ---------------------------------------------------------------------------
# Inventory (PROOF_BYTE_LEDGER.md Sections 1-2 [DERIVED] rules: one data
# commitment = 1,024 committed q31 coefficients; H3 slot form = 16 coeff
# per value; dense = 1 coeff per value).
# Value widths [TARGET_CONTRACT.md Section 2 + ring_matmul.rs U-K8
# header]: X offset codes [0,256) -> 8 bit; Y = SiLU int8 -> 8; UP
# requantized int8 -> 8; Z = Y o UP, |Z| <= 127^2 -> 15; lookup aux
# (m column, mask/blinder columns) mod-q/count-valued -> 31.
# Under H3 packing the committed COEFFICIENTS are value x slot
# idempotent e_t, and e_t has full-range mod-q coefficients: the
# slot-form witness is 31-bit per coefficient REGARDLESS of value width
# (D-1 finding F-2 — why DA's val_bits = 31 was correct for slot form
# and why dense re-encoding relaxes the whole digit chain).
# ---------------------------------------------------------------------------

SHAPES = {
    "2^20 layer": dict(
        n_el=1_048_572, dw=21, dt=9, kel=1348,
        x_commits=1_024, lookup_commits=21,
        slot_commits_per_tensor=16_384,   # ledger Section 0.1
        dense_commits_per_tensor=1_024,   # = ceil(n_el / 1024)
        had_rounds=20,                    # log2(n_el)
        img_rounds=24,                    # log2(n_el * 16) packed coords
        mm_rounds=None,                   # no matmul at the rig statement
    ),
    "FFN 512x11008": dict(
        n_el=5_636_096, dw=24, dt=9, kel=1651,
        x_commits=5_504, lookup_commits=25,
        slot_commits_per_tensor=88_064,   # ledger Section 2
        dense_commits_per_tensor=5_504,
        had_rounds=23,                    # log2(5.6e6) = 22.4 -> 23
        img_rounds=27,                    # log2(5.6e6 * 16) = 26.4 -> 27
        mm_rounds=(12, 12, 14),           # log2 4096, log2 11008 -> 14
    ),
}

ENCODINGS = ("slot+image", "dense")


def inventory(shape, encoding):
    """(data commits, committed rings) by the ledger rules."""
    s = SHAPES[shape]
    dense3 = s["dense_commits_per_tensor"] * 3
    slot3 = s["slot_commits_per_tensor"] * 3
    if encoding == "slot":            # DA as-priced (incomplete, R-2)
        tens = slot3
    elif encoding == "slot+image":    # CLAIM_REDUCTION 6.3 as-drawn
        tens = slot3 + dense3
    else:                             # dense (D-1 recommendation)
        tens = dense3
    commits = s["x_commits"] + tens + s["lookup_commits"]
    return commits, commits * 1024 // D


def value_classes(shape, encoding):
    """[(ring_count, value_bits)] for the digit decomposition."""
    s = SHAPES[shape]
    aux = s["lookup_commits"] * 1024 // D
    x_r = s["x_commits"] * 1024 // D
    t_r = s["dense_commits_per_tensor"] * 1024 // D
    slot_r = s["slot_commits_per_tensor"] * 3 * 1024 // D
    dense_part = [(x_r + 2 * t_r, 8), (t_r, 15), (aux, 31)]
    if encoding == "slot":
        return [(slot_r + x_r + aux, 31)]  # everything mod-q-wide
    if encoding == "slot+image":
        return [(slot_r, 31)] + dense_part
    return dense_part


# ---------------------------------------------------------------------------
# schedule2: DA's schedule() with TWO corrections needed by the dense
# model, otherwise formula-identical:
#   (a) the level-0 digit search runs over VALUE-WIDTH CLASSES —
#       witness limb count nl(e) = sum_c n_c * ceil(bits_c / e);
#   (b) the level-1 inputs t-hat and w are COMMITMENT coefficients
#       (full mod-q) independent of value width — invisible in DA's
#       runs because it passed val_bits = 31 everywhere.
# Self-check B4: one 31-bit class reproduces DA's schedule exactly.
# ---------------------------------------------------------------------------

def schedule2(classes, log2_q, gamma_max, kappa, max_levels=9):
    q_bits = log2_q
    n_ring = sum(c for c, _ in classes)
    rows = []
    e0 = None
    for e in range(1, 32):
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
    wz_bits = math.log2(da.fold_inf_norm(m2, e))
    rows.append(dict(lvl=0, n=n_ring, e=e, l=l0_eff, r=m2, gamma=gamma_z,
                     note="Greyhound fold over m2=%d cols, m1=%d"
                          % (m2, m1)))
    pend = [(z_len, wz_bits), (m2 * kappa, q_bits), (m2, q_bits)]
    stops = []
    for lvl in range(1, max_levels + 1):
        e_i, n_i = None, None
        for e_try in range(1, int(q_bits) + 1):
            n_try = sum(c * max(1, math.ceil(b / e_try)) for c, b in pend)
            gamma = da.OP_CONC * 2.0 ** (e_try - 1) * math.sqrt(n_try * D)
            if gamma <= gamma_max:
                e_i, n_i = e_try, n_try
        if e_i is None:
            break
        bare, e_bare, n_bare = None, None, None
        packed = None
        for e_s in range(1, e_i + 1):
            n_s = sum(c * max(1, math.ceil(b / e_s)) for c, b in pend)
            bytes_s = n_s * D * math.ceil((e_s + 1) / 8)
            if bare is None or bytes_s < bare:
                bare, e_bare, n_bare = bytes_s, e_s, n_s
            bits_s = math.ceil(n_s * D * (e_s + 1) / 8)   # bit-packed
            if packed is None or bits_s < packed:
                packed = bits_s
        stops.append((lvl, n_bare, e_bare, bare, packed))
        best = None
        for r in range(4, 257):
            if r > n_i:
                break
            gamma_i = da.OP_CONC * 2.0 ** (e_i - 1) * math.sqrt(n_i * D)
            wz_b = math.log2(da.fold_inf_norm(r, e_i))
            nxt = [(math.ceil(n_i / r), wz_b),
                   (r * kappa, q_bits),
                   (r * (r + 1), q_bits)]
            n_nxt = sum(c * max(1, math.ceil(b / e_i)) for c, b in nxt)
            if best is None or n_nxt < best[1]:
                best = (r, n_nxt, gamma_i, wz_b, nxt)
        r, n_nxt, gamma_i, wz_b, pend = best
        rows.append(dict(lvl=lvl, n=n_i, e=e_i, l=1, r=r, gamma=gamma_i,
                         note="fold r=%d" % r))
        if n_nxt >= n_i:
            break
    return dict(rows=rows, stops=stops, gamma_z=gamma_z, m1=m1, m2=m2,
                e0=e, l0=l0_eff, z_len=z_len, hide=hide)


def eval_proof2(sched, kappa):
    """DA's eval_proof_bytes() on a schedule2 dict (5-tuple stops), plus
    the bit-packed bare-witness lever per stop."""
    v_commit = 4 + kappa * POLY_B
    per_level_wire = ((4 + kappa * POLY_B)
                      + (4 + 256 * 4)
                      + (4 + 16 * KEL_B))
    best = None
    for (lvl, n_i, e_i, bare, packed) in sched["stops"]:
        total = v_commit + (lvl - 1) * per_level_wire + bare
        if best is None or total < best[0]:
            best = (total, lvl, n_i, e_i, bare, packed)
    total, lvl, n_i, e_i, bare, packed = best
    # the bit-packed lever may prefer a DIFFERENT stop:
    packed_best = min(v_commit + (lv - 1) * per_level_wire + pk
                      for (lv, _, _, _, pk) in sched["stops"])
    return dict(total=total, stop_level=lvl, n_final=n_i, e_final=e_i,
                bare=bare, per_level_wire=per_level_wire,
                pack_lever=(total - packed_best))


# ---------------------------------------------------------------------------
# The reconciled artifact model (O-2). Reconciliation decisions (doc
# Section 3):
#   R8-a  DA's "batch-merge sumcheck [MODEL]" line is DROPPED — the
#         terminal batch sumcheck (CR-L4) is one of DB's priced
#         instances; keeping both double-counts the one point-family
#         merge (R-3: ONE common landing point).
#   R8-b  the NEW-instance transcript is priced per instance from DB
#         10.1 (rounds x on-wire K-el/round + boundary values),
#         replacing DB's coarse +27-40 KiB band; the derived number
#         must land inside/near the band (self-check B5).
#   R8-c  the claim-value line uses DB 10.2's batch-entry count (one K
#         value per entry) instead of DA's "16 claims x 8 slots".
#   R8-d  slot form is priced AS COMPLETED (6.3 apparatus), not as
#         DA drew it (the R-2 violation).
# ---------------------------------------------------------------------------

WIRE_KEL = {2: 2, 3: 3}       # send-(deg) round wire [MODEL]
BOUNDARY_KEL = 4              # boundary values per instance [MODEL]
ENTRIES = {                   # DB 10.2 bands [MODEL]
    "ledger-unit": (48, 60, 68),      # pins ~40-60 + Had 3 + lookup 3 + 2
    "complete-layer": (100, 135, 170),  # DB 10.2's ~110-170, lo/mid/hi
}
DB_BAND = (27 * 1024, 40 * 1024)  # DB 10.1 transcript band [MODEL]


def instance_list(shape, encoding, scope, requant_checks=2):
    """DB Section 10.1, scoped. The SiLU descent pair itself is the
    ledger kel line, not counted here. The range arm's WITNESS side is
    assumed to rho-share the SiLU witness descent [MODEL — divergence
    D-R1 if it cannot]; its table descent (depth 8 -> 28 rounds) is
    counted. Packing-image sumchecks per CLAIM_REDUCTION 6.3 when slot
    form is retained."""
    s = SHAPES[shape]
    commits, _ = inventory(shape, encoding)
    batch_rounds = math.ceil(math.log2(commits * 1024))
    inst = [("hadamard", s["had_rounds"], 3)]
    if scope == "complete-layer":
        for r_ in s["mm_rounds"]:
            inst.append(("matmul", r_, 2))
        for _ in range(requant_checks):
            inst.append(("requant", s["had_rounds"], 3))
        inst.append(("range-table-descent", 28, 3))
    if encoding == "slot+image":
        for _ in range(3):
            inst.append(("packing-image", s["img_rounds"], 2))
    inst.append(("terminal-batch", batch_rounds, 3))
    return inst, batch_rounds


def transcript_bytes(inst):
    kel = sum(r_ * WIRE_KEL[dg] for _, r_, dg in inst)
    kel += BOUNDARY_KEL * len(inst)
    return kel * KEL_B


def artifact(shape, encoding, model, scope, n_entries=None,
             requant_checks=2):
    s = SHAPES[shape]
    commits, n_ring = inventory(shape, encoding)
    kappa, k_z = da.c3_kappa(LOG2Q - 3, LOG2Q)
    gmax = da.gamma_budget(LOG2Q, model, 0)
    sched = schedule2(value_classes(shape, encoding), LOG2Q, gmax, kappa)
    if sched is None:
        return None
    ep = eval_proof2(sched, kappa)
    use_jl = model != "exact-digit"
    jl_extra = (1024 * max(0, ep["stop_level"] - 1)) if use_jl else 0
    inst, batch_rounds = instance_list(shape, encoding, scope,
                                       requant_checks)
    tr = transcript_bytes(inst)
    if n_entries is None:
        n_entries = ENTRIES[scope][1]
    if encoding == "slot+image":
        n_entries += 6                    # 2 terminals x 3 image claims
    items = [
        ("statement (v3 codec)", 4096),
        ("global commitment identities (2 x outer u, kappa=%d)" % kappa,
         2 * (4 + kappa * POLY_B)),
        ("masked descent pair (dw %d + dt %d, 4 B/limb)"
         % (s["dw"], s["dt"]), s["kel"] * KEL_B),
        ("NEW sumcheck transcript (%d inst incl. terminal batch)"
         % len(inst), tr),
        ("eval proof: %d level msgs (incl. 512-row JL)" % ep["stop_level"],
         ep["stop_level"] * ep["per_level_wire"] + jl_extra),
        ("eval proof: final bare witness (%d rings, %d-bit digits)"
         % (ep["n_final"], ep["e_final"]), ep["bare"]),
        ("batch-entry claimed values (%d entries x K-el)" % n_entries,
         n_entries * KEL_B),
        ("framing/prefixes [MODEL]", 2048),
    ]
    total = sum(b for _, b in items)
    return items, total, sched, dict(ep=ep, jl_extra=jl_extra,
                                     kappa=kappa, k_z=k_z, n_ring=n_ring,
                                     commits=commits, tr=tr, inst=inst,
                                     batch_rounds=batch_rounds)


# ---------------------------------------------------------------------------
# Self-checks
# ---------------------------------------------------------------------------

def selfcheck_a():
    da.self_checks()
    ok = all(o for _, o, _, _ in da.checks)
    check("A1: DA 15-anchor battery re-run", ok,
          "%d/%d" % (sum(1 for _, o, _, _ in da.checks if o),
                     len(da.checks)))
    recorded = {
        ("2^20 layer", "per-level", 31.0, 31): 252_868,
        ("2^20 layer", "exact-digit", 31.0, 31): 265_540,
        ("FFN 512x11008", "per-level", 31.0, 31): 278_968,
        ("FFN 512x11008", "exact-digit", 31.0, 31): 289_080,
        ("FFN 512x11008", "compounded", 31.0, 31): 41_593_548,
        ("FFN 512x11008", "per-level", 46.0, 46): 354_104,
    }
    for (nm, model, lq, vb), want in recorded.items():
        shp = dict(da.SHAPES[nm])
        n_ring = shp["data_commits"] * 1024 // D
        kappa, _ = da.c3_kappa(lq - 3, lq)
        best = None
        depths = ([9] if da.SLACK_MODELS[model]["per_level"] == 1.0
                  else list(range(1, 10)))
        for depth in depths:
            gmax = da.gamma_budget(lq, model, depth - 1)
            if gmax < 1.0:
                continue
            sc = da.schedule(n_ring, lq, gmax, kappa, vb, max_levels=depth)
            if sc is None or not sc["stops"]:
                continue
            _, tot, ep = da.artifact_table(shp, sc, kappa)
            if best is None or tot < best[0]:
                best = (tot, ep)
        use_jl = model != "exact-digit"
        jl = 1024 * max(0, best[1]["stop_level"] - 1) if use_jl else 0
        got = best[0] + jl
        check("A2: DA verdict total %s/%s/q%d" % (nm, model, round(lq)),
              got == want, "got %d want %d" % (got, want))


def selfcheck_b():
    check("B1: slot inventory @2^20 = 50,197 commits (ledger 0.1)",
          inventory("2^20 layer", "slot")[0] == 50_197,
          str(inventory("2^20 layer", "slot")))
    check("B1: slot inventory @FFN = 269,721 commits (ledger 2)",
          inventory("FFN 512x11008", "slot")[0] == 269_721,
          str(inventory("FFN 512x11008", "slot")))
    c20, r20 = inventory("2^20 layer", "dense")
    cf, rf = inventory("FFN 512x11008", "dense")
    check("B2: dense inventory @2^20 = 4,117 commits / 32,936 rings",
          (c20, r20) == (4_117, 32_936), str((c20, r20)))
    check("B2: dense inventory @FFN = 22,041 commits / 176,328 rings",
          (cf, rf) == (22_041, 176_328), str((cf, rf)))
    ratio = inventory("FFN 512x11008", "slot")[1] / rf
    check("B2: dense ring reduction @FFN = 12.2x (R-2's '~13x')",
          12.0 <= ratio <= 13.5, "%.2f" % ratio)
    ci, ri = inventory("FFN 512x11008", "slot+image")
    check("B2: slot+image @FFN = slot + dense copies (6.3 as-drawn)",
          ci == 269_721 + 3 * 5_504, str((ci, ri)))
    # B4: schedule2 == DA schedule on the collapsed 31-bit class
    for nm in ("2^20 layer", "FFN 512x11008"):
        n_ring = da.SHAPES[nm]["data_commits"] * 1024 // D
        kappa, _ = da.c3_kappa(28.0, 31.0)
        for model in ("per-level", "exact-digit"):
            gmax = da.gamma_budget(31.0, model, 0)
            s_da = da.schedule(n_ring, 31.0, gmax, kappa, 31, max_levels=9)
            s_2 = schedule2([(n_ring, 31)], 31.0, gmax, kappa)
            same = (s_da["e0"] == s_2["e0"]
                    and abs(math.log2(s_da["gamma_z"])
                            - math.log2(s_2["gamma_z"])) < 1e-9
                    and [x[3] for x in s_da["stops"]]
                    == [x[3] for x in s_2["stops"]])
            check("B4: schedule2 == DA schedule (%s, %s)" % (nm, model),
                  same, "e0 %s vs %s" % (s_da["e0"], s_2["e0"]))
    # B5: dense complete-layer transcript lands in/near DB's band
    lo = transcript_bytes(instance_list("FFN 512x11008", "dense",
                                        "complete-layer", 1)[0])
    hi = transcript_bytes(instance_list("FFN 512x11008", "dense",
                                        "complete-layer", 2)[0])
    check("B5: dense complete-layer transcript vs DB 27-40 KiB [MODEL]",
          DB_BAND[0] * 0.85 <= lo <= hi <= DB_BAND[1] * 1.10,
          "%d..%d B" % (lo, hi))


def selfcheck_c():
    kappa, _ = da.c3_kappa(28.0, 31.0)
    for model, min_e0, da_e0 in (("per-level", 3, 1),
                                 ("exact-digit", 4, 2)):
        gmax = da.gamma_budget(31.0, model, 0)
        s2 = schedule2(value_classes("FFN 512x11008", "dense"),
                       31.0, gmax, kappa)
        check("C1: dense FFN e0 >= %d under %s (DA slot row: e0 = %d)"
              % (min_e0, model, da_e0),
              s2["e0"] >= min_e0, "e0 = %d" % s2["e0"])
    classes = value_classes("FFN 512x11008", "dense")
    nl1 = sum(c * max(1, math.ceil(b / 1)) for c, b in classes)
    gz1 = da.OP_CONC * math.sqrt(nl1 * D)
    gmax_l2 = da.gamma_budget(31.0, "compounded", 1)
    check("C2: compounded L=2 budget hosts dense FFN level-0 fold",
          gz1 <= gmax_l2,
          "gamma_z(e=1) 2^%.2f vs gamma_max(L=2) 2^%.2f"
          % (math.log2(gz1), math.log2(gmax_l2)))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def print_artifact(shape, encoding, model, scope, verbose=True):
    out = artifact(shape, encoding, model, scope)
    if out is None:
        print("   INFEASIBLE")
        return None
    items, total, sched, ex = out
    if verbose:
        print("\n-- %s | %s | %s | %s --" % (shape, encoding, model, scope))
        print("   n = %s commits = %s rings; e0 = %d (avg limbs %.1f); "
              "gamma_z = 2^%.2f"
              % (format(ex["commits"], ","), format(ex["n_ring"], ","),
                 sched["e0"], sched["l0"], math.log2(sched["gamma_z"])))
        for name, b in items:
            print("   %-64s %10s B" % (name, format(b, ",")))
        print("   %-64s %10s B  (%.2fx) -> %s"
              % ("TOTAL vs 262,144 B", format(total, ","), total / BUDGET,
                 "PASS" if total <= BUDGET else "OVER"))
        print("   pack lever [MODEL, R4 codec ext]: -%s B -> %s B (%.2fx)"
              % (format(ex["ep"]["pack_lever"], ","),
                 format(total - ex["ep"]["pack_lever"], ","),
                 (total - ex["ep"]["pack_lever"]) / BUDGET))
    return total, ex, sched


def main():
    print("U-AG3 EA spike: reconciled byte model "
          "(DA skeleton x DB instances x D-1 encoding)")
    print("=" * 74)
    print("\nSELF-CHECKS")
    selfcheck_a()
    selfcheck_b()
    selfcheck_c()
    n_ok = sum(1 for _, ok, _ in checks if ok)
    print("  self-checks: %d/%d OK" % (n_ok, len(checks)))
    for name, ok, detail in checks:
        print("    [%s] %s%s" % ("OK" if ok else "FAIL", name,
                                 (" (%s)" % detail) if detail else ""))
    if n_ok != len(checks):
        raise SystemExit("self-checks failed - refusing to print design "
                         "numbers")

    # ---- D-1 norm-chain table ----
    print("\nD-1 NORM-CHAIN RE-DERIVATION (level-0 digit base at q31)")
    kappa, k_z = da.c3_kappa(28.0, 31.0)
    print("  %-16s %-11s %-12s %4s %12s %10s %9s %10s" %
          ("shape", "encoding", "slack model", "e0", "witness limbs",
           "gamma_z", "headroom", "top MSIS"))
    for nm in SHAPES:
        for enc in ("slot", "slot+image", "dense"):
            for model in ("per-level", "exact-digit"):
                gmax = da.gamma_budget(31.0, model, 0)
                s2 = schedule2(value_classes(nm, enc), 31.0, gmax, kappa)
                nl = sum(c * max(1, math.ceil(b / s2["e0"]))
                         for c, b in value_classes(nm, enc))
                base = da.SLACK_MODELS[model]["base"]
                bt = math.log2(base * s2["gamma_z"])
                bits = da.msis_core_svp_bits(k_z, 31.0, bt)
                print("  %-16s %-11s %-12s %4d %13s %10s %8.2fb %7.1f b" %
                      (nm, enc, model, s2["e0"], format(nl, ","),
                       "2^%.2f" % math.log2(s2["gamma_z"]),
                       math.log2(gmax) - math.log2(s2["gamma_z"]), bits))

    # ---- O-2 reconciled tables: headline configs verbose ----
    print("\nO-2 RECONCILED ARTIFACT TABLES (canonical widths; entries = "
          "DB 10.2 midpoints [MODEL])")
    totals = {}
    for nm in SHAPES:
        scopes = (["ledger-unit"] if nm == "2^20 layer"
                  else ["ledger-unit", "complete-layer"])
        for scope in scopes:
            for enc in ENCODINGS:
                for model in ("per-level", "exact-digit"):
                    verbose = (nm == "FFN 512x11008"
                               and model == "per-level")
                    r = print_artifact(nm, enc, model, scope,
                                       verbose=verbose)
                    totals[(nm, enc, model, scope)] = r

    # ---- the delta + verdict table ----
    print("\nTHE D-1 DELTA TABLE (dense vs slot+image, reconciled model)")
    print("  %-14s %-15s %-12s %13s %13s %7s" %
          ("shape", "scope", "slack model", "slot+image B", "dense B",
           "delta"))
    for (nm, enc, model, scope) in list(totals):
        if enc != "slot+image":
            continue
        a = totals[(nm, "slot+image", model, scope)][0]
        b = totals[(nm, "dense", model, scope)][0]
        print("  %-14s %-15s %-12s %13s %13s %6.1f%%" %
              (nm[:14], scope, model, format(a, ","), format(b, ","),
               100.0 * (b - a) / a))
    print("\n  VERDICTS vs 262,144 B (pack lever applied in parens):")
    for k, (t, ex, sc) in totals.items():
        tp = t - ex["ep"]["pack_lever"]
        print("    %-58s %10s B %.2fx %s  (packed %s B %.2fx %s)" %
              ("/".join(k), format(t, ","), t / BUDGET,
               "PASS" if t <= BUDGET else "OVER",
               format(tp, ","), tp / BUDGET,
               "PASS" if tp <= BUDGET else "OVER"))

    # ---- sensitivities ----
    print("\nSENSITIVITIES at (FFN, dense, per-level, complete-layer) "
          "[MODEL]")
    base = totals[("FFN 512x11008", "dense", "per-level",
                   "complete-layer")][0]
    lo = artifact("FFN 512x11008", "dense", "per-level", "complete-layer",
                  n_entries=ENTRIES["complete-layer"][0],
                  requant_checks=1)[1]
    hi = artifact("FFN 512x11008", "dense", "per-level", "complete-layer",
                  n_entries=ENTRIES["complete-layer"][2],
                  requant_checks=2)[1]
    print("  entry/requant band (DB 10.1/10.2): %s .. %s B "
          "(%.2fx..%.2fx)" % (format(lo, ","), format(hi, ","),
                              lo / BUDGET, hi / BUDGET))
    s = SHAPES["FFN 512x11008"]
    second = s["kel"] * KEL_B
    print("  D-R1 range-arm witness CANNOT rho-share the SiLU descent: "
          "+%s B -> %s B (%.2fx)"
          % (format(second, ","), format(base + second, ","),
             (base + second) / BUDGET))
    _, ex, _ = totals[("FFN 512x11008", "dense", "per-level",
                       "complete-layer")]
    ep = ex["ep"]
    extra_proof = (ep["stop_level"] * ep["per_level_wire"]
                   + ex["jl_extra"] + ep["bare"] + 4 + 10 * POLY_B)
    print("  D-R2 each EXTRA eval proof (DB 10.2's 'up to 3'): ~+%s B "
          "-> budget-fatal; ONE batched opening across all claim "
          "domains is load-bearing (obligation E-O2)"
          % format(extra_proof, ","))

    # ---- pass numbers, O-8 floor, point families ----
    print("\n32-LAYER PASS NUMBERS (R1: state them; scope decided at "
          "FINAL)")
    for enc in ENCODINGS:
        t = totals[("FFN 512x11008", enc, "per-level",
                    "complete-layer")][0]
        print("  %-10s per-layer x 32 = %s B = %.2f MiB = %.1fx budget "
              "if per-pass" % (enc, format(32 * t, ","), 32 * t / 2**20,
                               32 * t / BUDGET))
    t, ex, sc = totals[("FFN 512x11008", "dense", "per-level",
                        "complete-layer")]
    per_layer_resid = ex["tr"] + ENTRIES["complete-layer"][1] * KEL_B
    o8_floor = 4096 + (t - per_layer_resid - 4096) + 32 * per_layer_resid
    print("  O-8 floor: with ONE descent pair + ONE eval proof for the "
          "pass, the 32 per-layer transcripts+entries alone are 32 x %s "
          "= %s B -> pass floor ~%s B (%.1fx) — the (b) accumulator "
          "must fold the INSTANCES, not just the openings [MODEL; "
          "folding design = U-AG4]"
          % (format(per_layer_resid, ","),
             format(32 * per_layer_resid, ","),
             format(o8_floor, ","), o8_floor / BUDGET))
    bat = ex["batch_rounds"]
    print("  point families (DA I-1 x DB list): all terminals merge in "
          "the ONE priced terminal-batch sumcheck (%d rounds = %s B — "
          "inside DA's 5.4-6.1 KiB/family price); families beyond it: 0"
          % (bat, format(bat * 3 * KEL_B, ",")))

    # ---- verifier / prover / knowledge error at the recommendation ----
    print("\nVERIFIER / PROVER / KNOWLEDGE ERROR at the D-1 "
          "recommendation [MODEL]")
    for nm in SHAPES:
        shp = SHAPES[nm]
        _, ex, sc = totals[(nm, "dense", "per-level", "ledger-unit")]
        tv = da.verifier_model(shp, sc, ex["kappa"])
        n_ring = ex["n_ring"]
        tp = da.prover_model(shp, n_ring, sc, ex["kappa"])
        ke = da.knowledge_error(sc, use_jl=True, jl_rows=512)
        print("  %-16s verify %.3f s 1T (slot-form DA row: %s); prover "
              "commit marginal %.1f us/el; post-FS 2^%.0f"
              % (nm, tv, "0.18 s" if nm == "2^20 layer" else "0.93 s",
                 tp, ke["post_fs"]))

    # ---- EB / EC exports ----
    print("\nEXPORTS")
    classes = value_classes("FFN 512x11008", "dense")
    nl1 = sum(c * max(1, math.ceil(b / 1)) for c, b in classes)
    gz1 = da.OP_CONC * math.sqrt(nl1 * D)
    print("  to EB (O-7): dense gamma_z floor (e=1) = 2^%.2f at FFN "
          "(slot form: 2^20.88); compounded L=2 budget 2^%.2f now HOSTS "
          "the level-0 fold (self-check C2) — the kill-switch's precise "
          "boundary (PARAMS_DESIGN 6.3) must be re-derived at dense: "
          "one-level-only no longer follows from the compounded lemma "
          "alone" % (math.log2(gz1),
                     math.log2(da.gamma_budget(31.0, "compounded", 1))))
    # the compounded byte floor at dense (PARAMS_DESIGN 6.3's 41.6 MB
    # re-run at the recommended encoding): depth-search like DA's
    kappa_c, _ = da.c3_kappa(28.0, 31.0)
    best_c = None
    for depth in range(1, 10):
        gm = da.gamma_budget(31.0, "compounded", depth - 1)
        if gm < 1.0:
            continue
        sc = schedule2(classes, 31.0, gm, kappa_c, max_levels=depth)
        if sc is None or not sc["stops"]:
            continue
        epc = eval_proof2(sc, kappa_c)
        # heavy lines only (descent+transcript etc. unchanged): reuse
        # the complete-layer fixed lines from the dense per-level run
        fixed = (4096 + 2 * (4 + kappa_c * POLY_B)
                 + SHAPES["FFN 512x11008"]["kel"] * KEL_B
                 + ex["tr"] + ENTRIES["complete-layer"][1] * KEL_B + 2048)
        tot = (fixed + epc["stop_level"] * epc["per_level_wire"]
               + 1024 * max(0, epc["stop_level"] - 1) + epc["bare"])
        if best_c is None or tot < best_c[0]:
            best_c = (tot, depth, epc)
    print("  to EB (O-7) cont.: compounded-reading byte floor at dense "
          "FFN = %s B (%.1fx budget; %d levels, %d-ring final witness) "
          "vs 41,593,548 B (158.67x) at slot form [MODEL] — the "
          "fallback boundary SOFTENS ~%.0fx but remains architecture-"
          "fail on bytes; EB owns the precise re-statement"
          % (format(best_c[0], ","), best_c[0] / BUDGET,
             len(schedule2(classes, 31.0,
                           da.gamma_budget(31.0, "compounded",
                                           best_c[1] - 1),
                           kappa_c, max_levels=best_c[1])["rows"]) - 1,
             best_c[2]["n_final"], 41_593_548 / best_c[0]))
    print("  to EC (O-4): dense kills the slot-junk channel (no junk "
          "coordinates exist); exposure surfaces stay the three of "
          "CLAIM_REDUCTION 11; T_blind unchanged (2^10-2^12 rings, "
          "31-bit class, in the aux value class); packing-image "
          "instances (slot+image only) would be one MORE masked "
          "sumcheck family — dense avoids the mask budget for them")

    print("\nALL DONE - %d/%d self-checks OK" % (n_ok, len(checks)))


if __name__ == "__main__":
    main()
