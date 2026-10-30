#!/usr/bin/env python3
"""[GATE ROUND 14, tools v17, 2026-10-20] Controls on the DD planes and
slots of a native R9 DD capture (D30), each PREDICTED and each shown
honest-then-perturbed, in memory only (no captured byte is touched):

  DT-1  slot 23's terminal at `A_PDICT` changed by +1 in the last stage:
        the identity fails at EXACTLY (that stage, 23), and the transcript
        replay refuses the same bundle (`pb-term` absorbs the terminals);
  DT-2  slot 17's terminal at `H_STUPLE` (the score entry's tuple helper)
        changed by +1: fails at exactly (that stage, 17);
  DT-3  slot 23's terminal at `H_GDD` (the dictionary's table helper)
        changed by +1: fails at exactly (that stage, 23);
  DT-4  the e column's LAST nonzero entry (slot n_col - 1) changed by +1 in
        EVERY period (so the column stays periodic, starts at 0 and stays a
        strictly increasing run then zero padding),
        digest check OFF: the structure check passes, the ARITHMETIC fails at
        exactly (that stage, 23) and the attribution to the stage's exp table
        refuses; with the digest check on, the digest refuses it;
  DT-5  the e column made non-increasing (its first two entries swapped,
        digest off): the STRUCTURE check refuses it;
  DT-6  the dictionary tag taken as 140 instead of TAG_DD = 141: slots 17
        and 23 fail in EVERY stage and nothing else -- the tag enters both
        DD relations and no other;
  DT-7  slot 23's plane list with `H_GDD` dropped: the push-order check
        refuses at slot 23 in every stage.

    python3 zk60_native_rg_ddcontrols.py --bundle <DD capture> --evidence <dir> --name <name>

NOTHING HERE IS A PRIVACY RESULT.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import resource
import sys
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_terminals as T  # noqa: E402
from zk60_native_rg_block import load_bundle  # noqa: E402
from zk60_native_rg_planes import plane_index_of  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402


def _sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def _failed(r):
    return sorted({(row["stage"], s) for row in r["per_stage"] for s in row["checked"]
                   if s not in row["equal"]}
                  | {(row["stage"], e["slot"]) for row in r["per_stage"] for e in row["not_checked"]
                     if e["why"] != "OPEN"})


def _plus_one(x):
    return [(int(x[0]) + 1) % T.P, int(x[1])]


def _docs_with(bundle, stage, mutate):
    docs = [st.doc for st in bundle.stages]
    d = copy.deepcopy(docs[stage])
    mutate(d)
    docs = list(docs)
    docs[stage] = d
    return docs


def _term_index(index, slot, name):
    return [p.name for p in index.slot_planes[slot]].index(name)


def _public_index(doc, slot, k):
    """the table index of slot's k-th public table"""
    pubs = [i for i, t in enumerate(doc["arguments"][slot]["tables"]) if t["kind"] == "public"]
    return pubs[k]


def run(bundle_dir):
    t0 = time.time()
    b = load_bundle(bundle_dir)
    index, reason = plane_index_of(b)
    if index is None:
        raise SystemExit(f"no plane index: {reason}")
    if int(b.run["shape"].get("dd_cap", 0)) <= 0:
        raise SystemExit("not a DD bundle")
    rp = RunReplay(b).run()
    honest = T.check_terminals(b, index, replay=rp)
    rec = {"what": "controls on the DD planes and slots, each predicted; NOT a privacy result",
           "privacy_acceptance": False, "bundle": b.name, "bundle_dir": bundle_dir,
           "honest": {"ok": honest["ok"], "slot_checks_equal": honest["slot_checks_equal"],
                      "of": honest["slot_checks_expected"], "covered_slots": honest["covered_slots"]},
           "controls": []}
    if not honest["ok"] or T.SC_DD not in honest["covered_slots"]:
        rec["ok"] = False
        rec["skipped"] = "the honest case does not pass with slot 23 covered; a control would prove nothing"
        return rec
    last = b.blocks - 1
    stages = list(range(b.blocks))

    def term_control(cid, slot, name, what):
        ti = _term_index(index, slot, name)

        def mut(d):
            d["arguments"][slot]["terminals"][ti] = _plus_one(d["arguments"][slot]["terminals"][ti])
        docs = _docs_with(b, last, mut)
        got = T.check_terminals(b, index, replay=rp, stage_docs=docs)
        failed = _failed(got)
        keep = b.stages[last].doc
        b.stages[last].doc = docs[last]
        try:
            try:
                rr = RunReplay(b).run()
                rfail = list(rr.failures)
            except Exception as exc:  # a refusal that raises
                rfail = [str(exc)]
        finally:
            b.stages[last].doc = keep
        rec["controls"].append({
            "control": cid, "what": what, "stage": last, "slot": slot, "terminal": ti,
            "predicted": [[last, slot]], "slots_that_failed": [list(x) for x in failed],
            "replay_refuses": bool(rfail), "first_replay_refusal": (rfail[0] if rfail else "")[:200],
            "restored": b.stages[last].doc is keep,
            "fires": failed == [(last, slot)] and bool(rfail)})

    term_control("DT-1", T.SC_DD, "A_PDICT", "slot 23's A_PDICT terminal +1 (the dictionary quotient)")
    term_control("DT-2", T.SC_SZC, "H_STUPLE", "slot 17's H_STUPLE terminal +1 (the score entry's tuple helper)")
    term_control("DT-3", T.SC_DD, "H_GDD", "slot 23's H_GDD terminal +1 (the dictionary's table helper)")

    # DT-4: one e-column entry +1, digest off (arithmetic) and on (digest)
    pi = _public_index(b.stages[last].doc, T.SC_DD, 0)

    cap = int(b.run["shape"]["dd_cap"])

    col0 = [int(v[0]) for v in list(b.stages[last].doc["arguments"][T.SC_DD]["tables"][pi]["values"])[:cap]]
    n_col = 1
    while n_col < cap and col0[n_col] > col0[n_col - 1]:
        n_col += 1
    k4 = n_col - 1

    def mut4(d):
        tab = d["arguments"][T.SC_DD]["tables"][pi]
        vals = [list(x) for x in tab["values"]]      # the capture's lazy array, copied
        for x in range(k4, len(vals), cap):
            vals[x] = _plus_one(vals[x])
        tab["values"] = vals
    docs4 = _docs_with(b, last, mut4)
    off = T.check_terminals(b, index, replay=rp, stage_docs=docs4, check_digests=False)
    on = T.check_terminals(b, index, replay=rp, stage_docs=docs4)
    off_failed = _failed(off)
    att = [a for a in off.get("dd_e_column_attribution", []) if a["stage"] == last]
    rec["controls"].append({
        "control": "DT-4", "what": f"the e column's last nonzero entry (slot {k4}) +1 in every period",
        "predicted_digest_off": [[last, T.SC_DD]], "digest_off_failed": [list(x) for x in off_failed],
        "digest_off_structure_failures": off["public_table_structure_failures"][:3],
        "attribution_at_the_stage": att,
        "digest_on_refusals": on["public_table_digest_failures"][:3],
        "fires": (off_failed == [(last, T.SC_DD)] and not off["public_table_structure_failures"]
                  and bool(att) and att[0].get("ok") is False
                  and bool(on["public_table_digest_failures"]))})

    # DT-5: the e column made non-increasing (first two entries of every period swapped)

    def mut5(d):
        tab = d["arguments"][T.SC_DD]["tables"][pi]
        vals = [list(x) for x in tab["values"]]
        for x in range(0, len(vals), cap):
            vals[x], vals[x + 1] = vals[x + 1], vals[x]
        tab["values"] = vals
    docs5 = _docs_with(b, last, mut5)
    r5 = T.check_terminals(b, index, replay=rp, stage_docs=docs5, check_digests=False)
    rec["controls"].append({
        "control": "DT-5", "what": "the e column's first two entries swapped in every period (digest off)",
        "structure_failures": r5["public_table_structure_failures"][:3],
        "fires": any("does not start at 0" in f or "strictly increasing" in f
                     for f in r5["public_table_structure_failures"])})

    # DT-6: the dictionary tag taken as 140
    keep_tag = T.TAG_DD
    T.TAG_DD = 140
    try:
        r6 = T.check_terminals(b, index, replay=rp)
    finally:
        T.TAG_DD = keep_tag
    f6 = _failed(r6)
    want6 = sorted((k, s) for k in stages for s in (T.SC_SZC, T.SC_DD))
    rec["controls"].append({
        "control": "DT-6", "what": "the dictionary tag taken as 140 instead of 141",
        "predicted": [list(x) for x in want6], "slots_that_failed": [list(x) for x in f6],
        "tag_restored": T.TAG_DD == keep_tag, "fires": f6 == want6})

    # DT-7: H_GDD dropped from slot 23's plane list
    planes = [[p.name for p in row] for row in index.slot_planes]
    planes[T.SC_DD] = [n for n in planes[T.SC_DD] if n != "H_GDD"]
    r7 = T.check_terminals(b, index, replay=rp, slot_planes=planes)
    f7 = _failed(r7)
    rec["controls"].append({
        "control": "DT-7", "what": "slot 23's plane list with H_GDD dropped",
        "predicted": [[k, T.SC_DD] for k in stages], "slots_that_failed": [list(x) for x in f7],
        "first_finding": next((f for f in r7["findings"] if "slot 23" in f), "")[:200],
        "fires": f7 == [(k, T.SC_DD) for k in stages]})

    rec["fired"] = sum(1 for c in rec["controls"] if c["fires"])
    rec["of"] = len(rec["controls"])
    rec["ok"] = rec["fired"] == rec["of"]
    rec["status"] = "PASS" if rec["ok"] else "NOT-OK"
    rec["seconds"] = round(time.time() - t0, 1)
    rec["peak_rss_mb"] = round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024)
    rec["tool_sha256"] = {os.path.basename(p): _sha(p) for p in (os.path.abspath(__file__), T.__file__)}
    return rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    a = ap.parse_args(argv)
    rec = run(a.bundle)
    os.makedirs(a.evidence, exist_ok=True)
    out = os.path.join(a.evidence, a.name + ".json")
    with open(out, "w") as fh:
        json.dump(rec, fh, indent=1, default=str)
    print(json.dumps({k: rec.get(k) for k in ("honest", "fired", "of", "status")}, indent=1))
    for c in rec["controls"]:
        print(c["control"], "fires" if c["fires"] else "DID NOT FIRE", c["what"])
    print(f"record: {out}  status {rec['status']}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
