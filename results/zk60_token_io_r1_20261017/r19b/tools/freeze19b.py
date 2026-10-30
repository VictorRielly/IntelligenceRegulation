#!/usr/bin/env python3
"""Token round 19b: the durable tree ops/zkp-mvp/token-io-r19b, its manifests and its freeze.

usage:
  freeze19b.py init                          copy frozen-r19/ (exactly the files of manifest_final_r19.sha256) into
                                             the new tree ops/zkp-mvp/token-io-r19b (refuses if it exists), re-hash;
                                             no target/ is copied (D46: frozen-r19 has none, and the manifest lists
                                             none)
  freeze19b.py snapshot OUT.sha256           manifest of the r19b tree (target/ dirs, BASELINE.sha256 and the
                                             native tests' pid-named evidence dirs skipped), `sha256  relpath`
  freeze19b.py compare A.sha256 B.sha256      changed / added / removed paths, B relative to A
  freeze19b.py freeze CANDIDATE.sha256 DEST   copy exactly the candidate's files from the r19b tree into DEST
                                             (refuses if DEST exists or any file's hash moved), then re-hash
  freeze19b.py save LIST OUTDIR               copy the r19b tree's files named in LIST (one relpath per line) into
                                             OUTDIR/<relpath> (a state's sources, e.g. r19b/wip/red), with sha256s

r19/tools/freeze19.py re-rooted (tree token-io-r19b, init source frozen-r19); otherwise the same rules.
"""
import hashlib, os, re, shutil, sys

R = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r19b"
FROZEN19 = R + "/frozen-r19"
MANIFEST19 = R + "/manifest_final_r19.sha256"
SKIP_DIRS = ("results/r12b-tests", "results/r12b-rope", "results/r12b-profile-fields", "results/r13-array-tests")
SKIP_RE = re.compile(r"^results/(r12-tied-\d+|r13-[a-z0-9-]+-\d+)$")


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


def save(listfile, outdir):
    rels = [l.strip() for l in open(listfile) if l.strip()]
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "SOURCES.sha256"), "w") as m:
        for rel in rels:
            s = os.path.join(ROOT, rel)
            t = os.path.join(outdir, rel)
            os.makedirs(os.path.dirname(t), exist_ok=True)
            shutil.copyfile(s, t)
            if h(s) != h(t):
                sys.exit(f"copy differs: {rel}")
            m.write(f"{h(t)}  {rel}\n")
            print(f"saved {rel} {h(t)}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "init":
        print(f"{MANIFEST19}: list sha256 {h(MANIFEST19)}")
        copy_exact(load(MANIFEST19), FROZEN19, ROOT)
    elif cmd == "snapshot":
        write(walk(ROOT), sys.argv[2])
    elif cmd == "compare":
        compare(load(sys.argv[2]), load(sys.argv[3]))
    elif cmd == "freeze":
        copy_exact(load(sys.argv[2]), ROOT, sys.argv[3])
    elif cmd == "save":
        save(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
