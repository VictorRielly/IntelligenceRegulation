#!/usr/bin/env python3
"""**Round 8's negative controls** for the masking commitment `M` and the
masked-sumcheck (CFS) channel at the shaped layouts.

A control that cannot fire at an honest capture measures nothing, so every
entry here records the HONEST verdict beside the perturbed one, and the
gate's own criterion is what each control tests: if the construction
returned something for every view whatsoever, "constructed" would be an
empty word.

**Nothing on disk is written.**  Every perturbation is applied to a SHADOW
of the stage built in memory -- a shallow copy of the stage's `arguments`
and `mask` with exactly the one field replaced -- and a test re-digests the
bundle directory afterwards to show that no captured byte moved.

The six:

  M-1  one published masked ROUND value moved by one          -> no coefficients
  M-2  one entry of one OPENED COLUMN of `M` moved by one     -> no preimage
  M-3  the functionals' declared ORDER permuted               -> two refusals
  M-4  a slot's mask LENGTH declared one short (slots 08, 09) -> refused
  M-5  one mask coefficient SHARED between two slots          -> the rank moves
  M-6  one PAD fewer than the distinct opened columns         -> no preimage

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY.
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import (  # noqa: E402
    P,
    f2_from_list,
    f2_is_zero,
    f2_sub,
)
from zk60_native_mask_commit import (  # noqa: E402
    MASK_Q,
    MaskModel,
    MaskPreimage,
    combined_weights,
    mask_len,
)
from zk60_native_pg_cfs import CfsPreimage  # noqa: E402
from zk60_native_rg_mask import (  # noqa: E402
    StageReplay,
    batched_value,
    disclosed_with_identification,
    joined_coefficients,
    permuted_weights,
    shaped_mask_model,
)

__all__ = ["mask_controls_at_shape"]


# ------------------------------------------------------------- the shadow
class _Shadow:
    """One stage with exactly one published field replaced, in memory.

    `mask` and `slots` are the only two surfaces the mask and CFS ports
    read, so the shadow copies those two and nothing else.  The original
    stage object is never mutated, and no file is opened.
    """

    def __init__(self, stage, mask=None, slots=None):
        self._stage = stage
        self.mask = mask if mask is not None else stage.mask
        self.slots = slots if slots is not None else stage.slots
        self.doc = dict(stage.doc)
        self.doc["arguments"] = self.slots
        self.doc["mask"] = self.mask
        self.name = getattr(stage, "name", None)


def _slots_with_round_moved(stage, s, j, x):
    """A copy of `arguments` with round `j`, point `x` of slot `s` moved by 1."""
    slots = list(stage.slots)
    arg = dict(slots[s])
    rounds = [list(r) for r in arg["rounds"]]
    val = list(rounds[j][x])
    val[0] = (val[0] + 1) % P
    rounds[j][x] = val
    arg["rounds"] = rounds
    slots[s] = arg
    return slots


def _mask_with_column_entry_moved(stage, col_pos, row):
    """A copy of `mask` with one entry of one opened column moved by 1."""
    m = dict(stage.mask)
    cols = list(m["columns"])
    c = dict(cols[col_pos])
    vals = list(c["values"])
    vals[row] = (vals[row] + 1) % P
    c["values"] = vals
    cols[col_pos] = c
    m["columns"] = cols
    return m


# ------------------------------------------------------------ M-1 helpers
def _infeasible_round(cp, s, data):
    """WHICH round makes slot `s` infeasible, found by arithmetic.

    The solver's own refusal names the slot.  This names the ROUND: the
    slot's system is re-solved with each round's `degree + 1` equations
    dropped in turn, and the round whose removal makes it feasible is the
    one the perturbation moved.  Nothing about the control's own knowledge
    enters -- the answer comes from the system.
    """
    from zk60_native_jv_field import solve
    from zk60_native_pg_cfs import f2_target, fp_columns

    arg = cp.slots[s]
    L = mask_len(*cp.specs[s])
    c = cp.c[s]
    if f2_is_zero(c):
        return None
    from zk60_native_jv_field import f2_inv, f2_mul

    ci = f2_inv(c)
    h, sigma = data
    freed = []
    for drop in range(len(arg["rounds"])):
        rows, targets, idx = [], [], 0
        for j, rnd in enumerate(arg["rounds"]):
            for x, v in enumerate(rnd):
                if j != drop:
                    rows.append(cp.R[s][idx])
                    targets.append(f2_mul(f2_sub(f2_from_list(v), h[j][x]), ci))
                idx += 1
        rows.append(cp.W[s])
        targets.append(f2_mul(f2_sub(f2_from_list(arg["scalar"]), sigma), ci))
        got, _ = solve(fp_columns(rows, L), f2_target(targets))
        if got is not None:
            freed.append(drop)
    return freed


# ---------------------------------------------------------------- the run
def mask_controls_at_shape(bundle, replay, k=0, columns=8,
                           permute=(0, 1), leak=(0, 1)) -> dict:
    """The six controls on one stage of one bundle."""
    stage = bundle.stages[k]
    acc = replay.stages[k]
    mm = shaped_mask_model(stage, acc)
    out = {
        "bundle": bundle.name,
        "stage": k,
        "nothing_written": "every perturbation is applied to an in-memory "
        "shadow of the stage; no captured byte is touched",
    }

    # ---------------------------------------------------------- honest
    cp, coef, cfs = joined_coefficients(stage, acc, which="all")
    honest_pre = MaskPreimage(mm, coef).build()
    honest_ver = honest_pre.verify(columns="full")
    honest_cfs = cp.verify()
    out["honest"] = {
        "cfs_round_entries": honest_cfs["round_entries"],
        "cfs_round_mismatches": honest_cfs["round_mismatches"],
        "cfs_scalar_mismatches": honest_cfs["scalar_mismatches"],
        "M_preimage_exhibited": honest_ver["all_entries_equal"],
        "M_column_entries": honest_ver["column_entries"],
        "M_column_mismatches": honest_ver["column_mismatches"],
        "b_admissible": honest_ver["b_admissible"],
    }
    honest_ok = bool(honest_cfs["all_entries_equal"] and honest_ver["all_entries_equal"])

    # ---------------- M-1: one published masked round value moved by one
    s1, j1, x1 = 0, 0, 0
    sh = _Shadow(stage, slots=_slots_with_round_moved(stage, s1, j1, x1))
    cp1 = CfsPreimage(sh, StageReplay(acc))
    got1 = cp1.run(fixed="zero")
    freed = None
    if got1 is None:
        cp0 = CfsPreimage(sh, StageReplay(acc))
        data = cp0.flat_transcript(s1)
        freed = _infeasible_round(cp0, s1, data)
    out["M1_one_masked_round_value_moved"] = {
        "what": f"the published masked round message of slot {s1:02d}, round "
        f"{j1}, evaluation point {x1}, moved by one in its real part",
        "honest_passes": honest_ok,
        "refusal": cp1.findings[0] if cp1.findings else None,
        "slot_named_by_the_solver": s1 if cp1.findings else None,
        "rounds_whose_removal_restores_feasibility": freed,
        "round_named_by_the_arithmetic": (freed[0] if freed and len(freed) == 1 else None),
        "fires": bool(got1 is None and freed == [j1]),
        "why": "the slot's system is OVERDETERMINED -- (rounds x (degree+1) + "
        "1) Fp2 equations against L Fp2 unknowns -- and the published rounds "
        "lie in its image only because they were MADE by adding c_s g_s to an "
        "honest transcript.  Moving one entry leaves that image, and no mask "
        "coefficients reproduce it.  The round is named by re-solving with "
        "each round's equations dropped in turn",
    }

    # -------------- M-2: one entry of one opened column of M moved by one
    b_row = 2 * mm.S  # the b_re row: forced by q, not free
    idx_counts = {}
    for i, c in enumerate(stage.mask["columns"]):
        idx_counts.setdefault(c["index"], []).append(i)
    unique_pos = next(i for i, c in enumerate(stage.mask["columns"])
                      if len(idx_counts[c["index"]]) == 1)
    shb = _Shadow(stage, mask=_mask_with_column_entry_moved(stage, unique_pos, b_row))
    mmb = MaskModel(shb, StageReplay(acc))
    preb = MaskPreimage(mmb, coef).build()
    verb = preb.verify(columns="full") if preb.ok else {}
    a_row = 0
    sha = _Shadow(stage, mask=_mask_with_column_entry_moved(stage, unique_pos, a_row))
    mma = MaskModel(sha, StageReplay(acc))
    prea = MaskPreimage(mma, coef).build()
    vera = prea.verify(columns="full") if prea.ok else {}
    out["M2_one_opened_column_entry_moved"] = {
        "what": f"one entry of the opened column at position {unique_pos} "
        f"(a node sampled exactly once), moved by one",
        "honest_passes": honest_ok,
        "at_a_b_row": {
            "row": b_row,
            "column_mismatches": verb.get("column_mismatches"),
            "first_mismatch": verb.get("first_column_mismatch"),
            "preimage_exhibited": verb.get("all_entries_equal"),
            "fires": bool(verb.get("column_mismatches")),
        },
        "at_an_a_row": {
            "row": a_row,
            "column_mismatches": vera.get("column_mismatches"),
            "first_mismatch": vera.get("first_column_mismatch"),
            "preimage_exhibited": vera.get("all_entries_equal"),
            "fires": bool(vera.get("column_mismatches")),
            "where_it_fires": "NOT on the a-row itself: the a-rows carry "
            f"Q = {MASK_Q} pads against {mm.D} distinct sampled nodes, so "
            "their Cauchy block is square and nonsingular and the pads absorb "
            "the moved target exactly.  It fires on the FOUR rows below -- "
            "b_re, b_im, u_re, u_im, at that one column and at no other -- "
            "because b is the residue of q and u the residue of the "
            "proximity vector: absorbing the move on the a-row moves the "
            "verifier's per-column identity at that node, and the capture's "
            "own b and u entries there contradict it.  The pads buy the "
            "a-row and pay for it four rows down",
        },
        "fires": bool(verb.get("column_mismatches") and vera.get("column_mismatches")),
        "why": "the b and u rows are not free: b is forced by q and u by the "
        "proximity vector, so their column values are determined once the "
        "a-rows are.  A moved entry on one of them cannot be met, and a moved "
        "entry on an a-row cannot be met either -- it reappears on them",
    }

    # ------------------- M-3: the functionals' declared order permuted
    i, j = permute
    fns, ws_p, v_p, fail_p = permuted_weights(mm, i, j)
    p1 = MaskPreimage(mm, coef, functionals=fns).build()
    v1 = p1.verify(columns=columns)
    onplane = [list(r) for r in coef]
    # move ONE coefficient so the PERMUTED batch hits the captured sum
    from zk60_native_jv_field import f2_add, f2_inv, f2_mul

    got_v = batched_value(mm, onplane, ws=ws_p)
    placed = None
    for s in range(mm.S):
        for t in range(mm.L[s]):
            if not f2_is_zero(ws_p[s][t]):
                onplane[s][t] = f2_add(
                    onplane[s][t],
                    f2_mul(f2_sub(mm.v, got_v), f2_inv(ws_p[s][t])),
                )
                placed = {"slot": s, "index": t}
                break
        if placed:
            break
    p2 = MaskPreimage(mm, onplane, functionals=fns).build()
    v2 = p2.verify(columns="full")
    out["M3_declared_functional_order_permuted"] = {
        "what": f"functionals {i} and {j} of the DECLARED order swapped, so "
        "each takes the other's power of theta",
        "honest_passes": honest_ok,
        "batched_value_changed": v_p != mm.v,
        "same_coefficients_b_admissible": v1["b_admissible"],
        "same_coefficients_fires": not v1["all_entries_equal"],
        "forced_onto_the_permuted_plane_at": placed,
        "forced_b_admissible": v2["b_admissible"],
        "forced_column_entries": v2["column_entries"],
        "forced_column_mismatches": v2["column_mismatches"],
        "forced_first_mismatch": v2["first_column_mismatch"],
        "forced_fires": not v2["all_entries_equal"],
        "fires": bool(
            (not v1["all_entries_equal"])
            and (not v2["all_entries_equal"])
            and v2["b_admissible"]
        ),
        "why": "the first flavour fails b's zero sum: the permuted batch is a "
        "different functional of the same coefficients.  The second removes "
        "that excuse by forcing the coefficients onto the PERMUTED plane -- b "
        "is then admissible and the view STILL has no preimage, because the "
        "verifier's per-column identity acc = sum_s a_s(x) W_s(x) + b(x) reads "
        "the weights themselves.  The order is pinned by the columns, not only "
        "by the scalar sum",
    }

    # ------------- M-4: a slot's mask length declared one short (08, 09)
    bilinear = [
        s for s, (_m, e, _d) in enumerate(bundle.run["shape"]["slots"]) if e == 2
    ]
    per_slot = []
    for s in bilinear:
        short = shaped_mask_model(stage, acc)
        short.L = list(short.L)
        short.L[s] -= 1
        sh_rec = short.shape()
        cshort = [list(r) for r in coef]
        cshort[s] = cshort[s][: short.L[s]]
        pshort = MaskPreimage(short, cshort).build()
        vshort = pshort.verify(columns=columns) if pshort.ok else {}
        # the Rust's own guard: a spec one VARIABLE short makes
        # `combined_weights` refuse by name at every functional of that slot
        specs = list(mm.specs)
        specs[s] = (specs[s][0] - 1, specs[s][1])
        _ws, _v, fails = combined_weights(specs, mm.m["functionals"], mm.theta)
        per_slot.append(
            {
                "slot": s,
                "true_L": mm.L[s],
                "declared_L": short.L[s],
                "weights_vanish_above_L": sh_rec["weights_vanish_above_L"],
                "shape_refused": not sh_rec["ok"],
                "shape_failed_on": sh_rec["failed"],
                "b_admissible": vshort.get("b_admissible"),
                "preimage_exhibited": vshort.get("all_entries_equal"),
                "spec_one_variable_short_refusals": len(fails),
                "spec_refusal_example": fails[0] if fails else None,
                "fires": bool(
                    (not sh_rec["ok"])
                    and not vshort.get("all_entries_equal")
                    and fails
                ),
            }
        )
    out["M4_a_slot_mask_length_declared_one_short"] = {
        "what": "each of the two REPAIRED BILINEAR slots (extension rounds 2, "
        "degree 3) modelled with one coefficient fewer than "
        "CfsMask::len(n, d) gives it",
        "honest_passes": honest_ok,
        "bilinear_slots": bilinear,
        "per_slot": per_slot,
        "fires": bool(per_slot) and all(e["fires"] for e in per_slot),
        "why": "two independent things refuse.  (a) The batched weight table "
        "does not vanish above the DECLARED length, which is the shape check "
        "`weights_vanish_above_L` -- and that check is the whole of the "
        "argument that the pads drop out of V(a).  (b) With one coefficient "
        "moved into the pad region V(a) changes and b is inadmissible.  A "
        "spec one VARIABLE short is refused a third way, by "
        "`combined_weights`'s own length assert, which is the Rust's",
    }

    # ---------- M-5: one mask coefficient shared between two slots
    sa, sb = (bilinear[0], bilinear[1]) if len(bilinear) > 1 else (0, 1)
    ca, kera, _ = cp.solve_slot(sa, *cp.data[sa])
    cb, kerb, _ = cp.solve_slot(sb, *cp.data[sb])
    # a coordinate where BOTH slots' rounds leave the coefficient free, and
    # one where BOTH force it -- both found by arithmetic, not chosen
    Lmin = min(len(ca), len(cb))
    free_t = next(
        (t for t in range(Lmin) if _reachable(kera, t) and _reachable(kerb, t)), None
    )
    forced_t = next(
        (t for t in range(Lmin)
         if not _reachable(kera, t) and not _reachable(kerb, t)),
        None,
    )
    base = disclosed_with_identification(mm, [])
    flavours = {}
    for label, t in (("free_coordinate", free_t), ("forced_coordinate", forced_t)):
        if t is None:
            flavours[label] = {"exists": False}
            continue
        ident = disclosed_with_identification(mm, [((sa, t), (sb, t))])
        reach = _reachable(kera, t) + _reachable(kerb, t)
        diff = f2_sub(ca[t], cb[t])
        flavours[label] = {
            "exists": True,
            "coefficient_index": t,
            "slot_a_free_fp_there": len(_reachable(kera, t)),
            "slot_b_free_fp_there": len(_reachable(kerb, t)),
            "the_two_forced_values_differ": not f2_is_zero(diff),
            "the_two_slots_can_agree_there": _in_span(reach, diff),
            "coefficient_unknowns_fp_after": ident["coefficient_unknowns_fp"],
            "disclosed_fp_after": ident["disclosed_fp_computed"],
            "fibre_fp_after": ident["fibre_dimension_fp"],
        }
    out["M5_one_coefficient_shared_between_two_slots"] = {
        "what": f"one mask coefficient of slot {sa:02d} and the coefficient "
        f"at the same index of slot {sb:02d} declared to be ONE unknown "
        "(synthetic: the honest layout shares none).  Two coordinates are "
        "used, and which is which is COMPUTED from the two slots' kernels",
        "honest_passes": honest_ok,
        "slots": [sa, sb],
        "rank_statement": {
            "coefficient_unknowns_fp_before": base["coefficient_unknowns_fp"],
            "disclosed_fp_before": base["disclosed_fp_computed"],
            "fibre_fp_before": base["fibre_dimension_fp"],
        },
        "flavours": flavours,
        "what_it_discloses": "M's OWN disclosed dimension does not move: it is "
        "one Fp2 functional of whatever unknown space there is, so identifying "
        "two coordinates leaves it at 2 Fp while the unknown space and the "
        "fibre each lose exactly 2 Fp.  The disclosure that moves is on the "
        "CFS side, and only at a coordinate the two slots' rounds each FORCE: "
        "there the shared unknown must take two different values at once and "
        "there is no joint solution.  That is the masking layer's form of "
        "round 7's control P-5 -- per-slot solutions exist and a joint one "
        "does not -- and it is why 'per commitment' and 'per slot' are not "
        "the same word as 'per run'",
        "fires": bool(
            flavours.get("forced_coordinate", {}).get("exists")
            and not flavours["forced_coordinate"]["the_two_slots_can_agree_there"]
            and flavours["forced_coordinate"]["coefficient_unknowns_fp_after"]
            == base["coefficient_unknowns_fp"] - 2
            and flavours["forced_coordinate"]["disclosed_fp_after"]
            == base["disclosed_fp_computed"]
        ),
        "why": "at a FREE coordinate each slot has a whole Fp2 of freedom "
        "there and the identification is satisfiable, which the record says "
        "rather than hides; at a FORCED one neither has any and the two "
        "values differ, so no assignment satisfies both slots at once",
    }

    # ------------- M-6: one pad fewer than the distinct opened columns
    w = mm.D - 1
    pre6 = MaskPreimage(mm, coef, pad_width=w).build()
    ver6 = pre6.verify(columns="full") if pre6.ok else {"column_mismatches": None}
    out["M6_one_pad_fewer_than_the_distinct_opened_columns"] = {
        "what": f"every a-row of M modelled with {w} pads against {mm.D} "
        f"distinct opened columns (the real budget is {MASK_Q}, margin "
        f"{MASK_Q - mm.D})",
        "honest_passes": honest_ok,
        "column_entries": ver6.get("column_entries"),
        "column_mismatches": ver6.get("column_mismatches"),
        "b_admissible": ver6.get("b_admissible"),
        "fires": bool(ver6.get("column_mismatches")),
        "why": "with fewer pad symbols than distinct opened columns the "
        "a-row's message cannot meet the captured column values at every "
        "sampled node, so the view leaves the image of the blinding map.  "
        "This is the control on the side that CAN fail: at the real budget "
        "the Cauchy block is square and nonsingular and every admissible "
        "coefficient vector on the V plane has a preimage",
    }

    names = [k2 for k2 in out if k2.startswith("M") and isinstance(out[k2], dict)
             and "fires" in out[k2]]
    out["control_names"] = names
    out["all_fire"] = all(out[k2]["fires"] for k2 in names)
    out["ok"] = bool(out["all_fire"] and honest_ok)
    return out


def _reachable(ker, t):
    """The Fp-span of coordinate `t` (an Fp2 unknown) over a kernel basis."""
    vecs = []
    for kvec in ker:
        v = (kvec[2 * t] % P, kvec[2 * t + 1] % P)
        if v != (0, 0):
            vecs.append(v)
    return vecs


def _in_span(vecs, target):
    """Is `target` in the Fp-span of `vecs` (both Fp^2)?  Exact, by rank."""
    from zk60_native_jv_field import rank

    if target == (0, 0):
        return True
    rows = [list(v) for v in vecs]
    r0 = rank(rows, 2) if rows else 0
    r1 = rank(rows + [list(target)], 2)
    return r0 == r1
