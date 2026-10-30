#!/usr/bin/env python3
"""Token round 13: manifests and the freeze of the R-C2 tree (ops/zkp-mvp/token-io-r12b).

usage:
  freeze13.py snapshot OUT.sha256            manifest of the tree (target/ dirs and BASELINE.sha256
                                             skipped), `sha256  relpath` sorted; prints the list sha256
  freeze13.py compare A.sha256 B.sha256      changed / added / removed paths, B relative to A
  freeze13.py freeze CANDIDATE.sha256 DEST   copy exactly the candidate's files from the tree into DEST
                                             (refuses if DEST exists or any file's hash moved), then
                                             re-hash the copy against the candidate

The native tests write pid-named evidence directories under the tree's results/ (REVIEW_R12B
N-r12b-4), so the freeze copies the PRE-suite candidate's file list, after checking every file
of it is unchanged.
"""
import hashlib, os, shutil, sys

ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r12b"
# test-output directories the native R12b tests create under the tree's results/ (pid-named
# files; REVIEW_R12B N-r12b-4): never part of a source manifest
SKIP_DIRS = ("results/r12b-tests", "results/r12b-rope", "results/r12b-profile-fields")


def h(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def walk(root):
    out = {}
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x != "target" and os.path.relpath(os.path.join(d, x), root) not in SKIP_DIRS)
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


def main():
    cmd = sys.argv[1]
    if cmd == "snapshot":
        write(walk(ROOT), sys.argv[2])
    elif cmd == "compare":
        compare(load(sys.argv[2]), load(sys.argv[3]))
    elif cmd == "freeze":
        cand, dest = load(sys.argv[2]), sys.argv[3]
        if os.path.exists(dest):
            sys.exit(f"{dest} exists")
        for rel, d in cand.items():
            if h(os.path.join(ROOT, rel)) != d:
                sys.exit(f"moved since the candidate: {rel}")
        for rel in sorted(cand):
            os.makedirs(os.path.dirname(os.path.join(dest, rel)), exist_ok=True)
            shutil.copyfile(os.path.join(ROOT, rel), os.path.join(dest, rel))
        got = walk(dest)
        if got != cand:
            sys.exit("the copy does not re-hash to the candidate")
        print(f"frozen {len(got)} files into {dest}: all re-hashed match, none missing, none extra")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
