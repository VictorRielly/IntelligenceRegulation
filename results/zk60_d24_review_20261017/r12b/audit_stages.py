"""Item 6 of the R12b fix check: did every acceptance stage in R12B_AUDIT.json run real tests?

For each stage: the guard record (exit, wall, peak RSS), the leaf command's test
filter, and the counts parsed from its own log ("test result: ok. N passed; ...",
"running N tests", or a non-test tool's output). A test stage whose log has
zero passed tests (or no result line) is flagged.
Usage: python3 audit_stages.py <r12b-dir> <out.json>
"""
import json
import os
import re
import sys

d, out = sys.argv[1], sys.argv[2]
audit = json.load(open(os.path.join(d, "R12B_AUDIT.json")))
rows = []
for name, rec in audit["stages"].items():
    cmd = rec.get("cmd", [])
    log = rec.get("log") or os.path.join(d, f"{name}.log")
    text = open(log, errors="replace").read() if os.path.exists(log) else None
    results = re.findall(r"test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out", text or "")
    running = [int(x) for x in re.findall(r"^running (\d+) tests?$", text or "", re.M)]
    passed = sum(int(r[1]) for r in results)
    failed = sum(int(r[2]) for r in results)
    ignored = sum(int(r[3]) for r in results)
    leaf = [c for c in cmd if not c.startswith("/usr/bin/env") and "=" not in c.split("/")[0]]
    is_test_binary = any("/deps/hashline-" in c for c in cmd) or ("test" in cmd and any(c.endswith("cargo") for c in cmd))
    filters = []
    if any("/deps/hashline-" in c for c in cmd):
        i = next(i for i, c in enumerate(cmd) if "/deps/hashline-" in c)
        filters = [c for c in cmd[i + 1:] if not c.startswith("--")]
    ok_lines = re.findall(r"^test (\S+) \.\.\. (ok|FAILED|ignored)", text or "", re.M)
    rows.append({
        "stage": name,
        "class": rec.get("class"),
        "exit": rec.get("exit"),
        "child_rc": rec.get("child_rc"),
        "wall_s": rec.get("child_wall_seconds"),
        "peak_rss_gib": rec.get("peak_rss_gib"),
        "test_binary": is_test_binary,
        "filters": filters,
        "log_bytes": None if text is None else len(text),
        "running": running,
        "results_lines": len(results),
        "passed": passed,
        "failed": failed,
        "ignored": ignored,
        "named_ok": sum(1 for _, s in ok_lines if s == "ok"),
        "flag_zero_tests": is_test_binary and passed == 0,
        "log_tail": None if text is None else text.strip()[-300:],
    })
json.dump({"stages": rows, "test_counts": audit.get("test_counts")}, open(out, "w"), indent=1)
for r in rows:
    print(f"{r['stage']:28s} exit={r['exit']} wall={r['wall_s'] and round(r['wall_s'],1)} rss={r['peak_rss_gib']} test={r['test_binary']} filters={r['filters'][:3]} passed={r['passed']} failed={r['failed']} ign={r['ignored']} named_ok={r['named_ok']} FLAG={r['flag_zero_tests']}")
print("audit test_counts:", json.dumps(audit.get("test_counts"))[:800])
