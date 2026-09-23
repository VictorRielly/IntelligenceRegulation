"""GS-4, second and INDEPENDENT observation: `audit_claims` re-run on 125M bytes.

The run gate's H-pair leaf (gs4_exclusivity_records.py) is one observation,
made by the gate's own weight-level port.  This script is a second one, by a
different route: it transcribes the Rust refusal code LITERALLY, at the lane
tip `2ea7221` of `/home/victor/wt-zk60-block125m` (read-only), and runs it on
the claim lists the four 125M captures carry:

  part_rows            hashline/src/private_block/protocol.rs:215-218
  audit_claims         protocol.rs:230-274
  part_key_at          protocol.rs:186-192
  opening_groups_at    protocol.rs:200-213
  check_opening        protocol.rs:318-328 (audit -> exact group count; the
                       challenge replay is NOT transcribed: it needs the
                       transcript, which the gate replays separately)
  endpoint_geometry    protocol.rs:356-370
  check_endpoint_opening protocol.rs:376-390 (the claim-shape half)
  boundary geometry    boundary.rs:186-197 (data + 2*sites + 2, site rows,
                       prox row), boundary::check_opening boundary.rs:287-289

Inputs, READ-ONLY, outside every repository (only the JSON is read; the
array store is never opened, because every claim is inline):
  /home/victor/zk60-artifacts/m125-capture-dense-l2/   two-block run, dense
  /home/victor/zk60-artifacts/m125-capture-zero-l2/    two-block run, all-zero
  /home/victor/zk60-artifacts/block-captures-20260923/m125-dense/  standalone
  /home/victor/zk60-artifacts/block-captures-20260923/m125-zero/   standalone

The geometry the audit is called with is DERIVED here from the shape and the
commitment's own row count, and only then compared with what the capture
declares (`site_rows`, `sum_rows`, `prox_row`), so a writer that declared the
wrong rows cannot make the audit pass by construction.

Negative controls (each must be refused, BY NAME, on the real claim lists):
  N1  claim 1's mask pair moved onto claim 0's pair           -> "unused or shared"
  N2  claim 0's first mask coefficient set to zero            -> "zero terminal mask coefficient"
  N3  claim 0's second mask part moved onto the proximity row -> "reaches the proximity pair"
  N4  H's LogUp sum claim moved to the FRONT of the list      -> "unexpected sum claim"
  N5  claim 0's pair shifted down one row (odd parity)        -> "does not carry exactly its own reserved pair"
  N6  the boundary's site-1 claim moved onto site 0's pair    -> "unused or shared"
  N7  an endpoint claim's mask part moved one row             -> "endpoint claim differs"

Nothing here is a privacy property.
"""

from __future__ import annotations

import copy
import json
import os
import sys

ART = "/home/victor/zk60-artifacts"
BUNDLES = [
    ("run dense (m125-capture-dense-l2)", f"{ART}/m125-capture-dense-l2", "run"),
    ("run zero (m125-capture-zero-l2)", f"{ART}/m125-capture-zero-l2", "run"),
    ("block dense (block-captures-20260923/m125-dense)", f"{ART}/block-captures-20260923/m125-dense", "block"),
    ("block zero (block-captures-20260923/m125-zero)", f"{ART}/block-captures-20260923/m125-zero", "block"),
]
ENDPOINT_MASK_ROWS = 5  # protocol.rs:341
ENDPOINT_ROWS, ENDPOINT_PROX = 7, 4  # protocol.rs:337-338


def is_zero(c):
    return c[0] == 0 and c[1] == 0


# ---------------------------------------------------- transcriptions (Rust)
def part_rows(p, n):
    """protocol.rs:215-218: r0 .. r0 + ceil(2^log_size / n)."""
    r0 = p["offset"] // n
    return range(r0, r0 + -(-(1 << p["log_size"]) // n))


def audit_claims(claims, n, rows, site_rows, sum_rows, prox):
    """protocol.rs:230-274, statement for statement.  Returns (None, uses) or (msg, uses)."""
    pre = "private block: mask schedule audit: "
    if prox + 2 != rows or len(site_rows) % 2 != 0:
        return pre + "proximity pair placement", None
    uses = [0] * rows
    site = set(site_rows)
    for ci, claim in enumerate(claims):
        touched = []
        for part in claim["parts"]:
            pr = part_rows(part, n)
            if pr.stop > prox:
                return pre + "a claim reaches the proximity pair or leaves the commitment", uses
            for r in pr:
                if r in site:
                    if is_zero(part["coefficient"]):
                        return pre + "zero terminal mask coefficient; discard attempt", uses
                    touched.append(r)
        is_sum = all(len(p["point"]) == 0 for p in claim["parts"])
        if is_sum and sum_rows is not None and ci + 1 == len(claims):
            def covered(row):
                return any(row in part_rows(p, n) and not is_zero(p["coefficient"]) for p in claim["parts"])
            if touched or not covered(sum_rows[0]) or not covered(sum_rows[1]):
                return pre + "the sum claim is not masked by the zero-sum pair alone", uses
        elif not is_sum:
            if len(touched) != 2 or touched[1] != touched[0] + 1 or (touched[0] - site_rows[0]) % 2 != 0:
                return pre + "a claim does not carry exactly its own reserved pair", uses
        else:
            return pre + "unexpected sum claim", uses
        for r in touched:
            uses[r] += 1
    if any(uses[r] != 1 for r in site_rows):
        return pre + "a reserved pair is unused or shared between claims", uses
    return None, uses


def part_key_at(p, log_n):
    """protocol.rs:186-192."""
    n = 1 << log_n
    ls = p["log_size"]
    if ls >= log_n:
        c0, ln = 0, n
    else:
        c0, ln = p["offset"] % n, 1 << ls
    tail = () if not p["point"] else tuple(tuple(v) for v in p["point"][max(0, ls - log_n):])
    return (tail, c0, ln)


def opening_groups_at(claims, log_n):
    """protocol.rs:200-213, first-occurrence order."""
    groups = []
    for claim in claims:
        key = part_key_at(claim["parts"][0], log_n)
        if any(part_key_at(p, log_n) != key for p in claim["parts"]):
            return "private block: claim parts with different column weights"
        for g in groups:
            if g[0] == key:
                g[1] += 1
                break
        else:
            groups.append([key, 1])
    return [c for _, c in groups]


def check_opening_no_replay(claims, log_n, rows, site_rows, sum_rows, prox, want_groups):
    """protocol.rs:318-325 (the replay at :326-327 is left to the gate)."""
    err, uses = audit_claims(claims, 1 << log_n, rows, site_rows, sum_rows, prox)
    if err:
        return err, uses, None
    groups = opening_groups_at(claims, log_n)
    if isinstance(groups, str):
        return groups, uses, None
    if len(groups) != want_groups:
        return f"private block: {len(groups)} opening groups, the schedule declares {want_groups}", uses, groups
    return None, uses, groups


def endpoint_geometry(endpoint_rows):
    """protocol.rs:356-370."""
    rows = endpoint_rows
    if rows <= ENDPOINT_MASK_ROWS:
        return None
    g = (rows, rows - ENDPOINT_MASK_ROWS, rows - ENDPOINT_MASK_ROWS + 2)
    if rows == ENDPOINT_ROWS and g != (ENDPOINT_ROWS, 2, ENDPOINT_PROX):
        return None
    return g


def check_endpoint_claims(claims, endpoint_rows, endpoint_log_n):
    """protocol.rs:376-387 (the claim-shape half)."""
    rows, data, prox = endpoint_geometry(endpoint_rows)
    n = 1 << endpoint_log_n
    ok = (
        len(claims) == 1
        and len(claims[0]["parts"]) == 3
        and part_rows(claims[0]["parts"][0], n) == range(0, data)
        and part_rows(claims[0]["parts"][1], n) == range(data, data + 1)
        and part_rows(claims[0]["parts"][2], n) == range(data + 1, data + 2)
        and all(not is_zero(p["coefficient"]) for p in claims[0]["parts"])
    )
    return None if ok else "private block: endpoint claim differs from the declared schedule"


# ------------------------------------------------------------- the bundles
def roles_of(bundle_dir, kind):
    if kind == "run":
        run = json.load(open(os.path.join(bundle_dir, "run.json")))
        shape = run["shape"]
        out = []
        for k, fn in enumerate(run["stage_files"]):
            st = json.load(open(os.path.join(bundle_dir, fn)))
            for r in st["roles"]:
                out.append((k, r))
        return shape, out, run.get("internal_boundaries", [])
    blk = json.load(open(os.path.join(bundle_dir, "block.json")))
    obs = json.load(open(os.path.join(bundle_dir, "observations.json")))
    return blk["shape"], [(0, r) for r in obs["roles"]], []


def check_role(shape, stage, role, boundaries):
    kind = role["commitment_kind"]
    rows = role["commitment"]["rows"]
    claims = role["claims"]
    for c in claims:
        for p in c["parts"]:
            if not isinstance(p["point"], list) or not isinstance(p["coefficient"], list):
                raise ValueError("a claim part is not inline; this script reads JSON only")
    rec = {"stage": stage, "role": role["role"], "kind": kind, "rows": rows, "claims": len(claims)}
    log_n = role["params"]["log_cols"]
    if kind == "external-endpoint":
        rows_g, data, prox = endpoint_geometry(shape["endpoint_rows"])
        derived = {"rows": rows_g, "site_rows": [data, data + 1], "prox_row": prox, "sum_rows": None,
                   "spare_rows": list(range(prox + 2, rows_g))}
        err = check_endpoint_claims(claims, shape["endpoint_rows"], shape["endpoint_log_n"])
        uses = None
        groups = opening_groups_at(claims, log_n)
        want = 1
    else:
        if kind == "internal-boundary":
            b = boundaries[role["boundary"]]
            data = (b["plane"][0] * b["plane"][1]) >> b["log_n"]  # BoundarySpec::data_rows = len >> log_n
            sites = b["sites"]
            derived = {"rows": data + 2 * sites + 2, "site_rows": list(range(data, data + 2 * sites)),
                       "prox_row": data + 2 * sites, "sum_rows": None, "spare_rows": []}
            want = sites
        else:  # a block commitment, A or H
            prox = rows - 2
            if role["role"] == "A":
                data = role["data_rows"]
                derived = {"rows": rows, "site_rows": list(range(data, prox)), "prox_row": prox,
                           "sum_rows": None, "spare_rows": []}
                want = shape["a_groups"]
            else:
                data = role["data_rows"]  # includes the two zero-sum rows (the writer's h_data_rows)
                derived = {"rows": rows, "site_rows": list(range(data, prox)), "prox_row": prox,
                           "sum_rows": [data - 2, data - 1], "spare_rows": []}
                want = shape["h_groups"]
        err, uses, groups = check_opening_no_replay(
            claims, log_n, derived["rows"], derived["site_rows"], derived["sum_rows"], derived["prox_row"], want
        )
    rec["derived_geometry_equals_declared"] = (
        derived["rows"] == rows
        and derived["site_rows"] == role["site_rows"]
        and derived["prox_row"] == role["prox_row"]
        and derived["sum_rows"] == role["sum_rows"]
    )
    rec["site_rows"] = len(derived["site_rows"])
    rec["refusal"] = err
    rec["accepted"] = err is None
    if uses is not None:
        su = [uses[r] for r in derived["site_rows"]]
        rec["site_row_uses_min_max"] = [min(su), max(su)] if su else None
        # rows at or above the first reserved row that are NOT reserved pair
        # rows (i.e. the proximity pair) and that any claim part reaches
        rec["proximity_rows_touched_by_a_claim"] = sorted(
            {r for c in claims for p in c["parts"] for r in part_rows(p, 1 << log_n)
             if r >= (derived["site_rows"][0] if derived["site_rows"] else rows) and r not in set(derived["site_rows"])}
        )
    if groups is None:  # the audit refused before any grouping was formed
        rec["opening_groups"] = None
    else:
        rec["opening_groups"] = groups if isinstance(groups, str) else len(groups)
    rec["groups_declared"] = want
    rec["group_sizes"] = groups if isinstance(groups, list) else None
    if kind == "block" and role["role"] == "A" and isinstance(groups, list):
        # the shaped check's B-7 distribution, DERIVED there from claim_sites
        # and the declared a_groups detail (ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md
        # §B-7); here compared as a multiset with what the real claims form
        b7 = ([6] + [2] * 8 + [1, 1] + [2] + [2] + [1] * 3 + [1, 1] + [1, 1] + [1] + [1] * 3
              + [35, 2] + [7, 1] + [6, 1] + [13, 2] + [11] + [3] + [1, 1])
        rec["a_group_multiset_equals_check_B7"] = sorted(groups) == sorted(b7)
        rec["a_largest_group"] = max(groups)
        rec["a_singleton_groups"] = sum(1 for g in groups if g == 1)
    return rec


def controls(shape, roles, boundaries):
    """N1..N7 on the first stage's real claim lists.  Each must be refused by name."""
    out = {}
    by = {}
    for stage, r in roles:
        by.setdefault((r["commitment_kind"], r["role"]), (stage, r))

    def run(name, stage, role, mutate, want):
        r2 = copy.deepcopy(role)
        mutate(r2)
        got = check_role(shape, stage, r2, boundaries)["refusal"]
        out[name] = {"refusal": got, "expected_substring": want, "fires_by_name": bool(got) and want in got}

    stA, A = by[("block", "A")]
    n = 1 << A["params"]["log_cols"]

    def n1(r):  # claim 1's pair onto claim 0's pair
        p0 = [p for p in r["claims"][0]["parts"] if p["offset"] // n >= r["data_rows"]]
        p1 = [p for p in r["claims"][1]["parts"] if p["offset"] // n >= r["data_rows"]]
        for a, b in zip(p1, p0):
            a["offset"] = b["offset"]

    def n2(r):
        m = [p for p in r["claims"][0]["parts"] if p["offset"] // n >= r["data_rows"]]
        m[0]["coefficient"] = [0, 0]

    def n3(r):
        m = [p for p in r["claims"][0]["parts"] if p["offset"] // n >= r["data_rows"]]
        m[1]["offset"] = r["prox_row"] * n

    def n5(r):
        m = [p for p in r["claims"][0]["parts"] if p["offset"] // n >= r["data_rows"]]
        for p in m:
            p["offset"] += n

    run("N1_shared_pair_on_A", stA, A, n1, "unused or shared")
    run("N2_zero_mask_coefficient_on_A", stA, A, n2, "zero terminal mask coefficient")
    run("N3_mask_part_on_the_proximity_row_of_A", stA, A, n3, "reaches the proximity pair")
    run("N5_pair_shifted_one_row_on_A", stA, A, n5, "does not carry exactly its own reserved pair")

    stH, H = by[("block", "H")]

    def n4(r):
        r["claims"].insert(0, r["claims"].pop())

    run("N4_sum_claim_not_last_on_H", stH, H, n4, "unexpected sum claim")

    if ("internal-boundary", "Input") in by:
        stB, B = by[("internal-boundary", "Input")]
        nb = 1 << B["params"]["log_cols"]

        def n6(r):
            p0 = [p for p in r["claims"][0]["parts"] if p["offset"] // nb >= 32]
            p1 = [p for p in r["claims"][1]["parts"] if p["offset"] // nb >= 32]
            for a, b in zip(p1, p0):
                a["offset"] = b["offset"]

        run("N6_boundary_site1_onto_site0", stB, B, n6, "unused or shared")

    stE, E = by[("external-endpoint", "Input")]
    ne = 1 << shape["endpoint_log_n"]

    def n7(r):
        r["claims"][0]["parts"][2]["offset"] += ne

    run("N7_endpoint_mask_part_moved", stE, E, n7, "endpoint claim differs")
    return out


def main():
    report = {"lane_tip_transcribed": "2ea7221", "bundles": []}
    for label, d, kind in BUNDLES:
        shape, roles, boundaries = roles_of(d, kind)
        recs = [check_role(shape, st, r, boundaries) for st, r in roles]
        report["bundles"].append(
            {
                "bundle": label,
                "dir": d,
                "shape": shape["name"],
                "log_cols": shape["log_cols"],
                "commitments": recs,
                "all_accepted": all(r["accepted"] for r in recs),
                "all_geometry_derived_equals_declared": all(r["derived_geometry_equals_declared"] for r in recs),
                "controls": controls(shape, roles, boundaries),
            }
        )
    report["summary"] = {
        "commitment_openings": sum(len(b["commitments"]) for b in report["bundles"]),
        "accepted": sum(r["accepted"] for b in report["bundles"] for r in b["commitments"]),
        "geometry_derived_equals_declared": all(b["all_geometry_derived_equals_declared"] for b in report["bundles"]),
        "controls_fired_by_name": sum(c["fires_by_name"] for b in report["bundles"] for c in b["controls"].values()),
        "controls": sum(len(b["controls"]) for b in report["bundles"]),
    }
    json.dump(report, sys.stdout, indent=1)
    print()
    for b in report["bundles"]:
        print(f"# {b['bundle']}", file=sys.stderr)
        for r in b["commitments"]:
            print(
                f"  stage {r['stage']} {r['role']:6s} {r['kind']:18s} rows {r['rows']:5d} claims {r['claims']:3d} "
                f"sites {r['site_rows']:3d} uses {r.get('site_row_uses_min_max')} groups {r['opening_groups']}/{r['groups_declared']} "
                f"geometry== {r['derived_geometry_equals_declared']} accepted {r['accepted']} {r['refusal'] or ''}",
                file=sys.stderr,
            )
        for k, c in b["controls"].items():
            print(f"  control {k}: fires_by_name={c['fires_by_name']}  ({c['refusal']})", file=sys.stderr)
    print("# summary", json.dumps(report["summary"]), file=sys.stderr)


if __name__ == "__main__":
    main()
