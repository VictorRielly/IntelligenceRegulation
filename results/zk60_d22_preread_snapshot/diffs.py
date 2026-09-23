"""Write the unified diff of every MOVED pinned file: main 4751b93 -> snapshot,
and, for the files that are neither side's bytes, also lane fee1a8d -> snapshot.

    python3 results/zk60_d22_preread_snapshot/diffs.py [--snapshot DIR]

Output: results/zk60_d22_preread_snapshot/diff/<path with / -> __>.<base>.diff
plus a stat line per file on stdout (kept as diffstat.txt).
"""
from __future__ import annotations

import argparse
import difflib
import os
import subprocess

REPO = "/home/victor/IntelligenceRegulation"
OUT = os.path.join(REPO, "results/zk60_d22_preread_snapshot/diff")
MOVED = [
    "hashline/Cargo.toml",
    "hashline/src/pcs.rs",
    "hashline/src/zk.rs",
    "hashline/src/private_block.rs",
    "hashline/src/private_block/argument.rs",
    "hashline/src/private_block/layout.rs",
    "hashline/src/private_block/protocol.rs",
    "hashline/src/private_block/wire.rs",
    "hashline/src/private_block/witness.rs",
    "zkp-core/src/lib.rs",
    "zkp-core/src/merkle.rs",
    "zkp-core/src/pcs.rs",
    "zkp-core/src/transcript.rs",
]
# the two files whose snapshot bytes are neither side's
NEITHER = {"hashline/src/pcs.rs", "hashline/src/zk.rs"}
# unpinned files that the tag patches / the toy path also touch
EXTRA = ["zkp-core/src/hashtag.rs", "zkp-core/Cargo.toml"]


def show(rev, path):
    r = subprocess.run(["git", "--no-pager", "show", f"{rev}:{path}"],
                       cwd=REPO, capture_output=True)
    return r.stdout.decode() if r.returncode == 0 else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="/tmp/claude-1000/d22-snapshot")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    for path in MOVED + EXTRA:
        snap = open(os.path.join(a.snapshot, path)).read()
        bases = [("4751b93", "main")]
        if path in NEITHER:
            bases.append(("fee1a8d", "lane"))
        for rev, tag in bases:
            old = show(rev, path)
            d = list(difflib.unified_diff(
                old.splitlines(keepends=True), snap.splitlines(keepends=True),
                fromfile=f"{rev}:{path}", tofile=f"snapshot:{path}", n=3))
            plus = sum(1 for l in d if l.startswith("+") and not l.startswith("+++"))
            minus = sum(1 for l in d if l.startswith("-") and not l.startswith("---"))
            hunks = sum(1 for l in d if l.startswith("@@"))
            name = path.replace("/", "__") + f".{tag}-{rev}.diff"
            with open(os.path.join(OUT, name), "w") as fh:
                fh.writelines(d)
            print(f"{path:<42} vs {tag} {rev}: {len(old.splitlines()):>5} -> "
                  f"{len(snap.splitlines()):>5} lines, +{plus} -{minus}, "
                  f"{hunks} hunks  [{name}]")


if __name__ == "__main__":
    main()
