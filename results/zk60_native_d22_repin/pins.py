#!/usr/bin/env python3
"""The pin inventory of the D22 re-read at `4751b93`, regenerable.

  python3 results/zk60_native_d22_repin/pins.py table   > pin_table.txt
  python3 results/zk60_native_d22_repin/pins.py drift   > capture_drift.txt

`table` prints, for every source pin of every TOY gate tool of this
worktree, the file's SHA-256 and git blob id (a) as the tool pins it,
(b) at the commit the tool names, (c) at `4751b93^`, (d) at `4751b93`,
(e) on this worktree's disk and (f) on the main repository's disk, and
says whether `4751b93` moves it.

`drift` does the same job for the wider net the CAPTURE manifest casts:
the 92 files `results/zk60_native_captures_20260919/source.json` records,
which of them had already moved by `4751b93^` and which `4751b93` moves.

Read-only: it runs `git show` against the main repository and hashes
bytes. Nothing is written anywhere.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys

MAIN = "/home/victor/IntelligenceRegulation"
WT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CAP = os.path.join(WT, "results", "zk60_native_captures_20260919", "source.json")
sys.path.insert(0, os.path.join(WT, "scripts"))


def blob_id(raw: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(raw) + raw).hexdigest()


def at(commit: str, path: str):
    p = subprocess.run(["git", "--no-pager", "-C", MAIN, "show", f"{commit}:{path}"],
                       capture_output=True)
    if p.returncode != 0:
        return None, None
    return hashlib.sha256(p.stdout).hexdigest(), blob_id(p.stdout)


def on_disk(root: str, path: str):
    f = os.path.join(root, path)
    if not os.path.exists(f):
        return None, None
    with open(f, "rb") as fh:
        raw = fh.read()
    return hashlib.sha256(raw).hexdigest(), blob_id(raw)


def table() -> None:
    import zk60_native_mask_commit as mc
    import zk60_native_terminal_polys as tp

    tables = [
        ("scripts/zk60_native_terminal_polys.py SOURCE_PINS", "5ca721f",
         [(p.path, p.sha256, p.blob) for p in tp.SOURCE_PINS]),
        ("scripts/zk60_native_mask_commit.py SOURCE_PINS", "1857c04",
         [(p.path, p.sha256, p.blob) for p in mc.SOURCE_PINS]),
    ]
    for name, pincommit, pins in tables:
        print("=" * 96)
        print(f"{name}   (the commit the tool names: {pincommit})")
        for path, sha, blob in pins:
            s_pin, b_pin = at(pincommit, path)
            s_prev, b_prev = at("4751b93^", path)
            s_new, b_new = at("4751b93", path)
            s_wt, _ = on_disk(WT, path)
            s_main, _ = on_disk(MAIN, path)
            mark = lambda g: "MATCH" if g == sha else "DIFFERS"  # noqa: E731
            print(f"\n  {path}")
            print(f"    pinned in tool : {sha} / {blob}")
            print(f"    @{pincommit:<12s}  : {s_pin} / {b_pin}  {mark(s_pin)}")
            print(f"    @4751b93^      : {s_prev} / {b_prev}  {mark(s_prev)}")
            print(f"    @4751b93       : {s_new} / {b_new}  {mark(s_new)}")
            print(f"    worktree disk  : {s_wt}  {mark(s_wt)}")
            print(f"    main disk      : {s_main}  {mark(s_main)}")
            print(f"    MOVES at 4751b93: {'YES' if s_prev != s_new else 'no'}")


def drift() -> None:
    with open(CAP) as fh:
        d = json.load(fh)
    print("capture source_commit:", d["source_commit"])
    moved_prev, moved_new, gone = [], [], []
    for path, want in sorted(d["files"].items()):
        a, _ = at("4751b93^", path)
        b, _ = at("4751b93", path)
        if a is None:
            gone.append(path)
            continue
        if a != want:
            moved_prev.append(path)
        if b != a:
            moved_new.append(path)
    print("\n== of the %d files the capture manifest records, those that had ALREADY"
          " moved by 4751b93^ (%d) ==" % (len(d["files"]), len(moved_prev)))
    for p in moved_prev:
        print("  ", p)
    print("\n== those 4751b93 itself moves (%d) ==" % len(moved_new))
    for p in moved_new:
        print("  ", p)
    print("\n== missing at 4751b93^ ==", gone)


if __name__ == "__main__":
    {"table": table, "drift": drift}[sys.argv[1] if len(sys.argv) > 1 else "table"]()
