#!/usr/bin/env python3
"""A33: make raw/ publishable. (1) the four cargo --message-format=json build logs are replaced by a short summary (the
executable path, error and warning counts, the guard's own lines are in the .guard.json); (2) the agent scratch directory's
path (it carries a tool session id) is replaced by <scratch> in every text file."""
import json
import re
from pathlib import Path

RAW = Path(__file__).resolve().parent / "raw"
SCRATCH = re.compile(r"/private/tmp/claude-501/[^\s\"']*?/scratchpad")
for f in sorted(RAW.glob("g1_build_*.log")):
    ex, warn, err = [], 0, 0
    for ln in f.read_text().splitlines():
        if not ln.startswith("{"):
            continue
        try:
            o = json.loads(ln)
        except json.JSONDecodeError:
            continue
        if o.get("reason") == "compiler-artifact" and o.get("target", {}).get("name") == "hashline" and o.get("profile", {}).get("test") and o.get("executable"):
            ex.append(o["executable"])
        if o.get("reason") == "compiler-message":
            lvl = o.get("message", {}).get("level")
            warn += lvl == "warning"
            err += lvl == "error"
    f.write_text(f"cargo --message-format=json output summarised by scrub.py: test executable(s) {ex}; compiler warnings {warn}, errors {err}\n")
for f in sorted(RAW.iterdir()):
    if f.suffix in (".log", ".json", ".txt", ".done"):
        t = f.read_text()
        n = SCRATCH.sub("<scratch>", t)
        if n != t:
            f.write_text(n)
