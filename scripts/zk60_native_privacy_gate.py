#!/usr/bin/env python3
"""The block-scope privacy gate P10: a preimage EXHIBITED, channel by channel.

    python3 scripts/zk60_native_privacy_gate.py \
      --captures results/zk60_native_captures_20260919 \
      --evidence results/zk60_native_privacy_gate

Definition: `docs/zkmatrix-poc/ZK60_PRIVACY_CASE_FIRST_MVP.md` section 4 (the
gate, rewritten under ruling C-6), section 2 (the view, channel by channel),
and `ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md` section 8 (why equal fibre
dimension is not a pass, and the two controls that test this gate's own
criterion).  Report: `docs/zkmatrix-poc/ZK60_NATIVE_PRIVACY_GATE.md`.

WHAT IT DOES, in one paragraph.  For each of the four captured receipts it
replays the transcript, then for TWO fixed hidden inputs -- the all-zero one
and a pseudorandom one derived from a public seed -- it SOLVES exactly over
the Goldilocks field for prover randomness (pads, mask rows, reserved pairs,
CFS mask coefficients) that reproduces the captured view, RECOMPUTES the view
from that randomness and compares it with the capture entry by entry, and
reports, for every channel of the privacy case's section 2, one of four
labels: CONSTRUCTED (a preimage was exhibited and verified), DERIVED (a
deterministic public function of other channels, named and recomputed),
ARGUED (the hash layer, with the assumption written out), OPEN (the gate
cannot speak, with the reason).

WHAT IT IS NOT.  It is not a privacy acceptance and establishes no privacy
property.  It is a statement about the LINEAR channels of four captured
receipts at two toy layouts.  The hash layer is argued, not computed; the
composition of the channels into one distribution (open item U-3b) and any
nonlinear functional of the view are untouched.

FAIL RULES (section 4.2, machine-readable form):
  * a `constructed` channel with `preimage_exhibited` false or null;
  * a `constructed` channel whose recomputed view differs from the capture;
  * a channel of section 2 missing from the `channels` array, or carrying no
    status;
  * an `argued` channel naming no assumption -- silence on the hash layer is
    a fail, not a pass;
  * an `open` channel absent;
  * a negative control that does not fire, or that fires on the honest
    capture.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_capture import (  # noqa: E402
    ManifestRefusal,
    load_all,
    manifest_check,
)
from zk60_native_jv_cfs import CfsView, terminal_identity  # noqa: E402
from zk60_native_jv_field import F2_ZERO, P, f2_add, f2_mul_base, f2_sub  # noqa: E402
from zk60_native_jv_joint import singleton_pair_rows  # noqa: E402
from zk60_native_jv_pcs import RoleView  # noqa: E402
from zk60_native_jv_replay import Replay  # noqa: E402
# [ROUND 9f] the two Cargo manifests that decide whether the test-only
# observers can compile into a release build (pre-read finding P36-2).
from zk60_native_manifest_pins import (  # noqa: E402
    ManifestPinError,
    check_manifest_pins,
)
# [ROUND 9h] the three files on the PRIVATE ATTENTION profile's path that no
# pin table named, while two of the four captures of record are attention
# receipts (ledger section R9h).
from zk60_native_profile_pins import (  # noqa: E402
    ProfilePinError,
    check_profile_pins,
)
from zk60_native_mask_commit import (  # noqa: E402
    MaskModel,
    MaskPreimage,
    check_source_pins,
    declared_functional_order,
    disclosed_dimension,
    force_functional,
    mask_controls,
    synthetic_coefficients,
)
from zk60_native_pg_cfs import CfsPreimage  # noqa: E402
from zk60_native_pg_pcs import MSG, RoleLayout, RolePreimage, solve_pair  # noqa: E402

TOOLS = [
    "zk60_native_privacy_gate.py",
    "zk60_native_pg_pcs.py",
    "zk60_native_pg_cfs.py",
    "zk60_native_mask_commit.py",
    # [ROUND 9f] the Cargo-manifest pins and their content assertion
    "zk60_native_manifest_pins.py",
    # [ROUND 9h] the private-attention profile's three path pins
    "zk60_native_profile_pins.py",
    "zk60_native_jv_field.py",
    "zk60_native_jv_capture.py",
    "zk60_native_jv_replay.py",
    "zk60_native_jv_pcs.py",
    "zk60_native_jv_cfs.py",
]

SEED = "zk60-privacy-gate/fixed-input/v1"
PRG_BOUND = 256  # the second fixed input's declared range, 0 .. 255

# The component's zero-witness acceptance test, cited and NOT run here.
ZERO_WITNESS_TEST = {
    "what": "the component's zero-witness acceptance test the gate's definition "
    "refers to (ZK60_PRIVACY_CASE_FIRST_MVP.md section 4.5, obligation U-4)",
    "where": "hashline/src/private_block/zero_witness_tests.rs, branch "
    "zk60-private-block-125m, commit ec84dac",
    "what_it_pins": "the all-zero hidden input proves and verifies on the toy "
    "profile; NORM_CEPS == 1; the exponential table's first entry as a constructor "
    "refusal; the two range boundaries (16,383 of an exclusive 16,384 and 512 of an "
    "inclusive 512); the zero-witness receipt is 2,816,472 bytes, like the fixture's",
    "run_by_this_gate": False,
    "why_not": "this lane is Python-only and does not build Rust; the test is cited "
    "as the precondition it is, on the security owner's record "
    "(ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md section 3, step 1, 2026-09-20 00:36)",
}


def tool_hashes():
    out = {}
    for t in TOOLS:
        with open(os.path.join(HERE, t), "rb") as fh:
            out[t] = hashlib.sha256(fh.read()).hexdigest()
    return out


# --------------------------------------------------------- the fixed inputs
def prg_row(profile, role, row, width=MSG, bound=PRG_BOUND):
    """A public, deterministic, in-range row: no witness is read or invented."""
    vals, blk = [], 0
    while len(vals) < width:
        h = hashlib.sha256(f"{SEED}|{profile}|{role}|{row}|{blk}".encode()).digest()
        for k in range(0, 32, 4):
            if len(vals) < width:
                vals.append(int.from_bytes(h[k : k + 4], "little") % bound)
        blk += 1
    return vals


def fixed_input(kind, layout, profile):
    if kind == "zero":
        return {}
    return {i: prg_row(profile, layout.name, i) for i in layout.data_rows}


def project_onto_disclosed(layout, data):
    """Move a fixed input onto the public identities the view discloses.

    The only such identity at these layouts is H's LogUp sum claim: the zsum
    slot's group reads the u pair, whose message sums to zero by the layout's
    public linear constraint, so the view determines `sum_i rw[i] rowsum_i`
    over the DATA rows and no fixed input off that plane has a preimage.  The
    correction is a public function of the capture: two data rows whose row
    weights are an Fp-basis of Fp2 absorb the residual.
    """
    out = {"identities": [], "applied": False}
    if not layout.u_rows:
        return out
    for gi, members in enumerate(layout.groups):
        if not (set(layout.group_rows[gi]) & set(layout.u_rows)):
            continue
        rho = layout.rhos[gi]
        want = F2_ZERO
        for t in range(MSG):
            want = f2_add(want, layout.gvec[gi][t])
        got = F2_ZERO
        for i in layout.data_rows:
            if rho[i] == F2_ZERO:
                continue
            s = sum(data.get(i, [0] * MSG)) % P
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
            "identity": "the LogUp sum claim: the view determines "
            "sum over data rows of rw[i] * (row sum), and the published value is 0",
            "residual_before": [residual[0], residual[1]],
            "already_satisfied": residual == F2_ZERO,
        }
        if residual != F2_ZERO and pick:
            d1, d2 = solve_pair(rho[pick[0]], rho[pick[1]], residual)
            for i, delta in zip(pick, (d1, d2)):
                row = list(data.get(i, [0] * MSG))
                row[0] = (row[0] + delta) % P
                data[i] = row
            entry.update({"corrected_rows": list(pick), "applied": True})
            out["applied"] = True
        out["identities"].append(entry)
    return out


# ------------------------------------------------------------- one capture
def run_capture(cap, replay, columns="full"):
    """Both fixed inputs, every commitment, and the masking commitment."""
    layouts, views = {}, {}
    for role in cap.roles:
        nm = role["role"]
        v = RoleView(cap, role, replay.role_prox_rhos[nm])
        v.run(replay.role_lambdas[nm])
        views[nm] = v
        layouts[nm] = RoleLayout(cap, v)
    cfsview = CfsView(cap, replay).run()

    out = {"roles": {}, "fixed_inputs": {}, "cfs": {}}
    digests = {}
    for nm, L in layouts.items():
        digests[nm] = L.matrix_digest()
        out["roles"][nm] = {
            "rows": L.rows,
            "data_rows": len(L.data_rows),
            "non_data_rows": L.rows - len(L.data_rows),
            "u_rows": L.u_rows,
            "opening_groups": len(L.groups),
            "claims": len(L.rws),
            "distinct_opened_columns": L.d,
            "layout_findings": L.findings,
            "reduction_hypotheses": views[nm].facts["reduction_hypotheses"],
            "disclosed_dimension_fp_stage2": views[nm].facts["disclosed_dimension"],
            "M_data_shape": [len(L.data_rows), MSG],
            "M_nondata_unknowns": (L.rows - len(L.data_rows)) * MSG
            + L.rows * MSG - len(L.u_rows),
            "y_entries": (len(L.groups) + 1) * 2 * MSG + len(L.rws) + L.d * L.rows,
            "matrix_digest": digests[nm],
        }

    for kind in ("zero", "prg"):
        per_role = {}
        for nm, L in layouts.items():
            data = fixed_input(kind, L, cap.profile)
            proj = project_onto_disclosed(L, data) if kind == "prg" else {"applied": False}
            raw = None
            if kind == "prg" and proj["applied"]:
                # the same input BEFORE the projection: it must have no preimage,
                # which is the disclosed dimension made visible
                unproj = fixed_input(kind, L, cap.profile)
                raw = RolePreimage(L, unproj).build()
            pre = RolePreimage(L, data).build()
            ver = pre.verify(columns=columns) if not pre.fail else None
            per_role[nm] = {
                "preimage_exhibited": not pre.fail,
                "no_preimage_reason": pre.fail,
                "exhibited_randomness_sha256": None if pre.fail else pre.blinding_digest(),
                "verification": ver,
                "fibre": pre.fibre_dimension(),
                "matrix_digest": L.matrix_digest(),
                "matrix_digest_unchanged": L.matrix_digest() == digests[nm],
                "projection_onto_the_disclosed_identity": proj,
                "before_projection_has_no_preimage": (
                    None if raw is None else bool(raw.fail)
                ),
            }
        out["fixed_inputs"][kind] = per_role

    # the masking commitment's channel, both accountings
    for which in ("all", "theta"):
        cp = CfsPreimage(cap, replay)
        if cp.run() is None:
            out["cfs"][which] = {"preimage_exhibited": False, "findings": cp.findings}
            continue
        before = cp.verify()
        proj = cp.project(which=which)
        ver = cp.verify()
        out["cfs"][which] = {
            "preimage_exhibited": ver["all_entries_equal"],
            "fixed_transcript": "the flat honest transcript whose claimed sum is what "
            "the hosted slots' published scalars force, projected onto the identities "
            "the M opening pins",
            "zero_transcript_is_infeasible": not before["all_entries_equal"],
            "projection": proj,
            "verification": ver,
            "functional_values": cp.functional_values(),
            "fibre": cp.fibre_dimension(),
            "findings": cp.findings,
        }
    # the link the "published terminals" channel rests on, CHECKED here and
    # not asserted: every terminal is the value of the PCS claim its private
    # table names, and those claim values are among the entries the
    # commitment-side preimage reproduces
    ti = terminal_identity(cap, replay)
    out["terminals"] = {
        "terminals": ti["terminals"],
        "republished_as_claim_values": ti["terminals_republished_as_claim_values"],
        "all_republished": ti["terminals"] == ti["terminals_republished_as_claim_values"],
    }
    out["cfs"]["stage3_disclosed_all_values_fp"] = cfsview["disclosed_all_values_fp"]
    out["cfs"]["stage3_disclosed_opening_only_fp"] = cfsview["disclosed_opening_only_fp"]
    out["cfs"]["slots"] = cfsview["slots"]
    out["cfs"]["published_functionals"] = cfsview["functionals"]
    out["mask"] = mask_stage(cap, replay, columns=columns)
    return out, layouts, views


# --------------------------------------------- the masking commitment M
def mask_stage(cap, replay, columns="full"):
    """M's own opening, with the ported row layout: the three channels closed.

    Until this lane the gate had no model of M's rows, so its `q`, its
    proximity vector and its own 256 opened columns were three OPEN channels
    whose stated remedy was "a port of encode_coeffs_coset and mask_commit's
    row layout into this tool; no capture field is missing".  The port is
    `zk60_native_mask_commit`; this stage runs it.

    What is exhibited: TWO distinct, public, seeded coefficient vectors on the
    plane the verifier's own first check cuts out, each with a full set of
    blinding values -- 256 pads per a-row, the two b rows, the two u rows --
    that reproduces the captured opening entry by entry.  The coefficient
    vectors are generated from a published seed and are prover randomness of
    the same kind M's own coefficients are; no witness, mask coefficient,
    salt or private plane is read or invented.
    """
    mm = MaskModel(cap, replay)
    out = {
        "source_pins": check_source_pins(),
        "shape": mm.shape(),
        "declared_order": declared_functional_order(cap, replay),
        "disclosed": disclosed_dimension(mm),
        "model_failures": mm.failures,
    }
    pres = []
    for tag in ("a1", "a2"):
        coefs, where = force_functional(mm, synthetic_coefficients(mm, tag), mm.v)
        pre = MaskPreimage(mm, coefs).build()
        ver = pre.verify(columns=columns) if pre.ok else None
        pres.append((coefs, pre, ver))
        out[f"preimage_{tag}"] = {
            "coefficients": "public, seeded; corrected at one position onto the "
            "V plane",
            "corrected_at": where,
            "preimage_exhibited": bool(ver and ver["all_entries_equal"]),
            "exhibited_randomness_sha256": pre.blinding_digest() if pre.ok else None,
            "verification": ver,
            "no_preimage_reason": pre.failures,
        }
    (c1, p1, _), (c2, p2, _) = pres
    diff = sum(
        1 for s in range(mm.S) for t in range(mm.L[s]) if c1[s][t] != c2[s][t]
    )
    out["two_preimages_at_different_coefficients"] = {
        "coefficient_positions": sum(mm.L),
        "positions_where_the_two_coefficient_vectors_differ": diff,
        "same_batched_functional_value": p1.functional_value() == p2.functional_value(),
        "blinding_digests_differ": p1.blinding_digest() != p2.blinding_digest(),
        "both_reproduce_the_captured_opening": all(
            v and v["all_entries_equal"] for _, _, v in pres
        ),
        "what_it_shows": "the captured opening is reproduced at two coefficient "
        "vectors that agree in NOTHING but the one Fp2 functional V, which is the "
        "disclosed dimension made concrete rather than argued",
    }
    # the off-plane refusal: the other side of the same statement
    off, _ = force_functional(
        mm, synthetic_coefficients(mm, "a3"), f2_add(mm.v, (1, 0))
    )
    po = MaskPreimage(mm, off).build()
    vo = po.verify(columns=4)
    out["off_the_V_plane_has_no_preimage"] = {
        "what": "a coefficient vector with V(a) one off the captured batch",
        "b_admissible": vo["b_admissible"],
        "q_sum_identity_holds": vo["q_sum_identity_holds"],
        "column_mismatches": vo["column_mismatches"],
        "preimage_exhibited": vo["all_entries_equal"],
        "why": "b's only constraint is its zero sum over G_512, which reads "
        "512 (q[0] + q[512]) = V(a); off that plane no b exists and the fibre is "
        "EMPTY.  The columns still match -- the pads absorb every coefficient "
        "vector -- so the disclosure is exactly this one Fp2 and nothing else",
    }
    out["ok"] = bool(
        out["shape"]["ok"]
        and out["declared_order"]["ok"]
        and out["disclosed"]["matches_prediction"]
        and out["two_preimages_at_different_coefficients"][
            "both_reproduce_the_captured_opening"
        ]
        and not vo["all_entries_equal"]
        and not mm.failures
    )
    return out


# ----------------------------------------------------------- the channels
def channels_for(cap, res):
    """One entry per channel of the privacy case's sections 2.1 and 2.2, plus
    the two the gate's own section 4.2 adds.  Every entry carries a status."""
    zero = res["fixed_inputs"]["zero"]
    prg = res["fixed_inputs"]["prg"]
    pcs_roles = ["A", "H", "Input", "Output"]
    pcs_ok = all(zero[r]["preimage_exhibited"] for r in pcs_roles)
    pcs_ver = all(
        zero[r]["verification"] and zero[r]["verification"]["all_entries_equal"]
        for r in pcs_roles
    )
    prg_ok = all(prg[r]["preimage_exhibited"] for r in pcs_roles)
    fibre = {r: zero[r]["fibre"]["fibre_dimension_fp"] for r in pcs_roles}
    same_fibre = all(
        zero[r]["fibre"]["fibre_dimension_fp"] == prg[r]["fibre"]["fibre_dimension_fp"]
        and prg[r]["matrix_digest_unchanged"]
        for r in pcs_roles
    )
    cfs = res["cfs"]["all"]
    mk = res["mask"]

    def mask_entry(name, section, how, ver_of, extra=None):
        """One of M's three channels, CONSTRUCTED by the ported row layout.

        Closed in this lane (2026-09-20).  The status is not written down: it
        is read off the exhibited preimage, so a port that stopped working
        would drop the channel back through the grade's own fail rule
        ("constructed but no preimage exhibited").
        """
        ver = ver_of(mk)
        ok = bool(mk["ok"] and ver and ver["all_entries_equal"])
        e = {
            "channel": name,
            "section": section,
            "status": "constructed" if ok else "open",
            "assumption": None,
            "preimage_exhibited": ok,
            "preimage_exhibited_second_coefficient_vector": bool(
                mk["preimage_a2"]["preimage_exhibited"]
            ),
            "how": how,
            "closed": "2026-09-20, by the port of zk.rs::mask_commit / mask_open "
            "into scripts/zk60_native_mask_commit.py (source-pinned)",
            "disclosed_fp_over_the_coefficients": mk["disclosed"]["disclosed_fp_computed"],
            "disclosed_fp_predicted": mk["disclosed"]["disclosed_fp_predicted"],
            "fibre_dimension_fp": mk["disclosed"]["fibre_dimension_fp"],
            "declared_functional_order_checked": mk["declared_order"]["ok"],
        }
        if not ok:
            e["reason"] = "the ported model of M did not exhibit a preimage: " + str(
                (mk.get("model_failures") or [])[:2]
                or (ver or {}).get("failures")
                or mk["shape"]["failed"]
            )
        if extra:
            e.update(extra(mk))
        return e

    def pcs_entry(name, section, note):
        return {
            "channel": name,
            "section": section,
            "status": "constructed",
            "assumption": None,
            "preimage_exhibited": bool(pcs_ok and pcs_ver),
            "preimage_exhibited_second_fixed_input": bool(prg_ok),
            "augmented_rank_equal": bool(pcs_ok and pcs_ver),
            "residual_entries_differing": sum(
                (zero[r]["verification"] or {}).get("group_vector_mismatches", 1)
                + (zero[r]["verification"] or {}).get("proximity_mismatches", 1)
                + (zero[r]["verification"] or {}).get("claim_value_mismatches", 1)
                + (zero[r]["verification"] or {}).get("column_mismatches", 1)
                for r in pcs_roles
            ),
            "fibre_dim_zero": fibre,
            "fibre_dim_real": "the same matrix: M_nondata does not depend on the "
            "hidden input, so the fibre dimension at the real witness is the same "
            "number; the gate asserts it by re-deriving the matrices at the second "
            "fixed input and comparing their digests",
            "fibre_dimension_equal_across_fixed_inputs": bool(same_fibre),
            "how": note,
        }

    ch = [
        pcs_entry(
            "opening-group vectors", "2.1",
            "solved on each claim's reserved mask pair (msg) and through the pad "
            "polynomials' free coefficients above the sampled nodes (pad); all "
            "512 entries of every group recomputed and compared",
        ),
        pcs_entry(
            "proximity vectors (PCS)", "2.1",
            "solved on the proximity pair, which no claim touches; all 512 entries "
            "recomputed and compared",
        ),
        pcs_entry(
            "claimed evaluations", "2.1",
            "each claim's own reserved pair carries its value; every claim value "
            "recomputed from the exhibited randomness and compared",
        ),
        pcs_entry(
            "opened column values", "2.1",
            "the pads are the preimage: Lagrange interpolation through the distinct "
            "sampled nodes, inside the Q = 256 pad budget; every opened column value "
            "of A, H and both endpoints recomputed and compared.  The M opening's "
            "own columns are NOT constructed -- see the open channel below",
        ),
        {
            "channel": "column indices",
            "section": "2.1",
            "status": "derived",
            "assumption": None,
            "preimage_exhibited": None,
            "function": "Transcript::challenge_indices over the public prefix; stage 1 "
            "of the joint-view tool re-derives every index from public data and this "
            "gate re-reads them from that replay",
            "recomputed": True,
            "note": "derived, not sampled by the prover",
        },
        {
            "channel": "leaf salts",
            "section": "2.1",
            "status": "argued",
            "assumption": "M-3",
            "preimage_exhibited": None,
            "model_assumption": "the salts are fresh uniform bytes in both worlds and "
            "equality of the two laws rests on M-3, the assumption that the whole "
            "output stream of the generator the code uses (ZkRng) is indistinguishable "
            "from uniform, including in the direction that published later outputs do "
            "not reveal earlier secret ones",
            "counts": {"per_opening": 256, "openings": 5, "bytes_each": 32},
        },
        {
            "channel": "the three Merkle roots",
            "section": "2.1",
            "status": "argued",
            "assumption": "M-2",
            "preimage_exhibited": None,
            "model_assumption": "the roots are generated by the prover itself under "
            "ruling D18, no oracle point is programmed, and indistinguishability of "
            "the two worlds' roots rests on M-2, the hiding of unopened salted leaves "
            "in the random-oracle model",
        },
        {
            "channel": "authentication paths",
            "section": "2.1",
            "status": "argued",
            "assumption": "M-2",
            "preimage_exhibited": None,
            "model_assumption": "the paths are genuine hashes of the same world's own "
            "columns; hiding of the roughly 212.5 unopened leaf digests and of the "
            "internal nodes above them per 2,048-leaf tree rests on M-2",
            "counts": {"levels_pcs": 11, "levels_mask": 12, "paths_per_opening": 256},
        },
        {
            "channel": "masked sumcheck rounds",
            "section": "2.1",
            "status": "constructed",
            "assumption": None,
            "preimage_exhibited": bool(cfs["preimage_exhibited"]),
            "augmented_rank_equal": bool(cfs["preimage_exhibited"]),
            "fibre_dim_zero": cfs["fibre"]["fibre_dimension_fp"],
            "fibre_dim_real": "the same matrix: R_s and the sum weights are functions "
            "of the replayed challenges and the slot geometry only",
            "how": "the CFS mask coefficients are solved per slot and every published "
            "round entry is recomputed from (fixed transcript, coefficients)",
            "per_slot_statement": "for slot s the gate exhibits mask coefficients with "
            "masked_round_j = honest_round_j + c_s g_s.round(j, rho_<j) at EVERY "
            "round and evaluation point, for a named fixed honest transcript; the "
            "remaining freedom is one Fp2 coefficient direction per slot",
            "entries_checked": cfs["verification"]["round_entries"],
            "entries_differing": cfs["verification"]["round_mismatches"],
        },
        {
            "channel": "published masked scalars, Gamma",
            "section": "2.1",
            "status": "constructed",
            "assumption": None,
            "preimage_exhibited": bool(cfs["preimage_exhibited"]),
            "how": "the same coefficients, through CfsMask::sum_weights: "
            "scalar_s = honest_scalar_s + c_s * <sum_weights, coef_s>, recomputed and "
            "compared for every slot",
            "entries_checked": cfs["verification"]["scalars"],
            "entries_differing": cfs["verification"]["scalar_mismatches"],
        },
        {
            "channel": "published terminals",
            "section": "2.1",
            "status": "constructed",
            "assumption": None,
            "preimage_exhibited": bool(
                pcs_ok and pcs_ver and res["terminals"]["all_republished"]
            ),
            "how": "every terminal is republished as the value of the PCS claim its "
            "private table names (argument.rs:223) -- CHECKED here, not assumed -- and "
            "those claim values are among the entries the commitment-side preimage "
            "reproduces exactly",
            "terminals": res["terminals"],
        },
        {
            "channel": "mask evaluations",
            "section": "2.1",
            "status": "derived",
            "assumption": None,
            "preimage_exhibited": None,
            "function": "mask_eval_s = (fin_s - terminal_polynomial_s) * c_s^-1, the "
            "verifier's own final check solved for the evaluation; the joint-view "
            "tool's stage 3 asserts the identity per slot on every capture",
            "recomputed": True,
        },
        {
            "channel": "LogUp sums",
            "section": "2.1",
            "status": "constructed",
            "assumption": None,
            "preimage_exhibited": bool(zero["H"]["preimage_exhibited"]),
            "how": "the one disclosed identity: the zsum claim's published value is "
            "Fp2::ZERO, and the all-zero input gives exactly that, so the fibre over "
            "the zero input is non-empty and the preimage is exhibited.  The gate's "
            "controls force the value nonzero and show the fibre becomes EMPTY",
            "note": "this is the channel where the fixed input is not free: a fixed "
            "input off this identity has no preimage, which is the disclosed "
            "dimension 2 of stage 2 made visible",
        },
        mask_entry(
            "the M opening's q", "2.1",
            "the masking commitment's row layout is now ported "
            "(zk60_native_mask_commit, pinned to zk.rs): b is 1,024 coefficients per "
            "part with the single constraint b[512] = -b[0], and the gate solves for "
            "it as q minus the product part.  b is admissible exactly when "
            "512 (q[0] + q[512]) = V(a), the verifier's own first check, so the q "
            "channel pins ONE Fp2 functional of the coefficients and nothing else -- "
            "exhibited at two coefficient vectors that differ everywhere else, and "
            "REFUSED off that plane",
            lambda mk: mk["preimage_a1"]["verification"],
            extra=lambda mk: {
                "b_zero_sum_admissible": mk["preimage_a1"]["verification"]["b_admissible"],
                "q_entries_fp2": mk["preimage_a1"]["verification"]["q_entries"],
                "q_entries_differing": mk["preimage_a1"]["verification"]["q_mismatches"],
                "q_is_reproduced_by_construction": True,
                "what_the_channel_actually_pins": "b's zero sum; the entry count "
                "records that the two arithmetic paths agree, not that q itself "
                "tested anything new",
                "off_the_plane": mk["off_the_V_plane_has_no_preimage"],
            },
        ),
        mask_entry(
            "the M proximity vector", "2.1",
            "u_re and u_im are 1,024 FREE coefficients each with no constraint at "
            "all, and the gate solves for them as prox minus the replayed "
            "rho-combination of the a and b rows (zk.rs:537-541).  Every one of the "
            "1,024 published Fp2 entries is met and the channel discloses nothing",
            lambda mk: mk["preimage_a1"]["verification"],
            extra=lambda mk: {
                "prox_entries_fp2": mk["preimage_a1"]["verification"]["prox_entries"],
                "prox_entries_differing": mk["preimage_a1"]["verification"]["prox_mismatches"],
                "u_unknowns_fp": 2 * 2 * (1 << 9),
                "disclosed_fp": 0,
            },
        ),
        mask_entry(
            "opened column values (the M opening's own 256 columns)", "2.1",
            "the 256 pads of each a-row are the preimage: the map from the pads to "
            "the row's values at the distinct sampled nodes is a Cauchy matrix in "
            "distinct nodes, solved here in closed form, and the b and u rows' own "
            "column values then follow from q and prox.  Every opened column value "
            "of every one of M's rows is recomputed through the ported NTT path and "
            "compared",
            lambda mk: mk["preimage_a1"]["verification"],
            extra=lambda mk: {
                "column_entries": mk["preimage_a1"]["verification"]["column_entries"],
                "column_entries_differing": mk["preimage_a1"]["verification"]["column_mismatches"],
                "pads_per_a_row": mk["shape"]["pads_per_a_row"],
                "distinct_opened_columns": mk["shape"]["distinct_columns"],
                "pad_margin": mk["shape"]["pad_margin"],
            },
        ),
        {
            "channel": "counts and lengths",
            "section": "2.1",
            "status": "argued",
            "assumption": "shape facts",
            "preimage_exhibited": None,
            "model_assumption": "every count and length in the receipt is a function "
            "of the public geometry alone (layout.rs:521-526, wire.rs:28-36), so it is "
            "the same in both worlds; the gate checks the two captures of one profile "
            "have identical proof byte counts",
        },
        {
            "channel": "the wire envelope",
            "section": "2.1",
            "status": "argued",
            "assumption": "shape facts",
            "preimage_exhibited": None,
            "model_assumption": "the 8-byte magic and the 32-byte binding digest are "
            "the transcript state after the header, a function of the public statement "
            "and the policy only -- witness-independent except through the endpoint "
            "roots, which the policy carries and which the D8/D11 obligation covers",
        },
        {
            "channel": "slots, scalars, framing (the residue, less the envelope)",
            "section": "2.1",
            "status": "argued",
            "assumption": "shape facts",
            "preimage_exhibited": None,
            "model_assumption": "the framing bytes are lengths and tags fixed by the "
            "public schedule; the payload inside them is the slot channels above",
        },
        {
            "channel": "the public statement and the 112-byte expected-IO policy",
            "section": "2.2",
            "status": "argued",
            "assumption": "O-1",
            "preimage_exhibited": None,
            "model_assumption": "the statement and policy are public inputs, identical "
            "in both worlds; condition O-1 rides on this channel -- if a deployment "
            "computes the 32-byte context digest from the request then for a "
            "low-entropy prompt the digest IS the prompt, which no property of the "
            "proof repairs",
        },
        {
            "channel": "the receipt's length",
            "section": "2.2",
            "status": "argued",
            "assumption": "shape facts",
            "preimage_exhibited": None,
            "model_assumption": "2,816,472 bytes at the block profile for every "
            "witness; the zero-witness Rust test asserts the zero input's receipt has "
            "exactly that length",
        },
        {
            "channel": "whether a proof attempt produced a receipt",
            "section": "2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "the refusal channel is inside the game (ruling C-2) and one "
            "refusal class is witness-dependent at about 2^-112; no capture can show "
            "it, because a capture only exists when the proof was accepted",
        },
        {
            "channel": "rejected-but-emitted receipts",
            "section": "2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "history item H8, a procedural condition on the deployment: "
            "finish has no equality precheck, so a rejected receipt is fully "
            "constructed and must never be transmitted",
        },
        {
            "channel": "retained captures",
            "section": "2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "history item H9, a procedural condition: a retained capture is "
            "a published opening of its two endpoint roots.  Today the writer is "
            "behind #[cfg(test)] and every capture is of a deliberately public fixture",
        },
        {
            "channel": "timing, memory, power",
            "section": "2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "declared out of scope for the first MVP (M-5, ruling C-2); no "
            "field of the capture bears on it",
        },
        {
            "channel": "prior proofs by the same prover",
            "section": "2.2",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "the composition of several receipts is chain item 21 and open "
            "item U-3b; this gate analyses one receipt at a time",
        },
        {
            "channel": "the integer-range facts the statement implies",
            "section": "4.2 row 16",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "chain item 20: the statement implies the hidden values are in "
            "range, which is information about them that no preimage argument removes",
        },
        {
            "channel": "any nonlinear functional of the joint view",
            "section": "4.2 row 17",
            "status": "open",
            "assumption": None,
            "preimage_exhibited": None,
            "reason": "chain item 21: the terminal identity links the commitment and "
            "masking channels with degree up to 4 in the terminals, and no linear "
            "model sees that link.  This gate is linear",
        },
    ]
    return ch


def grade(channels):
    """The section 4.2 fail rules, applied to the machine-readable array."""
    bad = []
    hash_layer = {"the three Merkle roots", "leaf salts", "authentication paths"}
    seen = {c["channel"] for c in channels}
    for c in channels:
        st = c.get("status")
        if st not in ("constructed", "derived", "argued", "open"):
            bad.append(f"{c['channel']}: status {st!r} is not one of the four labels")
            continue
        if st == "constructed" and not c.get("preimage_exhibited"):
            bad.append(f"{c['channel']}: constructed but no preimage exhibited")
        if st == "argued" and not c.get("assumption"):
            bad.append(f"{c['channel']}: argued but names no assumption")
        if st == "open" and not c.get("reason"):
            bad.append(f"{c['channel']}: open but gives no reason")
    for h in hash_layer:
        if h not in seen:
            bad.append(f"the hash layer is silent: {h} is missing")
        else:
            e = next(c for c in channels if c["channel"] == h)
            if e["status"] != "argued" or not e.get("assumption"):
                bad.append(f"the hash layer is silent: {h} names no assumption")
    return {
        "channels": len(channels),
        "by_status": {
            s: sum(1 for c in channels if c["status"] == s)
            for s in ("constructed", "derived", "argued", "open")
        },
        "failures": bad,
        "ok": not bad,
    }


# ------------------------------------------------------------- the controls
def controls(cap, replay, layouts, views, columns=8):
    """Each control must PASS on the honest capture and FAIL when perturbed.

    Two of them test THIS gate's own criterion (the check's section 8): an
    unsatisfiable channel, and a witness-bearing channel whose fibre becomes
    empty.  A control that cannot fire at an honest capture is not a control,
    so every entry records the honest verdict beside the perturbed one.
    """
    out = {}
    Lin = layouts["Input"]
    LH = layouts["H"]
    LA = layouts["A"]
    out["honest"] = {
        nm: not RolePreimage(layouts[nm], {}).build().fail for nm in layouts
    }

    # (1) an unsatisfiable channel: one coordinate of a captured group vector
    for pos, tag in ((0, "message position 0"), (MSG, "pad coefficient 0")):
        saved = Lin.gvec[0][pos]
        Lin.gvec[0][pos] = ((saved[0] + 1) % P, saved[1])
        pre = RolePreimage(Lin, {}).build()
        Lin.gvec[0][pos] = saved
        out[f"unsatisfiable_group_vector_{pos}"] = {
            "what": f"Input's opening-group vector perturbed by one at {tag}, the "
            "opened columns left alone",
            "honest_passes": out["honest"]["Input"],
            "fires": bool(pre.fail),
            "how": pre.fail[:1],
            "why_it_can_fire": "the view's own public identities tie the channels "
            "together -- the verifier's column identity says the group vector's "
            "encoding at a sampled node equals the group combination of that column's "
            "values -- so a perturbation of one channel alone leaves the image of the "
            "blinding map and no preimage exists",
        }
    out["honest_again"] = not RolePreimage(Lin, {}).build().fail

    # (2) a witness-bearing channel: the H LogUp sum claim's published value
    zs = [ci for ci, p in LH.claim_pair.items() if set(p) == set(LH.u_rows)]
    fired = None
    if zs:
        saved = LH.values[zs[0]]
        LH.values[zs[0]] = ((saved[0] + 1) % P, saved[1])
        pre = RolePreimage(LH, {}).build()
        LH.values[zs[0]] = saved
        fired = bool(pre.fail)
        how = pre.fail[:1]
    out["witness_bearing_logup_value"] = {
        "what": "H's LogUp sum claim forced to a value other than Fp2::ZERO",
        "claim": zs[:1],
        "honest_passes": out["honest"]["H"],
        "fires": bool(fired),
        "how": how if zs else ["no zsum claim found"],
        "why": "the u pair's message sums to zero by the layout's public linear "
        "constraint, so the zero input can only reach a zero published value: the "
        "fibre over the all-zero input becomes EMPTY",
    }

    # (3) the rank-loss control the brief asks for: remove blinding unknowns
    d = Lin.d
    pre = RolePreimage(Lin, {}, pad_width=d - 1).build()
    out["one_pad_fewer_than_the_distinct_opened_columns"] = {
        "what": f"Input modelled with {d - 1} pad symbols against {d} distinct opened "
        "columns -- one blinding unknown short of the budget",
        "honest_passes": out["honest"]["Input"],
        "fires": bool(pre.fail),
        "how": pre.fail[:1],
        "why": "with fewer pad symbols than distinct opened columns the row's pad "
        "polynomial cannot meet the opened values, so the view leaves the image of "
        "the blinding map and has no preimage.  This is the control on the side that "
        "CAN fail: at the real budget the map is onto, and then EVERY view has a "
        "preimage, which is what nothing-disclosed means",
    }

    # (4) a blinding unknown shared between two commitments
    a_single = singleton_pair_rows(views["A"])
    h_single = singleton_pair_rows(views["H"])
    shared = {"what": "one reserved mask row of a singleton opening group in A and one "
              "in H declared to be the SAME unknown"}
    if a_single and h_single:
        ra, rh = a_single[0]["rows"][0], h_single[0]["rows"][0]
        pa = RolePreimage(LA, fixed_input("prg", LA, cap.profile)).build()
        dh = fixed_input("prg", LH, cap.profile)
        project_onto_disclosed(LH, dh)
        ph = RolePreimage(LH, dh).build()
        diff = [t for t in range(MSG) if pa.X[ra][t] != ph.X[rh][t]]
        shared.update({
            "rows": {"A": ra, "H": rh},
            "per_commitment_preimages_exist": not pa.fail and not ph.fail,
            "positions_where_the_two_forced_values_differ": len(diff),
            "first_differing_position": diff[0] if diff else None,
            "fires": bool(diff),
            "why": "both rows belong to SINGLETON opening groups, so inside each "
            "commitment the pair's message is the unique solution of an invertible "
            "2x2 system at every position: A forces one value on the shared unknown "
            "and H forces another.  The per-commitment preimages exist and the JOINT "
            "one does not -- the case a per-commitment acceptance cannot see",
            "honest_passes": "the honest receipt shares no blinding row (the "
            "joint-view tool's stage 4 computes that the non-data block is block "
            "diagonal by role), so both preimages stand on the honest capture",
        })
    out["shared_blinding_unknown_between_two_commitments"] = shared

    # (5) the second fixed input on the disclosed channel
    dh = fixed_input("prg", LH, cap.profile)
    raw = RolePreimage(LH, dict(dh)).build()
    proj = project_onto_disclosed(LH, dh)
    fixed = RolePreimage(LH, dh).build()
    out["second_fixed_input_off_the_disclosed_identity"] = {
        "what": "the pseudorandom fixed input on H, before and after projection onto "
        "the one identity the view discloses",
        "before_projection_has_a_preimage": not raw.fail,
        "after_projection_has_a_preimage": not fixed.fail,
        "projection": proj,
        "fires": bool(raw.fail) and not fixed.fail,
        "why": "the disclosed dimension is not a number here but a refusal: a fixed "
        "input off the LogUp plane has no preimage at all",
    }

    # (6) the CFS channel's own feasibility
    cp = CfsPreimage(cap, replay)
    cp.run()
    before = cp.verify()
    cp.project(which="all")
    after = cp.verify()
    out["cfs_zero_transcript"] = {
        "what": "the canonical zero honest transcript against the published "
        "functional values",
        "zero_transcript_infeasible": not before["all_entries_equal"],
        "projected_transcript_feasible": after["all_entries_equal"],
        "fires": (not before["all_entries_equal"]) and after["all_entries_equal"],
        "why": "the M opening pins functionals of the mask coefficients that lie in "
        "the round span, so the fixed transcript is not free: the gate exhibits the "
        "preimage exactly on the plane those identities cut out",
    }

    # (7) the masking commitment's own three controls, from the ported layout:
    # a pad removed from M, the functional order permuted, a second functional
    # leaked.  Each records the honest verdict beside the perturbed one.
    out["mask_commitment_M"] = mask_controls(MaskModel(cap, replay))

    # every perturbation above is undone; prove it, on every commitment
    out["honest_after_every_control"] = {
        nm: not RolePreimage(layouts[nm], {}).build().fail for nm in layouts
    }
    names = [k for k in out if isinstance(out[k], dict) and "fires" in out[k]]
    out["all_fire"] = all(out[k]["fires"] for k in names)
    out["control_names"] = names + [
        "mask_commitment_M/" + n for n in out["mask_commitment_M"]["control_names"]
    ]
    out["ok"] = (
        out["all_fire"]
        and out["mask_commitment_M"]["ok"]
        and out["honest_again"]
        and all(out["honest"].values())
        and all(out["honest_after_every_control"].values())
    )
    return out


# -------------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--columns", default="full",
                    help="'full' (default) or a count, for a shorter verification pass")
    ap.add_argument("--controls-on", default="first",
                    choices=("first", "all", "none"))
    # [ROUND 9e] the ONLY way past a missing manifest, and it is recorded in
    # the record: before this flag existed the check skipped itself quietly.
    ap.add_argument("--no-validation-file", action="store_true",
                    help="declare, on the record, that this capture directory "
                         "carries no validation manifest; without it a missing "
                         "manifest is a refusal, not a pass")
    args = ap.parse_args(argv)

    # [ROUND 9f] BEFORE anything is read: the two Cargo manifests that decide
    # whether the test-only observers can reach a release build (finding
    # P36-2). A moved manifest, or one that ships the feature, stops the gate
    # here with a message naming the file -- condition 7 of the toy profile's
    # privacy statement (register D22), the same rule the Rust path pins obey.
    try:
        check_manifest_pins()
    except ManifestPinError as exc:
        print(f"REFUSED (Cargo manifest pins): {exc}", file=sys.stderr)
        return 3

    # [ROUND 9h] and, on the same footing, the three files on the PRIVATE
    # ATTENTION profile's proving and verifying path that no pin table named
    # (ledger section R9h). Two of the four captures of record are attention
    # receipts; the check is unconditional because a gate run reads the whole
    # capture directory, which holds both profiles.
    try:
        check_profile_pins()
    except ProfilePinError as exc:
        print(f"REFUSED (attention profile pins): {exc}", file=sys.stderr)
        return 3

    t0 = time.time()
    caps = load_all(args.captures)
    if not caps:
        print("no captures found", file=sys.stderr)
        return 2
    try:
        manifest = manifest_check(
            args.captures, caps, no_validation_file=args.no_validation_file)
    except ManifestRefusal as exc:
        print(f"REFUSED (manifest cross-check): {exc}", file=sys.stderr)
        return 3
    record = {
        "gate": "zk60-native-privacy-gate-P10",
        "version": 2,
        "version_2": "2026-09-20: the masking commitment M's row layout ported "
        "(scripts/zk60_native_mask_commit.py, source-pinned to zk.rs and "
        "private_block/argument.rs), which turns M's three OPEN channels -- its q, "
        "its proximity vector and its own 256 opened columns -- into CONSTRUCTED "
        "ones, with three controls of their own. No other channel and no other "
        "number changed",
        "definition": "ZK60_PRIVACY_CASE_FIRST_MVP.md section 4 (ruling C-6)",
        "privacy_property_established": False,
        "privacy_review_complete": False,
        "is_a_privacy_acceptance": False,
        "what_it_does_not_show": [
            "the hash layer is ARGUED, not computed: the roots, the 256 leaf salts "
            "per opening and the 11- and 12-level authentication paths rest on M-2 "
            "and M-3",
            "the composition of the channels into one distribution (open item U-3b) "
            "is untouched",
            "no nonlinear functional of the view is covered; the terminal identity "
            "links the two channels nonlinearly",
            "this is four captured receipts at two toy layouts, not a statement "
            "about the 125M profile or about all challenges",
        ],
        "zero_witness_acceptance_test": ZERO_WITNESS_TEST,
        "captures_dir": os.path.abspath(args.captures),
        "manifest": manifest,
        "tool_sha256": tool_hashes(),
        "fixed_inputs": {
            "zero": "the all-zero hidden input, the same one the Rust zero-witness "
            "test proves and verifies",
            "prg": f"a pseudorandom in-range input, value = "
            f"sha256('{SEED}|profile|role|row|block') read as little-endian u32 "
            f"modulo {PRG_BOUND}; public, deterministic, and NOT a witness",
        },
        "per_capture": [],
    }

    all_ok = True
    for n, cap in enumerate(caps):
        rp = Replay(cap).run()
        s = rp.summary()
        res, layouts, views = run_capture(cap, rp, columns=args.columns)
        ch = channels_for(cap, res)
        gr = grade(ch)
        ctl = None
        if args.controls_on == "all" or (args.controls_on == "first" and n == 0):
            ctl = controls(cap, rp, layouts, views)
        ok = s["ok"] and gr["ok"] and res["mask"]["ok"] and (ctl is None or ctl["ok"])
        all_ok = all_ok and ok
        record["per_capture"].append({
            "capture": cap.proof_sha256,
            "profile": cap.profile,
            "proof_bytes": cap.doc["proof_bytes"],
            "transcript_replay": s,
            "model": res["roles"],
            "fixed_inputs": res["fixed_inputs"],
            "masking_commitment": res["cfs"],
            "masking_commitment_M_opening": res["mask"],
            "channels": ch,
            "grade": gr,
            "controls": ctl,
            "ok": ok,
        })
        print(f"{cap.proof_sha256[:16]} {cap.kind}: {'ok' if ok else 'FAIL'}")

    lens = {}
    for c in caps:
        lens.setdefault(c.profile, set()).add(c.doc["proof_bytes"])
    record["receipt_length_is_the_same_within_a_profile"] = {
        p: sorted(v) for p, v in lens.items()
    }
    record["seconds"] = round(time.time() - t0, 1)
    record["ok"] = all_ok

    os.makedirs(args.evidence, exist_ok=True)
    out = os.path.join(args.evidence, "privacy_gate.json")
    with open(out, "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(args.evidence, "privacy_gate.done"), "w") as fh:
        fh.write("0\n" if all_ok else "1\n")
    print(f"record: {out} ({record['seconds']} s)")
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
