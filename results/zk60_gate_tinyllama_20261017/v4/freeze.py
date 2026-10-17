#!/usr/bin/env python3
"""Tools-freeze helper of the privacy-gate lane (round 3, tools v4).

    python3 freeze.py check  <manifest> <root>     # every listed file == its digest
    python3 freeze.py snapshot <dest>               # copy the CURRENT tool tree (v3) to <dest>
    python3 freeze.py manifest <out>                # write the manifest of the current tree
    python3 freeze.py patch <old-dir> <new-dir> <out> [<label-old> <label-new>]

The manifest lists, in this order and with paths relative to
`ops/zkp-mvp/gate-tinyllama/`: every `scripts/*.py` (sorted), every
`tests/*.py` (sorted), `counts/run_hash_counts.py` -- the layout of the v1-v3
manifests.  `patch` runs `diff -ruN -x __pycache__` with the gate directory
as working directory, so the labels read `original/...`, `scripts/...` as in
the v1-v3 patches.
"""
import hashlib
import os
import shutil
import subprocess
import sys

GATE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama"


def files(root):
    out = []
    for sub in ("scripts", "tests"):
        d = os.path.join(root, sub)
        if os.path.isdir(d):
            out += [f"{sub}/{n}" for n in sorted(os.listdir(d)) if n.endswith(".py")]
    if os.path.exists(os.path.join(root, "counts/run_hash_counts.py")):
        out.append("counts/run_hash_counts.py")
    return out


def sha(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def main(argv):
    cmd = argv[0]
    if cmd == "check":
        man, root = argv[1], argv[2]
        bad = 0
        n = 0
        for line in open(man):
            d, p = line.split(None, 1)
            p = p.strip()
            n += 1
            if not os.path.exists(os.path.join(root, p)) or sha(os.path.join(root, p)) != d:
                print("MOVED", p)
                bad += 1
        listed = {line.split(None, 1)[1].strip() for line in open(man)}
        extra = [p for p in files(root) if p not in listed]
        for p in extra:
            print("NOT IN MANIFEST", p)
        print(f"{n} listed, {bad} moved, {len(extra)} unlisted")
        return 1 if bad or extra else 0
    if cmd == "snapshot":
        dest = argv[1]
        if os.path.exists(dest):
            raise SystemExit(f"{dest} exists; a snapshot is never overwritten")
        for p in files(GATE):
            os.makedirs(os.path.dirname(os.path.join(dest, p)), exist_ok=True)
            shutil.copy2(os.path.join(GATE, p), os.path.join(dest, p))
        print(f"{len(files(GATE))} files copied to {dest}")
        return 0
    if cmd == "manifest":
        out = argv[1]
        if os.path.exists(out):
            raise SystemExit(f"{out} exists; a manifest is never overwritten")
        with open(out, "w") as fh:
            for p in files(GATE):
                fh.write(f"{sha(os.path.join(GATE, p))}  {p}\n")
        print(f"{len(files(GATE))} files -> {out}  sha256 {sha(out)}")
        return 0
    if cmd == "patch":
        old, new, out = argv[1], argv[2], argv[3]
        if os.path.exists(out):
            raise SystemExit(f"{out} exists; a patch is never overwritten")
        p = subprocess.run(["diff", "-ruN", "-x", "__pycache__", old, new],
                           cwd=GATE, capture_output=True)
        with open(out, "wb") as fh:
            fh.write(p.stdout)
        print(f"diff exit {p.returncode}; {len(p.stdout)} B -> {out}  sha256 {sha(out)}")
        return 0 if p.returncode in (0, 1) else 2
    raise SystemExit(__doc__)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
