#!/usr/bin/env python3
"""Token round 14: the round's changes against frozen-r13 (light; text only).

usage: r14_diffstat.py CANDIDATE.sha256 OUT_STEM
Writes OUT_STEM.txt (changed / added / removed files with +/- line counts) and OUT_STEM.diff (unified diffs of
every changed or added file, frozen-r13 -> the r14 tree).
"""
import difflib, os, sys

R = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
OLD = f"{R}/frozen-r13"
NEW = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r14"


def load(path):
    m = {}
    for line in open(path):
        line = line.rstrip("\n")
        if line:
            d, rel = line.split("  ", 1)
            m[rel] = d
    return m


def main():
    old, new = load(f"{R}/manifest_final_r13.sha256"), load(sys.argv[1])
    stem = sys.argv[2]
    changed = sorted(k for k in old if k in new and old[k] != new[k])
    added = sorted(k for k in new if k not in old)
    removed = sorted(k for k in old if k not in new)
    lines, diffs = [], []
    for rel in changed + added:
        a = open(os.path.join(OLD, rel)).read().splitlines(keepends=True) if rel in old else []
        b = open(os.path.join(NEW, rel)).read().splitlines(keepends=True)
        d = list(difflib.unified_diff(a, b, f"frozen-r13/{rel}", f"token-io-r14/{rel}"))
        plus = sum(1 for x in d if x.startswith("+") and not x.startswith("+++"))
        minus = sum(1 for x in d if x.startswith("-") and not x.startswith("---"))
        lines.append(f"{'changed' if rel in old else 'added  '}  +{plus:<5} -{minus:<5} {rel}")
        diffs.extend(d)
    for rel in removed:
        lines.append(f"removed  {rel}")
    head = f"vs frozen-r13 (manifest_final_r13): {len(changed)} changed, {len(added)} added, {len(removed)} removed"
    open(f"{stem}.txt", "w").write(head + "\n" + "\n".join(lines) + "\n")
    open(f"{stem}.diff", "w").write("".join(diffs))
    print(head)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
