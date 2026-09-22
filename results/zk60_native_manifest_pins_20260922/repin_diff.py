#!/usr/bin/env python3
"""Round 9f, T4: what the re-pin moved in the three guarded records.

    python3 results/zk60_native_manifest_pins_20260922/repin_diff.py

Each record is compared, leaf by leaf, with its own committed bytes at
`025e1ac` (the commit round 9e closed on), read straight out of git.  The only
differences allowed are

  * `tool_sha256/zk60_native_privacy_gate.py` and
    `tool_sha256/zk60_native_joint_view.py` -- the two gates, each of which
    now calls the manifest-pin check before it reads anything;
  * `tool_sha256/zk60_native_manifest_pins.py` -- a NEW leaf: the check's own
    file, which both gates list in their `TOOLS` table so that the record
    names every tool whose bytes can turn a run into a refusal;
  * any `seconds` leaf -- the record's own wall clock and the three per-stage
    ones inside the joint-view record, on a shared box.

Anything else is a figure of record moving and is printed as UNEXPECTED --
including a tool hash for a file this round did NOT touch (`mask_commit.py`
and `terminal_polys.py` above all: they are named by 122 and 8 committed
records respectively and this round deliberately leaves their bytes alone).
Exit 0 only if there is none.
"""
import json
import os
import subprocess
import sys

ROOT = "/home/victor/wt-zk60-jointview"
BASE = "025e1ac"
RECORDS = [
    "results/zk60_native_privacy_gate/privacy_gate.json",
    "results/zk60_native_privacy_gate_channels/privacy_gate.json",
    "results/zk60_native_joint_view/joint_view.json",
]
CHANGED_BY_THIS_ROUND = (
    "zk60_native_privacy_gate.py",    # caller: the check, before any analysis
    "zk60_native_joint_view.py",      # caller: the same
    "zk60_native_manifest_pins.py",   # NEW: the pins and the content assertion
)
ALLOWED_TOOLS = tuple("/tool_sha256/" + t for t in CHANGED_BY_THIS_ROUND)


def allowed(path):
    return path.split("/")[-1] == "seconds" or path in ALLOWED_TOOLS


def walk(a, b, path, out):
    if type(a) is not type(b):
        out.append((path, repr(a)[:120], repr(b)[:120]))
        return
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                out.append((path + "/" + str(k), "<absent>", repr(b[k])[:120]))
            elif k not in b:
                out.append((path + "/" + str(k), repr(a[k])[:120], "<absent>"))
            else:
                walk(a[k], b[k], path + "/" + str(k), out)
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append((path + "/len", len(a), len(b)))
            return
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, path + "/" + str(i), out)
    elif a != b:
        out.append((path, repr(a)[:120], repr(b)[:120]))


def main():
    bad = 0
    for rel in RECORDS:
        old = json.loads(subprocess.run(
            ["git", "--no-pager", "-C", ROOT, "show", f"{BASE}:{rel}"],
            check=True, capture_output=True, text=True).stdout)
        new = json.load(open(os.path.join(ROOT, rel)))
        rows = []
        walk(old, new, "", rows)
        print("=" * 72)
        print(rel)
        ok_rows, unexpected = [], []
        for p, x, y in rows:
            (ok_rows if allowed(p) else unexpected).append((p, x, y))
        for p, x, y in ok_rows:
            print(f"  allowed    {p}\n               {BASE} {x}\n               now      {y}")
        for p, x, y in unexpected:
            print(f"  UNEXPECTED {p}\n               {BASE} {x}\n               now      {y}")
        print(f"  {len(ok_rows)} allowed, {len(unexpected)} unexpected, "
              f"{len(rows)} differing leaves in all")
        bad += len(unexpected)
    print("=" * 72)
    print("VERDICT:", "only the two callers' hashes, the new tool's hash and "
          "the clocks moved" if not bad else f"{bad} unexpected difference(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
