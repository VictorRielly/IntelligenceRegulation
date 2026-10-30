#!/usr/bin/env python3
"""[gate round 21] May the gate's derivation run now?  Brief: Astra's first real app post (three category proves
through `apps/proven-media/tools/classifier_pipeline.py`, guard labels `pm-classify-*`) goes FIRST.

Exits 0 (and prints a JSON line) when the box is alone (round 20's `alone_check.py`: no live or waiting guarded
job, no FIFO ticket, no hold file) AND either
  (a) three `pm-classify-label` runs (the last step of each category's worker) ended after T0, or
  (b) no `pm-classify-*` run ended after T0, none is live, and the clock is past the IDLE deadline (Astra did not
      start: the derivation is a ~2 min light-memory job and then gets out of the way), or
  (c) the clock is past the HARD deadline.
Exits 1 otherwise.  Reads only the guard's status and history.
"""
import datetime as dt
import json
import subprocess
import sys

HIST = "/home/victor/IntelligenceRegulation/results/zk60_resource_guard/history.jsonl"
ALONE = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round20/alone_check.py"
T0 = "2026-10-29T21:33:40Z"
IDLE_DEADLINE = "2026-10-29T22:45:00Z"
HARD_DEADLINE = "2026-10-30T04:00:00Z"


def main():
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    pm = []
    with open(HIST) as fh:
        for line in fh:
            try:
                j = json.loads(line)
            except ValueError:
                continue
            if str(j.get("label", "")).startswith("pm-classify-") and str(j.get("ts_end", "")) > T0:
                pm.append({"label": j["label"], "ts_end": j["ts_end"], "exit": j.get("exit")})
    a = subprocess.run(["python3", ALONE, "gate21-"], capture_output=True, text=True)
    try:
        alone = json.loads(a.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        alone = {"alone": False, "error": a.stdout[-500:] + a.stderr[-500:]}
    labels = sum(1 for x in pm if x["label"] == "pm-classify-label")
    live_pm = [x for x in alone.get("live_guarded_jobs", []) + alone.get("guard_processes", [])
               if str(x.get("label", "")).startswith("pm-classify-")]
    reason = None
    if alone.get("alone"):
        if labels >= 3:
            reason = "astra's three category workers finished (3 pm-classify-label)"
        elif not pm and not live_pm and now > IDLE_DEADLINE:
            reason = "astra started nothing since T0 and the idle deadline passed"
        elif now > HARD_DEADLINE:
            reason = "hard deadline"
    rec = {"now": now, "pm_classify_since_T0": pm, "labels_done": labels, "live_pm": live_pm,
           "alone": alone.get("alone"), "go": reason is not None, "reason": reason}
    print(json.dumps(rec))
    return 0 if reason else 1


if __name__ == "__main__":
    sys.exit(main())
