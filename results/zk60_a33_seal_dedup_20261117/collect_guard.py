#!/usr/bin/env python3
"""A33: one table of every guarded run (label, class, guard run id, exit, wall, peak RSS, waited, ds4-bench before/after)."""
import json
from pathlib import Path

RAW = Path(__file__).resolve().parent / "raw"
rows = ["| label | class | guard run id | exit | child wall s | waited s | peak RSS GiB | ds4-bench before / after |", "|---|---|---|---|---|---|---|---|"]
for g in sorted(RAW.glob("*.guard.json"), key=lambda p: json.loads(p.read_text())["ts_end"]):
    j = json.loads(g.read_text())
    sp = RAW / (g.name.replace(".guard.json", ".status_pre.txt"))
    ds = "?"
    if sp.exists():
        t = sp.read_text()
        before = t.split("--- pgrep -fl ds4-bench ---")[1].split("---")[0].strip() if "--- pgrep -fl ds4-bench ---" in t else "?"
        after = t.split("after the run ---")[1].strip() if "after the run ---" in t else "?"
        ds = f"{'none' if before == '(none)' else 'RUNNING'} / {'none' if after == '(none)' else 'RUNNING'}"
    rows.append(f"| {j['label']} | {j['class']} | {j['run_id']} | {j['exit']} | {j['child_wall_seconds']:.1f} | {j['waited_s']:.0f} | {j['peak_rss_gib']} | {ds} |")
text = "\n".join(rows)
print(text)
(Path(__file__).resolve().parent / "GUARD_RUNS.md").write_text(text + "\n")
