#!/usr/bin/env python3
"""Round 9e, S4: what the re-pin moved in the three guarded records.

    python3 results/zk60_native_manifest_check_20260922/repin_diff.py

Each record is compared, leaf by leaf, with its own committed bytes at
`d837d50` (the commit round 9d closed on), read straight out of git.  The
only differences allowed are

  * `tool_sha256/<one of the three files the fix touches>` -- the reader
    itself and the two gates that call it, each of which lists the other in
    its own `TOOLS` table; a changed tool byte is the whole reason the
    records have to be re-taken;
  * any `seconds` leaf -- the record's own wall clock and the three per-stage
    ones inside the joint-view record, on a shared box.

Anything else is a figure of record moving and is printed as UNEXPECTED --
including a tool hash for a file this fix did NOT touch.  Exit 0 only if
there is none.
"""
import json
import os
import subprocess
import sys

ROOT = "/home/victor/wt-zk60-jointview"
BASE = "d837d50"
RECORDS = [
    "results/zk60_native_privacy_gate/privacy_gate.json",
    "results/zk60_native_privacy_gate_channels/privacy_gate.json",
    "results/zk60_native_joint_view/joint_view.json",
]
CHANGED_BY_THE_FIX = (
    "zk60_native_jv_capture.py",      # the reader: the fix itself
    "zk60_native_privacy_gate.py",    # caller: the flag and the refusal path
    "zk60_native_joint_view.py",      # caller: the same
)
ALLOWED_TOOLS = tuple("/tool_sha256/" + t for t in CHANGED_BY_THE_FIX)


def allowed(path):
    # any wall clock, at the top of a record or inside one of the joint-view
    # gate's stages, and the tool hashes this fix moved -- nothing else
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
    print("VERDICT:", "only the changed tool's hash and the clock moved"
          if not bad else f"{bad} unexpected difference(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
