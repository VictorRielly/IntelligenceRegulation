#!/usr/bin/env python3
"""Token round 14: the durable tree ops/zkp-mvp/token-io-r14, its manifests and its freeze.

usage:
  freeze14.py init                           copy exactly frozen-r13's 257 files (manifest_final_r13) from
                                             ops/zkp-mvp/token-io-r12b into ops/zkp-mvp/token-io-r14 (refuses
                                             if the destination exists or a file moved), then re-hash the copy
  freeze14.py snapshot OUT.sha256            manifest of the r14 tree (target/ dirs, BASELINE.sha256 and the
                                             native tests' pid-named evidence dirs skipped), `sha256  relpath`
  freeze14.py compare A.sha256 B.sha256      changed / added / removed paths, B relative to A
  freeze14.py freeze CANDIDATE.sha256 DEST   copy exactly the candidate's files from the r14 tree into DEST
                                             (refuses if DEST exists or any file's hash moved), then re-hash

Same rules as r13/tools/freeze13.py; only the tree root differs, and the skip list also names the
native R12b tied test's pid-named output dirs results/r12-tied-<pid>/ (seen after s17).
"""
import hashlib, os, re, shutil, sys

R = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
SRC = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r12b"
ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r14"
SKIP_DIRS = ("results/r12b-tests", "results/r12b-rope", "results/r12b-profile-fields")
SKIP_RE = re.compile(r"^results/r12-tied-\d+$")


def h(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def walk(root):
    out = {}
    for d, dirs, files in os.walk(root):
        keep = []
        for x in sorted(dirs):
            rel = os.path.relpath(os.path.join(d, x), root)
            if x == "target" or rel in SKIP_DIRS or SKIP_RE.match(rel):
                continue
            keep.append(x)
        dirs[:] = keep
        for f in files:
            p = os.path.join(d, f)
            rel = os.path.relpath(p, root)
            if rel == "BASELINE.sha256":
                continue
            if os.path.islink(p) or not os.path.isfile(p):
                sys.exit(f"not a regular file: {p}")
            out[rel] = h(p)
    return out


def write(m, path):
    with open(path, "w") as f:
        for rel in sorted(m):
            f.write(f"{m[rel]}  {rel}\n")
    print(f"{path}: {len(m)} files, list sha256 {h(path)}")


def load(path):
    m = {}
    for line in open(path):
        line = line.rstrip("\n")
        if line:
            d, rel = line.split("  ", 1)
            m[rel] = d
    return m


def compare(a, b):
    changed = sorted(k for k in a if k in b and a[k] != b[k])
    added = sorted(k for k in b if k not in a)
    removed = sorted(k for k in a if k not in b)
    print(f"changed {len(changed)}: {changed}")
    print(f"added {len(added)}: {added}")
    print(f"removed {len(removed)}: {removed}")
    return changed, added, removed


def copy_exact(cand, src, dest):
    if os.path.exists(dest):
        sys.exit(f"{dest} exists")
    for rel, d in cand.items():
        if h(os.path.join(src, rel)) != d:
            sys.exit(f"moved since the candidate: {rel}")
    for rel in sorted(cand):
        os.makedirs(os.path.dirname(os.path.join(dest, rel)), exist_ok=True)
        shutil.copyfile(os.path.join(src, rel), os.path.join(dest, rel))
    got = walk(dest)
    if got != cand:
        sys.exit("the copy does not re-hash to the candidate")
    print(f"copied {len(got)} files into {dest}: all re-hashed match, none missing, none extra")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "init":
        copy_exact(load(f"{R}/manifest_final_r13.sha256"), SRC, ROOT)
    elif cmd == "snapshot":
        write(walk(ROOT), sys.argv[2])
    elif cmd == "compare":
        compare(load(sys.argv[2]), load(sys.argv[3]))
    elif cmd == "freeze":
        copy_exact(load(sys.argv[2]), ROOT, sys.argv[3])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
