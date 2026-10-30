#!/usr/bin/env python3
"""[gate round 22] Exit 0 when Astra's first real post (resumed 00:15 UTC, coordinator 00:23) is done: three
`pm-classify-label` runs ended after T0, or (fallback: it stopped) at least one pm-classify-* run ended after T0, none
is live or waiting now, and the last ended more than 15 minutes ago. Reads the guard history and process table only."""
import datetime as dt, json, os, sys
T0 = "2026-10-30T00:15:00Z"
HIST = "/home/victor/IntelligenceRegulation/results/zk60_resource_guard/history.jsonl"
pm = []
for line in open(HIST):
    try:
        j = json.loads(line)
    except ValueError:
        continue
    if str(j.get("label", "")).startswith("pm-classify-") and str(j.get("ts_end", "")) > T0:
        pm.append(j)
live = False
for p in os.listdir("/proc"):
    if not p.isdigit():
        continue
    try:
        a = open(f"/proc/{p}/cmdline", "rb").read().split(b"\0")
    except OSError:
        continue
    a = [x.decode(errors="replace") for x in a if x]
    if len(a) >= 3 and a[1].endswith("zk60_resource_guard.py") and a[2] == "run" and "--label" in a \
            and a[a.index("--label") + 1].startswith("pm-classify-"):
        live = True
now = dt.datetime.now(dt.timezone.utc)
labels = sum(1 for j in pm if j["label"] == "pm-classify-label")
last = max((j["ts_end"] for j in pm), default=None)
idle = last is not None and (now - dt.datetime.strptime(last, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)).total_seconds() > 900
go = labels >= 3 or (pm and not live and idle)
print(json.dumps({"now": now.strftime("%H:%M:%SZ"), "pm_since_T0": [(j["label"], j["ts_end"], j.get("exit")) for j in pm],
                  "labels": labels, "pm_live_or_waiting": live, "go": bool(go)}))
sys.exit(0 if go else 1)
