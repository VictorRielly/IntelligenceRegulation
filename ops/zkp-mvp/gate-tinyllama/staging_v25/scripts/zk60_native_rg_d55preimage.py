#!/usr/bin/env python3
"""[v25 STAGING, 2026-11-02, NL-1 / PRE lane] THE FULL ZERO-DATA PREIMAGE on a
D55 ("commit, fork, join") fork-run capture: every fork's A and H at
MSG != PAD (both halves), every tail commitment (each internal boundary,
both external endpoints), every opened column and the salted leaves of the
opened columns.

    python3 -B zk60_native_rg_d55preimage.py --bundle <D55 bundle> --evidence <dir> [--name N]

Called from `zk60_native_rg_d55.d55_gate` (part `PRE full zero-data
preimage`) with the per-commitment views of `d55_stage3`; standalone it runs
the D55 loader, the replay and `d55_stage3` first.

WHAT WAS PORTED.  The D12a run gate's stage 11 (`zk60_native_run_gate.stage11`,
round 7, opt-in `--full-preimage` there): `zk60_native_rg_ahpreimage.full_preimages`
on every PCS commitment of the run and `zk60_native_rg_ahcontrols.ah_controls`
(P-1 .. P-6) on one stage's A and H -- both IMPORTED UNCHANGED.  At D55 the
commitments are the forks' (A@k, H@k; a fork commits no boundary) and the
TAIL's (B0 .. B{L-2}, E-Input, E-Output: every boundary is committed in the
head and opened once in the tail), exactly the views `d55_stage3` ranks.  The
controls run on fork kc (the interior fork 1, else 0).

WHAT IT SHOWS, per commitment: blinding r' with the hidden data set to ZERO
(a public object; no capture carries a witness and none is read) such that
the forward map reproduces EVERY published entry -- each opening group's
vector (message half n and pad half Q), the proximity vector (both halves),
every claim value, every row of every opened column -- and the opened
columns rebuilt from (0, r') re-hash under the bundle's own rule and
authenticate against the PUBLISHED salts and Merkle paths to the root.

D55 CHECKS on top of `full_preimages`' own verdict:
  * every fork's A and H and every tail commitment is in the set and is
    exhibited (nothing skipped);
  * A and H are solved at MSG != PAD (n message positions, Q pad symbols);
  * every commitment's salted leaves: rehashed == authenticated == its opened
    columns (256 with replacement).

CONTROLS (each must fire, or the part is false; nothing on disk is written):
  P-1 .. P-6  `ah_controls` on fork kc's A and H, unchanged (one opened
              column entry moved; a group-vector entry moved, message half /
              pad half; one pad fewer than the distinct columns; a blinding
              row shared between A and H; a fixed input off H's disclosed
              identity) -- D12a's rule: a control the layout gives no object
              is reported NOT APPLICABLE by name, and a family with none
              applicable is not a pass;
  PRE-T1      an OPENED COLUMN entry of the tail's first boundary moved by one
              (`ah_controls.p1_opened_column_entry` on B0): no preimage;
  PRE-T2 / PRE-A2  a PAD/MSG SWAP: one group's first Q message entries and its
              Q pad entries exchanged in the published vector (the tail's B0;
              fork kc's A): no preimage -- the solve tells the two halves apart;
  PRE-T3 / PRE-A3  a SALTED LEAF changed: one opened column rebuilt from the
              exhibited (0, r') authenticates under its published salt and
              path (honest), and does NOT with one salt bit flipped, one path
              node bit flipped, or one rebuilt entry moved by one (B0; fork
              kc's A, re-solved for the purpose).

WHAT IT DOES NOT SHOW (`full_preimages`' own list): the LAW of the blinding
(existence is not uniformity on the fibre); the masking commitment M's rows
(the CFS channel: part R13-7); an UNOPENED Merkle leaf (M-2 / M-3, argued);
anything nonlinear (NL-1).  NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import types
from operator import mul

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import P  # noqa: E402
from zk60_native_rg_ahcontrols import ah_controls, p1_opened_column_entry  # noqa: E402
from zk60_native_rg_ahpreimage import (  # noqa: E402  -- imported, never re-implemented
    WideRolePreimage,
    full_preimages,
    layout_for_view,
    preimage_for_view,
)

PART = "PRE full zero-data preimage"
NOT_HERE_CLOSED = "the full zero-data preimage (A and H at MSG != PAD)"


def commitment_order(b, views) -> list:
    """every fork's A and H in fork order, then the tail's openings in order:
    the views `d55_stage3` built (a missing one is a finding, not a skip)"""
    want = [b.stages[k].key(r) for k in range(b.blocks) for r in ("A", "H")]
    want += [b.tail.key_at(i) for i in range(len(b.tail.roles))]
    return want


def _control_fork(b, control_fork=None):
    if control_fork is not None:
        return control_fork
    return 1 if b.blocks > 1 else 0


def _tail_control_key(b):
    return "B0" if b.boundaries else "E-Input"


# ---------------------------------------------------------------- the salted-leaf control
def rebuild_column(pre, j) -> list:
    """one opened column re-encoded from the exhibited rows (0, r'), exactly as
    `WideRolePreimage.verify` re-encodes it"""
    L = pre.L
    m = L.m
    emsg, epad = L.emsg[j], L.epad[j]
    col = []
    for i in range(L.rows):
        xi = pre.X[i]
        msg = xi[:m]
        got = sum(map(mul, xi[m:], epad))
        if any(msg):
            got += sum(map(mul, msg, emsg))
        col.append(got % P)
    return col


def _flip(bs: list, at: int) -> list:
    out = list(bs)
    out[at] = out[at] ^ 1
    return out


def salted_leaf_control(pre, view, name, rule) -> dict:
    """`WideRolePreimage._hash_layer` (the method, unchanged) on ONE opened
    column rebuilt from the exhibited preimage: the published salt and path
    authenticate it; one salt bit, one path-node bit or one rebuilt entry
    changed must not"""
    root = view.role["commitment"]["root"]
    c = view.role["columns"][0]
    j = c["index"]
    col = rebuild_column(pre, j)

    def layer(column, values):
        ns = types.SimpleNamespace(L=types.SimpleNamespace(v=types.SimpleNamespace(role={"columns": [column]}), name=name))
        return WideRolePreimage._hash_layer(ns, {j: values}, rule, root)

    honest = layer(c, col)
    moved = list(col)
    moved[len(moved) // 2] = (moved[len(moved) // 2] + 1) % P
    bad_path = [list(x) for x in c["path"]]
    bad_path[0] = _flip(bad_path[0], 0)
    cases = {
        "salt one bit flipped": layer(dict(c, salt=_flip(list(c["salt"]), 0)), col),
        "path node one bit flipped": layer(dict(c, path=bad_path), col),
        "rebuilt entry moved by one": layer(c, moved),
    }
    honest_ok = bool(honest.get("ok")) and honest["salted_leaves_authenticated"] == 1 and col == list(c["values"])
    rows = {k: {"authenticated": v["salted_leaves_authenticated"], "refused": not v.get("ok"),
                "failure": (v["failures"] or [None])[0]} for k, v in cases.items()}
    return {"what": f"{name}: opened column {j} rebuilt from the exhibited (0, r'), re-hashed under the bundle's rule and "
                    "folded along its published salt and path (the hash layer's own method)",
            "column_index": j, "honest_rebuilt_equals_the_published_column": col == list(c["values"]),
            "honest_authenticates": honest_ok, "perturbed": rows,
            "fires": honest_ok and all(r["refused"] and r["authenticated"] == 0 for r in rows.values())}


# ---------------------------------------------------------------- the PAD/MSG swap control
def pad_msg_swap(view, name, honest_ok, group=0) -> dict:
    """one group's published vector with its first Q message entries and its Q
    pad entries EXCHANGED (the halves swapped): no preimage"""
    layout = layout_for_view(view, name=name)
    m, q = layout.m, layout.q
    g = min(group, len(layout.groups) - 1)
    v = list(layout.gvec[g])
    v[:q], v[m:m + q] = v[m:m + q], v[:q]
    changed = sum(1 for a, b_ in zip(v, layout.gvec[g]) if a != b_)
    layout.gvec[g] = v
    bad = WideRolePreimage(layout).build()
    refusal = bad.fail[0] if bad.fail else None
    named = bool(refusal) and ("not reachable from the opened columns" in refusal or "cannot be met inside the kernel" in refusal)
    return {"what": f"{name}: group {g}'s published vector with message entries [0, {q}) and pad entries [{m}, {m + q}) "
                    f"exchanged (MSG n = {m}, PAD Q = {q})",
            "entries_changed": changed, "honest_preimage_exhibited": bool(honest_ok), "refused": bool(bad.fail),
            "refusal": refusal, "refusal_names_the_step": named,
            "fires": bool(honest_ok) and bool(bad.fail) and named and changed > 0}


# ---------------------------------------------------------------- the part
def d55_full_preimage(b, views, controls=True, control_fork=None) -> dict:
    t0 = time.time()
    order = commitment_order(b, views)
    missing = [nm for nm in order if nm not in views]
    rec = full_preimages(b, views, names=[nm for nm in order if nm in views])
    rec["ported_from"] = "zk60_native_run_gate.stage11 (D12a, round 7): full_preimages + ah_controls, both unchanged"
    rec["requested"] = True
    per = {p["commitment"]: p for p in rec["per_commitment"]}
    facts, f = [], list(f"{nm}: no view (not ranked by d55_stage3)" for nm in missing)
    for nm in order:
        p = per.get(nm)
        if p is None:
            continue
        sysd = p["system"]
        ver = p.get("verification") or {}
        hl = ver.get("hash_layer") or {}
        ncols = len(views[nm].role["columns"])
        row = {"commitment": nm, "kind": p["commitment_kind"], "rows": sysd["rows"], "data_rows": sysd["data_rows"],
               "groups": sysd["groups"], "claims": sysd["claims"], "msg_n": sysd["message_positions_n"],
               "pad_Q": sysd["pad_symbols_Q"], "distinct_opened_columns": sysd["distinct_opened_columns_d"],
               "opened_columns": ncols, "entries_compared": ver.get("entries_compared"),
               "entries_differing": None if not ver else (ver["group_vector_mismatches"] + ver["proximity_mismatches"]
                                                          + ver["claim_value_mismatches"] + ver["column_mismatches"]),
               "columns_rehashed": hl.get("columns_rehashed"), "salted_leaves_authenticated": hl.get("salted_leaves_authenticated"),
               "exhibited": p["preimage_exhibited"], "fibre_dimension_fp": (p.get("fibre") or {}).get("fibre_dimension_fp"),
               "seconds": p.get("seconds")}
        row["msg_ne_pad"] = row["msg_n"] != row["pad_Q"]
        row["every_leaf_authenticated"] = bool(hl.get("checked")) and row["columns_rehashed"] == ncols == row["salted_leaves_authenticated"]
        if not row["exhibited"]:
            f.append(f"{nm}: no preimage exhibited ({(p.get('solve_findings') or ['verification differs'])[0]})")
        if nm[:2] in ("A@", "H@") and not row["msg_ne_pad"]:
            f.append(f"{nm}: solved at MSG == PAD, not the run's shape")
        if not row["every_leaf_authenticated"]:
            f.append(f"{nm}: {row['salted_leaves_authenticated']} of {ncols} opened columns' salted leaves authenticated")
        facts.append(row)
    rec["d55"] = {"what": "every fork's A and H and every tail commitment, each exhibited at d = 0, A / H at MSG != PAD, "
                          "every opened column's salted leaf authenticated",
                  "commitments_expected": order, "per_commitment": facts,
                  "forks": b.blocks, "tail_commitments": len(b.tail.roles), "findings": f, "ok": not f}
    ok = bool(rec["ok"]) and not f
    if controls:
        kc = _control_fork(b, control_fork)
        a, h = b.stages[kc].key("A"), b.stages[kc].key("H")
        ts = time.time()
        rec["controls"] = ah_controls(b, views, a_name=a, h_name=h)
        rec["controls"]["seconds"] = round(time.time() - ts, 1)
        ts = time.time()
        rec["d55_controls"] = d55_pre_controls(b, views, kc, per)
        rec["d55_controls"]["seconds"] = round(time.time() - ts, 1)
        ok = ok and bool(rec["controls"].get("ok")) and bool(rec["d55_controls"].get("ok"))
    else:
        rec["controls"] = {"skipped": "controls not requested", "ok": False}
    rec["ok"] = ok
    rec["seconds"] = round(time.time() - t0, 1)
    return rec


def d55_pre_controls(b, views, kc, per) -> dict:
    out = {}
    rule = b.hash_rule
    tk = _tail_control_key(b)
    tv = views[tk]
    ak = b.stages[kc].key("A")
    av = views[ak]
    # PRE-T1: an opened column entry of the tail's first boundary moved
    p1 = p1_opened_column_entry(tv, tk)
    out["PRE-T1 an opened column changed (tail)"] = dict(p1, control="PRE-T1", on=tk)
    # PRE-T2 / PRE-A2: the PAD/MSG swap
    out["PRE-T2 a PAD/MSG swap (tail)"] = dict(pad_msg_swap(tv, tk, per.get(tk, {}).get("preimage_exhibited")), control="PRE-T2", on=tk)
    out["PRE-A2 a PAD/MSG swap (fork A)"] = dict(pad_msg_swap(av, ak, per.get(ak, {}).get("preimage_exhibited")), control="PRE-A2", on=ak)
    # PRE-T3 / PRE-A3: a salted leaf changed (the honest solve re-taken to keep its rows)
    for cid, key, view in (("PRE-T3", tk, tv), ("PRE-A3", ak, av)):
        _rec, pre = preimage_for_view(view, name=key, verify=False)
        if pre.fail:
            out[f"{cid} a salted leaf changed ({'tail' if cid == 'PRE-T3' else 'fork A'})"] = {
                "control": cid, "on": key, "fires": False, "honest_solve_failed": pre.fail[:1]}
            continue
        r = salted_leaf_control(pre, view, key, rule)
        del pre
        out[f"{cid} a salted leaf changed ({'tail' if cid == 'PRE-T3' else 'fork A'})"] = dict(r, control=cid, on=key)
    out["on_fork"] = kc
    out["on_tail"] = tk
    out["ok"] = all(v["fires"] for v in out.values() if isinstance(v, dict))
    return out


def main(argv=None):
    import zk60_native_rg_d55 as D
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name")
    ap.add_argument("--no-controls", action="store_true")
    a = ap.parse_args(argv)
    t0 = time.time()
    b = D.D55Bundle(a.bundle)
    rp = D.D55Replay(b).run()
    if not rp.summary()["ok"]:
        raise SystemExit("the D55 replay failed")
    _s3, views = D.d55_stage3(b, rp, do_controls=False, return_views=True)
    rec = d55_full_preimage(b, views, controls=not a.no_controls)
    rec["total_seconds"] = round(time.time() - t0, 1)
    try:
        import resource
        rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1 << 20))
    except Exception:  # noqa: BLE001
        pass
    os.makedirs(a.evidence, exist_ok=True)
    path = os.path.join(a.evidence, f"d55pre-{a.name or os.path.basename(os.path.normpath(a.bundle))}.json")
    with open(path, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True, default=str)
    print(json.dumps({"exhibited": len(rec["exhibited"]), "not_exhibited": rec["not_exhibited"],
                      "entries": rec["view_entries_compared"], "differing": rec["view_entries_differing"],
                      "leaves": rec["salted_leaves_authenticated"], "d55_findings": rec["d55"]["findings"],
                      "controls": {c["control"]: c.get("fires") for c in rec.get("controls", {}).get("controls", [])},
                      "d55_controls": {k: v.get("fires") for k, v in rec.get("d55_controls", {}).items() if isinstance(v, dict)}},
                     indent=1, default=str))
    print(f"status: {'PASS' if rec['ok'] else 'NOT-OK'} ({rec['total_seconds']} s) -> {path}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
