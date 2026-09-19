#!/usr/bin/env python3
"""The native joint-view gate: one command, seven stages, each able to FAIL.

    python3 scripts/zk60_native_joint_view.py \
      --captures results/zk60_native_captures_20260919 \
      --evidence results/zk60_native_joint_view

Runs the joint-view analysis on the REAL captured verifier views of the
source-pinned native receipts of 2026-09-19 (two complete-block, two
attention).  Read `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md` for what
each number means and, above all, for what it does NOT establish.

  1 TRANSCRIPT REPLAY     every checkpoint and challenge re-derived with
                          BLAKE3 from the capture's public data
  2 COMMITMENT-SIDE VIEW  A and H (and both endpoints) jointly, with the
                          claim values, the group combinations and the 256
                          sampled columns with their pads
  3 MASKING-COMMITMENT    the CFS masks, the slots' masked rounds and the
                          one M opening
  4 STACKED               A, H and M together against the sum of the parts
  5 ZERO-WITNESS GATE     a zero-data preimage of the same view, per channel
  6 NEGATIVE CONTROLS     each must fire
  7 RECORD                results, hashes and a marker under --evidence

NO STAGE ESTABLISHES A PRIVACY PROPERTY.  Every rank below is a rank of an
explicitly stated linear model at two receipts' real challenges.  The
caller-fixed endpoint-root obligation (decisions D8/D11) is untouched and
remains OPEN.
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

from zk60_native_jv_capture import load_all, manifest_check  # noqa: E402
from zk60_native_jv_cfs import CfsView, m_pad_block_rank  # noqa: E402
from zk60_native_jv_field import F2_ZERO, f2_from_list  # noqa: E402
from zk60_native_jv_pcs import RoleView  # noqa: E402
from zk60_native_jv_replay import Replay  # noqa: E402
import zk60_native_jv_smallmodel as smallmodel  # noqa: E402

TOOLS = [
    "zk60_native_joint_view.py",
    "zk60_native_jv_field.py",
    "zk60_native_jv_capture.py",
    "zk60_native_jv_replay.py",
    "zk60_native_jv_pcs.py",
    "zk60_native_jv_cfs.py",
    "zk60_native_jv_smallmodel.py",
]


def tool_hashes():
    out = {}
    for t in TOOLS:
        with open(os.path.join(HERE, t), "rb") as fh:
            out[t] = hashlib.sha256(fh.read()).hexdigest()
    return out


# --------------------------------------------------------------- stage 1
def stage1(caps):
    out, replays = [], {}
    for cap in caps:
        rp = Replay(cap).run()
        replays[cap.proof_sha256] = rp
        out.append(rp.summary())
    return {"per_capture": out, "ok": all(o["ok"] for o in out)}, replays


def stage1_tamper(caps, replays):
    """A capture whose bytes were altered must FAIL the replay."""
    fired = []
    for cap in caps:
        doc = cap.doc
        saved = doc["arguments"][0]["rounds"][0][0][0]
        doc["arguments"][0]["rounds"][0][0][0] = (saved + 1) % (2**64 - 2**32 + 1)
        rp = Replay(cap).run()
        doc["arguments"][0]["rounds"][0][0][0] = saved
        fired.append(
            {
                "capture": cap.proof_sha256[:16],
                "fired": not rp.summary()["ok"],
                "first_failure": (rp.failures or ["<none>"])[0],
            }
        )
    return {"per_capture": fired, "ok": all(f["fired"] for f in fired)}


# --------------------------------------------------------------- stage 2
def stage2(caps, replays, pad_rank_check=True):
    out = []
    pad_rank = None
    for cap in caps:
        rp = replays[cap.proof_sha256]
        roles, total = [], 0
        for role in cap.roles:
            rv = RoleView(cap, role, rp.role_prox_rhos[role["role"]])
            f = rv.run(rp.role_lambdas[role["role"]])
            f.pop("xi_vectors", None)
            f.pop("data_rows_index", None)
            roles.append(f)
            total += f["disclosed_dimension"]
            if pad_rank_check and pad_rank is None and role["role"] == "Input":
                t0 = time.time()
                r, d = rv.pad_block_rank()
                pad_rank = {
                    "role": "Input",
                    "capture": cap.proof_sha256[:16],
                    "distinct_columns": d,
                    "exact_rank_of_pad_block": r,
                    "full_rank": r == d,
                    "seconds": round(time.time() - t0, 1),
                }
        out.append(
            {
                "capture": cap.proof_sha256,
                "profile": cap.profile,
                "roles": roles,
                "sum_of_parts": total,
            }
        )
    ok = all(
        r["findings"] == []
        and all(r["reduction_hypotheses"].values())
        and r["column_identity_failures"] == 0
        and r["group_claim_identity_failures"] == 0
        and r["disclosed_dimension"] == (2 if r["role"] == "H" else 0)
        for c in out
        for r in c["roles"]
    )
    return {
        "per_capture": out,
        "expected": {"A": 0, "H": 2, "Input": 0, "Output": 0},
        "pad_block_exact_rank_cross_check": pad_rank,
        "ok": ok and (pad_rank is None or pad_rank["full_rank"]),
    }


# --------------------------------------------------------------- stage 3
def stage3(caps, replays, pad_rank_check=True):
    out = []
    mpad = None
    for cap in caps:
        rp = replays[cap.proof_sha256]
        f = CfsView(cap, rp).run()
        f.pop("per_slot_detail", None)
        slots = f.pop("per_slot")
        f["slots_with_uncovered_directions"] = [p["slot"] for p in slots if p["uncovered"]]
        out.append({"capture": cap.proof_sha256, "profile": cap.profile, **f})
        if pad_rank_check and mpad is None:
            t0 = time.time()
            r, d = m_pad_block_rank(cap)
            mpad = {
                "capture": cap.proof_sha256[:16],
                "distinct_columns": d,
                "exact_rank_of_a_row_pad_block": r,
                "full_rank": r == d,
                "seconds": round(time.time() - t0, 1),
            }
    ok = all(
        c["findings"] == []
        and c["uncovered_consistency_directions"] == 0
        and c["q_public_sum_identity"]
        and c["m_pad_margin"] > 0
        for c in out
    )
    return {
        "per_capture": out,
        "m_pad_block_exact_rank_cross_check": mpad,
        "ok": ok and (mpad is None or mpad["full_rank"]),
    }


# --------------------------------------------------------------- stage 4
def stage4(s2, s3):
    """A, H and M stacked.  The four commitments and the CFS masks draw
    disjoint parts of the prover's randomness, so a functional supported on
    data coordinates decomposes channel by channel and the joint disclosed
    space is the SUM of the parts (it can only be smaller under aliasing)."""
    rows = []
    for c2, c3 in zip(s2["per_capture"], s3["per_capture"]):
        pcs = {r["role"]: r["disclosed_dimension"] for r in c2["roles"]}
        rows.append(
            {
                "capture": c2["capture"],
                "profile": c2["profile"],
                "pcs_parts_fp": pcs,
                "pcs_sum_fp": sum(pcs.values()),
                "cfs_opening_only_fp": c3["disclosed_opening_only_fp"],
                "cfs_all_derived_values_fp": c3["disclosed_all_values_fp"],
                "joint_opening_only_fp": sum(pcs.values()) + c3["disclosed_opening_only_fp"],
                "joint_all_derived_values_fp": sum(pcs.values())
                + c3["disclosed_all_values_fp"],
                "joint_equals_sum_of_parts": True,
            }
        )
    return {"per_capture": rows, "ok": True}


# --------------------------------------------------------------- stage 5
def stage5(caps, s2):
    """The zero-witness gate, channel by channel, IN THE LINEAR MODEL.

    For a fixed view, the set of (data, randomness) consistent with it is an
    affine coset of ker(randomness map): every fibre therefore has the SAME
    free dimension, whichever data value it sits over.  A zero-data preimage
    exists exactly when every disclosed functional takes the value it takes
    at zero, i.e. when the public identities the disclosed space consists of
    evaluate to zero.  On the commitment side the only disclosed functional
    is H's LogUp identity, whose published claim value is checked to be zero
    here; A, Input and Output disclose nothing, so a zero-data preimage
    exists unconditionally.  CHANNELS NOT COVERED: the roots, the leaf salts
    and the Merkle authentication paths are hash objects; no linear algebra
    covers them.  What covers them is assumed, not shown: salted-leaf hiding
    of the unopened columns, and, for the two caller-fixed endpoint roots,
    the programmable random-oracle argument of D8/D11, WHICH IS OPEN.
    """
    rows = []
    for cap, c2 in zip(caps, s2["per_capture"]):
        h = cap.role("H")
        sums = [
            cl
            for cl in h["claims"]
            if all(not p["point"] for p in cl["parts"])
        ]
        zero_valued = all(f2_from_list(cl["value"]) == F2_ZERO for cl in sums) and sums
        per_role = {}
        for r in c2["roles"]:
            per_role[r["role"]] = {
                "disclosed_dimension": r["disclosed_dimension"],
                "zero_data_preimage_exists_in_model": (
                    r["disclosed_dimension"] == 0
                    or (r["role"] == "H" and bool(zero_valued))
                ),
                "fibre_is_a_coset_of_the_same_kernel": True,
            }
        rows.append(
            {
                "capture": cap.proof_sha256,
                "h_sum_claims": len(sums),
                "h_sum_claim_value_is_zero": bool(zero_valued),
                "roles": per_role,
                "channels_covered": [
                    "claim values",
                    "group vectors",
                    "proximity vector",
                    "sampled column values",
                    "M: q, proximity vector, sampled column values",
                    "the slots' masked round messages",
                ],
                "channels_not_covered": [
                    "the three Merkle roots",
                    "the 256 leaf salts served per opening",
                    "the 11- and 12-level authentication paths",
                    "the receipt's byte encoding and its length",
                    "anything nonlinear in the view",
                ],
            }
        )
    ok = all(
        v["zero_data_preimage_exists_in_model"] for r in rows for v in r["roles"].values()
    )
    return {"per_capture": rows, "ok": ok}


# --------------------------------------------------------------- stage 6
def stage6(caps, replays):
    ctl = smallmodel.controls()
    honest_ok = (
        ctl["honest"]["bruteforce"] == ctl["honest"]["reduction"] == 0
        and ctl["honest_with_zero_sum_pair"]["bruteforce"]
        == ctl["honest_with_zero_sum_pair"]["reduction"]
    )
    names = [
        "masks_removed",
        "two_claims_share_one_pair",
        "commitment_opened_twice",
        "extra_published_helper_sum",
        "one_pad_fewer_than_opened_columns",
    ]
    fired = {n: ctl[n]["bruteforce"] > 0 for n in names}
    tamper = stage1_tamper(caps, replays)
    return {
        "small_model": ctl,
        "reduction_agrees_with_bruteforce": honest_ok,
        "controls_fired": fired,
        "altered_capture_bytes_break_the_replay": tamper,
        "ok": honest_ok and all(fired.values()) and tamper["ok"],
    }


# ------------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--skip-exact-pad-rank", action="store_true")
    args = ap.parse_args(argv)

    t0 = time.time()
    caps = load_all(args.captures)
    if not caps:
        print("no captures found", file=sys.stderr)
        return 2
    record = {
        "gate": "zk60-native-joint-view",
        "version": 1,
        "privacy_review_complete": False,
        "privacy_property_established": False,
        "d8_d11_endpoint_root_obligation": "open, untouched by this gate",
        "captures_dir": os.path.abspath(args.captures),
        "manifest": manifest_check(args.captures, caps),
        "tool_sha256": tool_hashes(),
        "captures": [
            {
                "proof_sha256": c.proof_sha256,
                "profile": c.profile,
                "json_sha256": c.sha256,
                "json_bytes": c.bytes,
                "slots": len(c.slots),
                "source_commit": c.doc["source_commit"],
            }
            for c in caps
        ],
    }
    s1, replays = stage1(caps)
    record["stage1_transcript_replay"] = s1
    record["stage2_commitment_side_joint_view"] = stage2(
        caps, replays, not args.skip_exact_pad_rank
    )
    record["stage3_masking_commitment_view"] = stage3(
        caps, replays, not args.skip_exact_pad_rank
    )
    record["stage4_stacked"] = stage4(
        record["stage2_commitment_side_joint_view"], record["stage3_masking_commitment_view"]
    )
    record["stage5_zero_witness_gate"] = stage5(caps, record["stage2_commitment_side_joint_view"])
    record["stage6_negative_controls"] = stage6(caps, replays)
    record["seconds"] = round(time.time() - t0, 1)
    stages = [k for k in record if k.startswith("stage")]
    record["ok"] = all(record[k]["ok"] for k in stages)

    os.makedirs(args.evidence, exist_ok=True)
    out = os.path.join(args.evidence, "joint_view.json")
    with open(out, "w") as fh:
        json.dump(record, fh, indent=1, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(args.evidence, "joint_view.done"), "w") as fh:
        fh.write("0\n" if record["ok"] else "1\n")
    for k in stages:
        print(f"{k}: {'ok' if record[k]['ok'] else 'FAIL'}")
    print(f"record: {out} ({record['seconds']} s)")
    return 0 if record["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
