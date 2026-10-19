"""Round 7's negative controls for the FULL zero-data preimage of `A` and `H`.

Each control is shown to PASS on the honest capture first, and each must make
the construction REFUSE -- by name, at the thing that was moved.  A gate that
constructs a preimage for every view whatsoever measures nothing, so these
controls are the gate's own criterion (ruling C-6, and §8 of
`ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md`: equal fibre dimension is not a pass,
because the fibre may be EMPTY).

  P-1  one OPENED COLUMN entry moved by one          -> the pad half of some
                                                        combination stops being
                                                        divisible by `Z_S`
  P-2  one GROUP VECTOR entry moved, message half    -> the claim values cannot
                                                        be met inside the kernel
  P-3  one GROUP VECTOR entry moved, pad half        -> the `Z_S` divisibility
  P-4  one pad FEWER than the distinct opened columns-> the interpolant of the
                                                        required pad values has
                                                        too high a degree
  P-5  a blinding row SHARED between `A` and `H`     -> both per-commitment
                                                        preimages exist and force
                                                        DIFFERENT values on it
  P-6  a fixed input OFF `H`'s disclosed identity    -> no preimage before the
                                                        projection, a verified one
                                                        after: `H`'s disclosed 2
                                                        is a refusal, not a number

NOTHING IS WRITTEN TO ANY CAPTURE.  Every perturbation is applied to the
layout object this process built, never to a file, and the honest run is
re-taken afterwards from the untouched capture.
"""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import (  # noqa: E402
    F2_ZERO,
    P,
    f2_add,
    f2_mul_base,
    f2_sub,
)
from zk60_native_pg_pcs import solve_pair  # noqa: E402
from zk60_native_privacy_gate import PRG_BOUND, SEED, prg_row  # noqa: E402
from zk60_native_rg_ahpreimage import (  # noqa: E402
    WideRolePreimage,
    layout_for_view,
)


def _run(layout, data=None, pad_width=None):
    pre = WideRolePreimage(layout, data=data, pad_width=pad_width).build()
    return pre


def _honest(view, name):
    layout = layout_for_view(view, name=name)
    pre = _run(layout)
    ver = None if pre.fail else pre.verify()
    return layout, pre, ver


def _fires(pre, needle):
    return {
        "refused": bool(pre.fail),
        "refusal": pre.fail[0] if pre.fail else None,
        "refusal_names_the_step": bool(pre.fail) and needle in pre.fail[0],
    }


# ------------------------------------------------------------------ P-1
def p1_opened_column_entry(view, name):
    """One opened column entry moved by one: no preimage."""
    layout, pre, ver = _honest(view, name)
    honest_ok = not pre.fail and ver["all_entries_equal"]
    j = layout.nodes_j[0]
    row = layout.rows // 2
    moved = list(layout.colval[j])
    moved[row] = (moved[row] + 1) % P
    layout.colval[j] = moved
    bad = _run(layout)
    out = {
        "control": "P-1",
        "what": "one OPENED COLUMN entry of this commitment moved by one",
        "entry": {"column_index": j, "row": row},
        "honest_preimage_exhibited": bool(honest_ok),
        "honest_entries_compared": None if ver is None else ver["entries_compared"],
        **_fires(bad, "not reachable from the opened columns"),
        "why": "the row's pad polynomial is the interpolant through the d sampled "
        "nodes, so moving one opened value moves that row's pad by a Lagrange "
        "basis polynomial of degree d-1; every combination that reads the row "
        "then has a pad residual that Z_S (degree d) does not divide",
    }
    out["fires"] = out["refused"] and out["refusal_names_the_step"] and honest_ok
    return out


# ------------------------------------------------------------------ P-2
def p2_group_vector_message_entry(view, name):
    """One group-vector entry, message half, moved by one: no preimage."""
    layout, pre, ver = _honest(view, name)
    honest_ok = not pre.fail and ver["all_entries_equal"]
    gi = None
    pos = None
    for g in range(len(layout.groups)):
        cand = [t for t in range(layout.m) if layout.cw[g][t] != F2_ZERO]
        if cand:
            gi, pos = g, cand[0]
            break
    if gi is None:
        return {"control": "P-2", "fires": False,
                "skipped": "no group has a nonzero column weight"}
    moved = list(layout.gvec[gi])
    moved[pos] = ((moved[pos][0] + 1) % P, moved[pos][1])
    layout.gvec[gi] = moved
    bad = _run(layout)
    out = {
        "control": "P-2",
        "what": "one GROUP VECTOR entry moved by one, at a MESSAGE position the "
        "group's column key really reads",
        "entry": {"group": gi, "position": pos, "members": len(layout.groups[gi])},
        "honest_preimage_exhibited": bool(honest_ok),
        **_fires(bad, "cannot be met inside the kernel"),
        "why": "the anchor pair absorbs the moved entry, so the group VECTOR is "
        "still reproduced -- and then the verifier's own group identity "
        "<v_g, cw> = sum lambda*value no longer holds, and no correction inside "
        "the kernel of the vector constraint can change that sum.  This is the "
        "control that tests the gate's OWN criterion: a channel with no "
        "preimage must be reported as having none",
    }
    out["fires"] = out["refused"] and out["refusal_names_the_step"] and honest_ok
    return out


# ------------------------------------------------------------------ P-3
def p3_group_vector_pad_entry(view, name):
    """One group-vector entry, pad half, moved by one: no preimage."""
    layout, pre, ver = _honest(view, name)
    honest_ok = not pre.fail and ver["all_entries_equal"]
    gi = 0
    pos = layout.m  # the first PAD coefficient of the published vector
    moved = list(layout.gvec[gi])
    moved[pos] = ((moved[pos][0] + 1) % P, moved[pos][1])
    layout.gvec[gi] = moved
    bad = _run(layout)
    out = {
        "control": "P-3",
        "what": "one GROUP VECTOR entry moved by one, at the first PAD coefficient",
        "entry": {"group": gi, "pad_coefficient": 0},
        "honest_preimage_exhibited": bool(honest_ok),
        **_fires(bad, "not reachable from the opened columns"),
        "why": "the pads are already fixed at the d sampled nodes by the opened "
        "columns, so the only freedom left in the combination is a multiple of "
        "Z_S; a constant added to the residual is not one",
    }
    out["fires"] = out["refused"] and out["refusal_names_the_step"] and honest_ok
    return out


# ------------------------------------------------------------------ P-4
def p4_one_pad_fewer(view, name):
    """The commitment MODELLED with `d - 1` pads against `d` distinct columns."""
    layout, pre, ver = _honest(view, name)
    honest_ok = not pre.fail and ver["all_entries_equal"]
    bad = _run(layout, pad_width=layout.d - 1)
    out = {
        "control": "P-4",
        "what": f"the commitment modelled with {layout.d - 1} pad symbols against "
        f"{layout.d} distinct opened columns",
        "distinct_opened_columns": layout.d,
        "pads_modelled": layout.d - 1,
        "pads_the_receipt_has": layout.q,
        "honest_preimage_exhibited": bool(honest_ok),
        **_fires(bad, "cannot meet"),
        "why": "the required pad values at d distinct nodes determine an "
        "interpolant of degree d-1; a commitment with fewer than d pad symbols "
        "cannot carry it, and the refusal names the degree",
    }
    out["fires"] = out["refused"] and out["refusal_names_the_step"] and honest_ok
    return out


# ------------------------------------------------------------------ P-5
def _forced_pair(layout):
    """A group whose ONLY non-data support is its own anchor pair.

    For such a group the all-zero data leaves, at every message position, an
    invertible 2x2 system with a UNIQUE solution: the pair's values are
    FORCED, not chosen.  Returns `(group, pair)` or `None`.
    """
    for gi, rho in enumerate(layout.rhos):
        pair = layout.anchor[gi]
        if pair is None or layout.group_rows[gi] != sorted(pair):
            continue
        if set(pair) & set(layout.u_rows):
            continue  # a u row carries a public constraint: it is not free
        support = {
            i for i in range(layout.rows)
            if rho[i] != F2_ZERO and i not in layout.data_rows
        }
        if support == set(pair) and not layout.gkernel[gi]:
            return gi, pair
    return None


def p5_shared_blinding_row(view_a, view_h, name_a, name_h):
    """One reserved mask row of `A` and one of `H` declared the SAME unknown."""
    la, pa, va = _honest(view_a, name_a)
    lh, ph, vh = _honest(view_h, name_h)
    honest_ok = (
        not pa.fail and not ph.fail
        and va["all_entries_equal"] and vh["all_entries_equal"]
    )
    fa, fh = _forced_pair(la), _forced_pair(lh)
    if fa is None or fh is None:
        return {
            "control": "P-5",
            "fires": False,
            "applicable": False,
            "skipped": "no group of this commitment has its anchor pair as its "
            "only non-data support with an empty correction kernel, so no row's "
            "value is FORCED by this commitment alone and the control would "
            "claim more than it shows",
            "honest_preimage_exhibited": bool(honest_ok),
        }
    (ga, pair_a), (gh, pair_h) = fa, fh
    ra, rh = pair_a[0], pair_h[0]
    n = min(la.m, lh.m)
    differ = [t for t in range(n) if pa.X[ra][t] != ph.X[rh][t]]
    out = {
        "control": "P-5",
        "applicable": True,
        "what": f"the reserved mask row {ra} of {name_a} (group {ga}) and row "
        f"{rh} of {name_h} (group {gh}) declared the SAME blinding unknown",
        "each_row_is_forced_by_its_own_commitment": True,
        "why_forced": "each is the anchor of a group whose only non-data support "
        "is that pair and whose correction kernel is empty, so with the data at "
        "zero its value at every message position is the unique solution of an "
        "invertible 2x2 system",
        "honest_preimage_exhibited": bool(honest_ok),
        "message_positions_compared": n,
        "positions_where_the_two_forced_values_differ": len(differ),
        "first_position_that_differs": differ[0] if differ else None,
        "joint_preimage_exists": not differ,
        "why": "both per-commitment preimages exist, and they force DIFFERENT "
        "values on the shared unknown: no JOINT preimage exists.  This is the "
        "case a per-commitment acceptance cannot see, and it is why the run "
        "gate's joint figures (ruling R-3) are not evidence of independent "
        "blinding",
    }
    out["fires"] = bool(differ) and honest_ok
    return out


# ------------------------------------------------------------------ P-6
def _project_onto_disclosed(layout, data):
    """Move a fixed input onto the public identity `H`'s view discloses.

    Derived from `zk60_native_privacy_gate.project_onto_disclosed`, with the
    message width read from the layout instead of the toy's `MSG`.  The only
    such identity at these layouts is `H`'s LogUp sum claim: the zsum slot's
    group reads the `u` pair, whose message sums to zero by the layout's
    public linear constraint, so the view DETERMINES
    `sum_i rw[i] (row sum of i)` over the data rows, and no fixed input off
    that plane has a preimage.  The correction is a public function of the
    capture.
    """
    out = {"identities": [], "applied": False}
    if not layout.u_rows:
        return out
    m = layout.m
    for gi, _members in enumerate(layout.groups):
        if not (set(layout.group_rows[gi]) & set(layout.u_rows)):
            continue
        rho = layout.rhos[gi]
        want = F2_ZERO
        for t in range(m):
            want = f2_add(want, layout.gvec[gi][t])
        got = F2_ZERO
        for i in layout.data_rows:
            if rho[i] == F2_ZERO:
                continue
            s = sum(data.get(i, [0] * m)) % P
            if s:
                got = f2_add(got, f2_mul_base(rho[i], s))
        residual = f2_sub(want, got)
        pick = None
        for a in range(len(layout.data_rows)):
            for b in range(a + 1, len(layout.data_rows)):
                i1, i2 = layout.data_rows[a], layout.data_rows[b]
                if solve_pair(rho[i1], rho[i2], residual) is not None:
                    pick = (i1, i2)
                    break
            if pick:
                break
        entry = {
            "group": gi,
            "identity": "the LogUp sum claim: the view determines sum over data "
            "rows of rw[i] * (row sum), and the published value is 0",
            "residual_before": [residual[0], residual[1]],
            "already_satisfied": residual == F2_ZERO,
        }
        if residual != F2_ZERO and pick:
            d1, d2 = solve_pair(rho[pick[0]], rho[pick[1]], residual)
            for i, delta in zip(pick, (d1, d2)):
                row = list(data.get(i, [0] * m))
                row[0] = (row[0] + delta) % P
                data[i] = row
            entry.update({"corrected_rows": list(pick), "applied": True})
            out["applied"] = True
        out["identities"].append(entry)
    return out


def p6_off_the_disclosed_identity(view, name, profile):
    """A SECOND fixed input on `H`, before and after the projection."""
    layout = layout_for_view(view, name=name)
    if not layout.u_rows:
        return {"control": "P-6", "fires": False, "applicable": False,
                "skipped": "this commitment declares no public linear constraint, "
                "so it discloses no identity a fixed input could sit off"}
    data = {
        i: prg_row(profile, name, i, width=layout.m, bound=PRG_BOUND)
        for i in layout.data_rows
    }
    before = _run(layout, data={k: list(v) for k, v in data.items()})
    bver = None if before.fail else before.verify()
    proj = _project_onto_disclosed(layout, data)
    after = _run(layout, data=data)
    aver = None if after.fail else after.verify()
    out = {
        "control": "P-6",
        "applicable": True,
        "what": "a SECOND fixed input -- a public, deterministic, in-range "
        f"pseudorandom one from the seed {SEED!r} -- on every data row of {name}, "
        "before and after projection onto the identity the view discloses",
        "u_rows": list(layout.u_rows),
        "projection": proj,
        "before_projection": {
            "solved": not before.fail,
            "refusal": before.fail[0] if before.fail else None,
            "all_entries_equal": None if bver is None else bver["all_entries_equal"],
        },
        "after_projection": {
            "solved": not after.fail,
            "refusal": after.fail[0] if after.fail else None,
            "all_entries_equal": None if aver is None else aver["all_entries_equal"],
            "entries_compared": None if aver is None else aver["entries_compared"],
        },
        "why": "H's disclosed dimension of 2 is exactly this identity.  A fixed "
        "input off it has NO preimage -- the disclosed dimension shows up as a "
        "REFUSAL, not as a number -- and the same input projected onto it has "
        "one, verified entry by entry.  The all-zero input is ON the identity "
        "because the published LogUp sum is zero, which is why round 7's honest "
        "case is feasible at all",
    }
    out["fires"] = bool(
        before.fail
        and not after.fail
        and aver is not None
        and aver["all_entries_equal"]
    )
    return out


# ------------------------------------------------------------------ driver
def ah_controls(bundle, views, a_name="A@0", h_name="H@0"):
    """Every round-7 control, on one stage's `A` and `H`."""
    va, vh = views[a_name], views[h_name]
    profile = bundle.run["shape"]["profile"]
    ctl = [
        p1_opened_column_entry(vh, h_name),
        p2_group_vector_message_entry(va, a_name),
        p3_group_vector_pad_entry(vh, h_name),
        p4_one_pad_fewer(vh, h_name),
        p5_shared_blinding_row(va, vh, a_name, h_name),
        p6_off_the_disclosed_identity(vh, h_name, profile),
    ]
    applicable = [c for c in ctl if c.get("applicable", True)]
    return {
        "what": "each control is shown to pass on the honest capture first, and "
        "each must make the construction refuse by name at the thing that moved",
        "on": {"A": a_name, "H": h_name},
        "nothing_on_disk_was_written": True,
        "controls": ctl,
        "controls_total": len(ctl),
        "controls_applicable": len(applicable),
        "controls_that_fire": sum(1 for c in ctl if c.get("fires")),
        "not_applicable": [c["control"] for c in ctl if not c.get("applicable", True)],
        # [v5, review P-11] a family with no applicable control is not a pass
        "ok": bool(applicable) and all(c.get("fires") for c in applicable),
    }
