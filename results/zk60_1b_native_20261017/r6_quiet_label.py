"""Label a guarded run "quiet box" or "shared box": every other guarded job
in the guard history whose [start, end] overlaps this run's prove job.
usage: python3 -B r6_quiet_label.py <run dir>   -> prints and writes <run dir>/box_label.json"""
import datetime
import json
import os
import sys

H = "/home/victor/IntelligenceRegulation/results/zk60_resource_guard/history.jsonl"


def span(d):
    end = datetime.datetime.strptime(d["ts_end"], "%Y-%m-%dT%H:%M:%SZ")
    return end - datetime.timedelta(seconds=d.get("child_wall_seconds") or 0), end


def main():
    r = sys.argv[1]
    g = json.load(open(os.path.join(r, "prove.guard.json")))
    s0, e0 = span(g)
    others = []
    for line in open(H):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if not d.get("ts_end") or not d.get("child_wall_seconds") or d.get("run_id") == g.get("run_id"):
            continue
        s, e = span(d)
        ov = (min(e, e0) - max(s, s0)).total_seconds()
        if ov > 0:
            others.append(dict(label=d["label"], cls=d["class"], start=s.isoformat() + "Z", end=e.isoformat() + "Z", overlap_s=round(ov, 2)))
    # the history's ts_end is truncated to whole seconds, so a span rebuilt as
    # end - wall can reach up to TOL s past the true boundary: a job that
    # ended in the same second this one started is a boundary tie, not an
    # overlap (heavy-class jobs share one lock and cannot truly overlap)
    TOL = 1.5
    real = [o for o in others if o["overlap_s"] > TOL]
    label = "quiet box" if not real else "shared box"
    out = dict(run=r, prove_start=s0.isoformat() + "Z", prove_end=e0.isoformat() + "Z", label=label, overlapping=real,
               boundary_ties=[o for o in others if o["overlap_s"] <= TOL], tolerance_s=TOL,
               note="guarded jobs only (unguarded processes are not in the history); jobs still running at the time of this scan are not in the history yet; re-run the scan later to be sure")
    json.dump(out, open(os.path.join(r, "box_label.json"), "w"), indent=1)
    print(label, real, "boundary ties:", [o["label"] for o in others if o["overlap_s"] <= TOL])


main()
