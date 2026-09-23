"""GS-4: was `audit_claims`' exclusivity OBSERVED at the 125M shape?

Reads (READ-ONLY) every committed 125M gate record of the joint-view lane
(`/home/victor/wt-zk60-jointview`, tip `adcd831`) and prints, per record and
per commitment, the leaves that the gate's H-pair check writes:

  reduction_hypotheses.H-pair   the gate's `_check_pair_schedule`
                                (zk60_native_jv_pcs.py:394-433, inherited by
                                zk60_native_rg_pcs.RunRoleView): every claim's
                                recomputed row weights, restricted to the
                                non-data rows, sit on exactly ONE adjacent pair
                                (or, for the LogUp sum claim, exactly on the
                                u pair), no pair is used by two claims, the
                                pair's two coefficients are an Fp-basis of Fp2,
                                no claim touches the proximity pair
  reserved_pairs_used           the number of DISTINCT pairs the claims use
  claims                        the number of claims
  reserved_mask_rows            non-data rows minus proximity minus u rows
  spare_mask_rows               mask rows NOT among the declared site rows
  sum_claims_on_u_rows / claims_evaluating_u_rows
  group_claim_identity_failures / column_identity_failures
                                the two identities that bind the recomputed
                                row weights to the receipt's published bytes
  findings                      any failure the view recorded

and derives, per commitment, the exclusivity verdict
  exclusive := H-pair and findings == [] and reserved_pairs_used == claims
  surjective := 2*(reserved_pairs_used - sum_claims) == reserved_mask_rows - spare
(every reserved pair row used exactly once, the `audit_claims` "every site row
used exactly once" clause), with the u pair counted once for the sum claim.

Nothing here is a privacy property.
"""

from __future__ import annotations

import json
import os
import sys

JV = "/home/victor/wt-zk60-jointview/results"
RECORDS = [
    # (round, path) -- two-block RUN records at 125M
    ("9 (run, dense)", "zk60_native_run_gate_m125/m125-dense.json"),
    ("9 (run, zero)", "zk60_native_run_gate_m125/m125-zero.json"),
    ("9c (run, dense, every stage)", "zk60_native_run_gate_m125/m125-dense-everything.json"),
    ("9 (run, dense, full arm)", "zk60_native_run_gate_m125/m125-dense-full.json"),
    ("9 (run, zero, full arm)", "zk60_native_run_gate_m125/m125-zero-full.json"),
    # STANDALONE 125M block records
    ("9j (block, dense)", "zk60_native_run_gate_block/block-m125-dense.json"),
    ("9j (block, zero)", "zk60_native_run_gate_block/block-m125-zero.json"),
    ("9j (block, dense, every stage)", "zk60_native_run_gate_block/block-m125-dense-everything.json"),
    ("9k (block, dense, C3c)", "zk60_native_run_gate_9k/block-m125-dense-c3c.json"),
    ("9k (block, zero, C3c)", "zk60_native_run_gate_9k/block-m125-zero-c3c.json"),
]
# rung-G, for the comparison the lemma's §4.D makes ("observed at rung-G on
# two captures")
RUNG_G = [
    ("rung-G run, tame (round 1)", "zk60_native_run_gate/run-a-tame.json"),
    ("rung-G run, zero (round 1)", "zk60_native_run_gate/run-b-zero.json"),
    ("rung-G run, dense (round 4)", "zk60_native_run_gate_s20/run-g-dense-s20.json"),
]


def per_commitment(rec):
    s3 = rec.get("stage3_per_commitment")
    if not s3:
        return None
    return s3.get("per_commitment")


def row(label, pc):
    hp = pc.get("reduction_hypotheses", {})
    claims = pc.get("claims")
    used = pc.get("reserved_pairs_used")
    sums = pc.get("sum_claims_on_u_rows", 0)
    mask = pc.get("reserved_mask_rows")
    spare = len(pc.get("spare_mask_rows") or [])
    exclusive = bool(hp.get("H-pair")) and not pc.get("findings") and used == claims
    surjective = (mask is not None) and 2 * (used - sums) == mask - spare
    return {
        "record": label,
        "role": pc.get("role"),
        "kind": pc.get("commitment_kind"),
        "rows": pc.get("rows"),
        "claims": claims,
        "groups": pc.get("groups"),
        "reserved_pairs_used": used,
        "reserved_mask_rows": mask,
        "spare_mask_rows": spare,
        "sum_claims_on_u_rows": sums,
        "claims_evaluating_u_rows": pc.get("claims_evaluating_u_rows"),
        "H_pair": hp.get("H-pair"),
        "H_prox": hp.get("H-prox"),
        "H_pad": hp.get("H-pad"),
        "group_claim_identity_failures": pc.get("group_claim_identity_failures"),
        "group_claim_identities_checked": pc.get("group_claim_identities_checked"),
        "column_identity_failures": pc.get("column_identity_failures"),
        "column_identity_checked": pc.get("column_identity_checked"),
        "findings": pc.get("findings"),
        "k0": pc.get("k0"),
        "disclosed_dimension": pc.get("disclosed_dimension"),
        "exclusive": exclusive,
        "every_reserved_row_used_once": surjective,
    }


def main():
    out = {"records": [], "rows": [], "rung_g_rows": []}
    for label, rel in RECORDS + RUNG_G:
        path = os.path.join(JV, rel)
        if not os.path.exists(path):
            out["records"].append({"record": label, "path": rel, "present": False})
            continue
        rec = json.load(open(path))
        pcs = per_commitment(rec)
        out["records"].append(
            {
                "record": label,
                "path": rel,
                "present": True,
                "has_stage3": pcs is not None,
                "commitments": None if pcs is None else len(pcs),
                "bundle": rec.get("bundle"),
                "stages_run": rec.get("stages_run"),
            }
        )
        if pcs is None:
            continue
        for pc in pcs:
            r = row(label, pc)
            r["path"] = rel
            (out["rung_g_rows"] if (label, rel) in RUNG_G else out["rows"]).append(r)

    rows = out["rows"]
    out["summary_125m"] = {
        "records_with_stage3": sum(1 for r in out["records"] if r.get("has_stage3") and (r["record"], r["path"]) not in RUNG_G),
        "commitment_views": len(rows),
        "exclusive_everywhere": all(r["exclusive"] for r in rows),
        "every_reserved_row_used_once_everywhere": all(r["every_reserved_row_used_once"] for r in rows),
        "claims_total": sum(r["claims"] for r in rows),
        "distinct_pairs_total": sum(r["reserved_pairs_used"] for r in rows),
        "kinds": sorted({r["kind"] for r in rows}),
        "identity_failures_total": sum(
            (r["group_claim_identity_failures"] or 0) + (r["column_identity_failures"] or 0) for r in rows
        ),
    }
    json.dump(out, sys.stdout, indent=1, sort_keys=True)
    print()
    print("\n# table: record | role | claims | distinct pairs | mask rows | spare | sum-on-u | H-pair | exclusive | used-once", file=sys.stderr)
    for r in rows + out["rung_g_rows"]:
        print(
            f"{r['record']:34s} {r['role']:9s} {r['claims']:4d} {r['reserved_pairs_used']:4d} "
            f"{r['reserved_mask_rows']:4d} {r['spare_mask_rows']:2d} {r['sum_claims_on_u_rows']:2d} "
            f"{str(r['H_pair']):5s} {str(r['exclusive']):5s} {str(r['every_reserved_row_used_once']):5s}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
