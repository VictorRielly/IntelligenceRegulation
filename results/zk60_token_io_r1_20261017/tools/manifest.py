#!/usr/bin/env python3
"""Source manifest of the lane's working copy (ops/zkp-mvp/token-io).

usage: manifest.py OUT.sha256 [COMPARE.sha256 ...]

Walks the working copy (skipping build `target/` directories and the
BASELINE.sha256 file itself), writes `sha256  relpath` lines sorted by path,
prints the list's own sha256, and for each COMPARE manifest prints the
changed / added / removed paths.
"""
import hashlib
import os
import sys

ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io"


def walk():
    out = {}
    for d, dirs, files in os.walk(ROOT):
        dirs[:] = sorted(x for x in dirs if x != "target")
        for f in files:
            p = os.path.join(d, f)
            rel = os.path.relpath(p, ROOT)
            if rel == "BASELINE.sha256":
                continue
            with open(p, "rb") as fh:
                out[rel] = hashlib.sha256(fh.read()).hexdigest()
    return out


def load(path):
    m = {}
    with open(path) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            h, rel = line.split("  ", 1)
            m[rel] = h
    return m


def main():
    out_path = sys.argv[1]
    cur = walk()
    text = "".join(f"{cur[k]}  {k}\n" for k in sorted(cur))
    with open(out_path, "w") as fh:
        fh.write(text)
    print(f"{len(cur)} files; list sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    for cmp_path in sys.argv[2:]:
        old = load(cmp_path)
        changed = sorted(k for k in cur if k in old and old[k] != cur[k])
        added = sorted(k for k in cur if k not in old)
        removed = sorted(k for k in old if k not in cur)
        print(f"vs {os.path.basename(cmp_path)}: changed {len(changed)}, added {len(added)}, removed {len(removed)}")
        for k in changed:
            print(f"  changed {k}")
        for k in added:
            print(f"  added   {k}")
        for k in removed:
            print(f"  removed {k}")


if __name__ == "__main__":
    main()
