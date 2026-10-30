#!/usr/bin/env python3
"""Token round 18: the durable tree ops/zkp-mvp/token-io-r18, its manifests and its freeze.

usage:
  freeze18.py init                           copy frozen-r17/ (exactly the files of manifest_final_r17.sha256) into
                                             the new tree ops/zkp-mvp/token-io-r18 (refuses if it exists), re-hash
  freeze18.py stage                          check frozen-r17's (and the tree's) three baseline files =
                                             native_sources.json's baseline_sha256, then copy Astra's five staged
                                             files (each checked = staged_sha256 before and after) into hashline/
  freeze18.py snapshot OUT.sha256            manifest of the r18 tree (target/ dirs, BASELINE.sha256 and the
                                             native tests' pid-named evidence dirs skipped), `sha256  relpath`
  freeze18.py compare A.sha256 B.sha256      changed / added / removed paths, B relative to A
  freeze18.py freeze CANDIDATE.sha256 DEST   copy exactly the candidate's files from the r18 tree into DEST
                                             (refuses if DEST exists or any file's hash moved), then re-hash
  freeze18.py patch FILE PATCH               apply ONE patch (unified diff, one file) to the r18 tree's FILE
                                             with `patch` semantics checked here: every hunk's context must match

Same rules as r17/tools/freeze17.py; the tree root, the init source and the `stage` step differ.
Astra's candidate directory is READ ONLY: `stage` only reads it.
"""
import hashlib, json, os, re, shutil, sys

R = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-r18"
FROZEN17 = R + "/frozen-r17"
MANIFEST17 = R + "/manifest_final_r17.sha256"
A5 = "/home/victor/IntelligenceRegulation/results/zk60_astra_20261026/a5_batch_candidate"
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


def stage():
    src = json.load(open(A5 + "/native_sources.json"))
    for rel, d in sorted(src["baseline_sha256"].items()):
        got = h(os.path.join(FROZEN17, "hashline", rel))
        if got != d:
            sys.exit(f"baseline differs: frozen-r17/hashline/{rel} {got} != {d}")
        got = h(os.path.join(ROOT, "hashline", rel))
        if got != d:
            sys.exit(f"baseline differs: r18 tree hashline/{rel} {got} != {d}")
        print(f"baseline ok (frozen-r17 and the r18 tree): hashline/{rel} {d}")
    for rel, d in sorted(src["staged_sha256"].items()):
        s = os.path.join(A5, "staged", "hashline", rel)
        if os.path.islink(s) or h(s) != d:
            sys.exit(f"staged file differs: {s}")
        t = os.path.join(ROOT, "hashline", rel)
        if os.path.exists(t) and rel not in src["baseline_sha256"]:
            sys.exit(f"{t} exists; the stage creates it")
        shutil.copyfile(s, t)
        if h(t) != d:
            sys.exit(f"copied file differs: {t}")
        print(f"staged: hashline/{rel} {d}")


def apply_patch(target, patch):
    """a minimal unified-diff applier for ONE file: every hunk's old lines (context and removals) must match the
    target at the hunk's position exactly; a new file (`--- /dev/null`) must not exist yet"""
    lines = open(patch).read().split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    i = 0
    while i < len(lines) and not lines[i].startswith("--- "):
        i += 1
    new_file = lines[i].startswith("--- /dev/null")
    i += 2  # the --- and +++ lines
    if new_file:
        if os.path.exists(target):
            sys.exit(f"{target} exists; the patch creates it")
        old = []
    else:
        old = open(target).read().split("\n")
        if old and old[-1] == "":
            old = old[:-1]
    out, pos, hunks = [], 0, 0
    hre = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
    while i < len(lines):
        m = hre.match(lines[i])
        if not m:
            sys.exit(f"{patch}: no hunk header at line {i + 1}: {lines[i]!r}")
        start = int(m.group(1)) - (0 if new_file else 1)
        if new_file:
            start = 0
        out.extend(old[pos:start])
        pos = start
        i += 1
        while i < len(lines) and not lines[i].startswith("@@ "):
            ln = lines[i]
            tag, body = (ln[:1], ln[1:]) if ln else (" ", "")
            if tag == "\\":
                i += 1
                continue
            if tag in (" ", "-"):
                if pos >= len(old) or old[pos] != body:
                    sys.exit(f"{patch}: hunk {hunks + 1}: context differs at target line {pos + 1}: "
                             f"{(old[pos] if pos < len(old) else None)!r} != {body!r}")
                pos += 1
                if tag == " ":
                    out.append(body)
            elif tag == "+":
                out.append(body)
            else:
                sys.exit(f"{patch}: unknown line tag {tag!r}")
            i += 1
        hunks += 1
    out.extend(old[pos:])
    with open(target, "w") as f:
        f.write("\n".join(out) + "\n")
    print(f"{target}: {hunks} hunk(s) applied from {patch}; sha256 {h(target)}")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "init":
        print(f"{MANIFEST17}: list sha256 {h(MANIFEST17)}")
        copy_exact(load(MANIFEST17), FROZEN17, ROOT)
    elif cmd == "stage":
        stage()
    elif cmd == "snapshot":
        write(walk(ROOT), sys.argv[2])
    elif cmd == "compare":
        compare(load(sys.argv[2]), load(sys.argv[3]))
    elif cmd == "freeze":
        copy_exact(load(sys.argv[2]), ROOT, sys.argv[3])
    elif cmd == "patch":
        target = sys.argv[2] if os.path.isabs(sys.argv[2]) else os.path.join(ROOT, sys.argv[2])
        apply_patch(target, sys.argv[3])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
