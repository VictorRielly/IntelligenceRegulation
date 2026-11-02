#!/usr/bin/env python3
"""Gate round 26 wiring (2026-11-02): the totals README.md section 4 quotes, over the four FRESH registered records
(records/d55-py-r13-{rung,8b}-s{0,1}.json): commitments ranked, disclosed dimensions against their expectation,
pad margins, every control's verdict."""
import collections
import json
import os

E = os.path.join(os.path.dirname(os.path.abspath(__file__)), "records")
names = [f"d55-py-r13-{k}-s{s}.json" for k in ("rung", "8b") for s in (0, 1)]
ranked = disc_ok = minors = hyps = m_zero = 0
disclosed = collections.Counter()
margins = collections.Counter()
controls = collections.Counter()
for n in names:
    r = json.load(open(os.path.join(E, n)))
    s3 = r["R13-6 per commitment"]
    for row in s3["per_commitment"]:
        ranked += 1
        disclosed[row["disclosed_dimension"]] += 1
        disc_ok += row["disclosed_dimension"] == row["expected_disclosed_dimension"]
        minors += bool(row["certifying_minor"].get("full_row_rank") and row["certifying_minor"].get("determinant_nonzero"))
        hyps += all(row["reduction_hypotheses"].values())
        margins[row["pad_margin"]] += 1
    m_zero += sum(1 for m in s3["masking_commitments"] if m["disclosed_dimension"] == 0)

    def fired(where, d):
        for k, v in d.items():
            if isinstance(v, dict) and "fires" in v:
                controls[(where, bool(v["fires"]))] += 1
    fired("R13-H", r["R13-H registered header"]["controls"])
    fired("R13-3", r["R13-3 terminals"]["controls"])
    fired("D55-J", r["D55-J joint rank"]["controls"])
    fired("D55-C", r["D55-C replay controls"])
    fired("PINS", r["PINS controls"]["controls"])
    controls[("D55-IO", bool(r["D55-IO joined claims from the forks"]["control"]["fires"]))] += 1
    controls[("mask", bool(r["R13-7 mask and CFS"]["controls"]["ok"]))] += 1
    controls[("exclusivity", bool(s3["exclusivity_controls"]["ok"]))] += 1
    print(n, r["status"], r["seconds"], "s", r.get("peak_rss_mb"), "MB")
print("regular commitments ranked", ranked, "| disclosed", dict(disclosed), "| = expectation", disc_ok, "| certifying minor full rank, det != 0", minors,
      "| reduction hypotheses true", hyps, "| M at 0", m_zero, "| pad margins", dict(sorted(margins.items())))
print("controls (part, fired): count", dict(sorted(controls.items())))
