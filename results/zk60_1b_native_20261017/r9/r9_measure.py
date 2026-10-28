#!/usr/bin/env python3
"""NATIVE R9: DD on vs off from the HL_PB_TIMING tables of two stack runs of
the SAME export (R8 CLI, DD off; R9 CLI with --dd, DD on). Per block (the
counts are a function of the profile; the seconds are summed over blocks):
committed words (the A and H commits' counted words), byte lookups (the
looked words of the byte histogram), zero-check ELEMENT-TERMS in the
runtime's own convention (per slot 2^(main + ext rounds) x its table count,
summed over slots — NOT the review's committed-reads convention), and the
prove time split. usage: r9_measure.py <off run dir> <on run dir> <label>"""
import json
import re
import sys


def table(path):
    blocks, cur = [], None
    for line in open(path, errors="replace"):
        if not line.startswith("PB-TIMING prove |"):
            if line.startswith("PB-TIMING prove ["):
                cur = {"phases": []}
                blocks.append(cur)
            continue
        parts = [p.strip() for p in line.split("|")]
        if parts[1] == "phase" or cur is None:
            continue
        m = re.match(r"(\d+) (\S+)", parts[5])
        cur["phases"].append((parts[1], parts[2], float(parts[3]), int(m.group(1)) if m else 0, m.group(2) if m else ""))
    return blocks


def summary(path):
    bl = table(path)
    first = bl[0]["phases"]
    get = lambda pfx: sum(n for (p, _, _, n, _) in first if p.startswith(pfx))
    ev = {}
    for line in open(path, errors="replace"):
        if '"event":"proved"' in line:
            ev = json.loads(line[line.index("{"):])
    return dict(
        blocks=len(bl),
        committed_words=get("A: commit") + get("H: commit"),
        a_words=get("A: commit"),
        h_words=get("H: commit"),
        byte_lookups=get("A: lookup values + the byte histogram"),
        element_terms=sum(n for (p, _, _, n, u) in first if u == "elem-terms"),
        slot23_terms=sum(n for (p, _, _, n, u) in first if p.startswith("slot 23")),
        seconds_by_half={h: round(sum(s for b in bl for (_, hh, s, _, _) in b["phases"] if hh == h), 2) for h in sorted({hh for b in bl for (_, hh, _, _, _) in b["phases"]}) if h},
        prove_run_seconds=ev.get("prove_run_seconds"),
        total_seconds=ev.get("total_seconds"),
        receipt_bytes=ev.get("receipt_bytes"),
        identity=ev.get("statement_identity"),
    )


off, on, label = sys.argv[1], sys.argv[2], sys.argv[3]
a, b = summary(off + "/prove.log"), summary(on + "/prove.log")
pct = lambda x, y: round(100.0 * (y / x - 1), 2) if x else None
res = dict(label=label, off=a, on=b, d_committed_pct=pct(a["committed_words"], b["committed_words"]), d_byte_lookups_pct=pct(a["byte_lookups"], b["byte_lookups"]),
           d_element_terms_pct=pct(a["element_terms"], b["element_terms"]), d_prove_run_pct=pct(a["prove_run_seconds"] or 0, b["prove_run_seconds"] or 0))
json.dump(res, open(on + "/dd_vs_off.json", "w"), indent=1)
print(json.dumps(res, indent=1))
