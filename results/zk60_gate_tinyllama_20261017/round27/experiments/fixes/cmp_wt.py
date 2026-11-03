"""does the fixer's worktree hold exactly ec12ffb2's bytes for the gate files?"""
import hashlib
import os
import sys

root, tree = sys.argv[1], sys.argv[2]
bad, n = [], 0
for line in open(tree):
    meta, p = line.rstrip("\n").split("\t")
    full = os.path.join(root, p)
    if not os.path.exists(full):
        bad.append((p, "missing"))
        continue
    d = open(full, "rb").read()
    if hashlib.sha1(b"blob %d\0" % len(d) + d).hexdigest() != meta.split()[2]:
        bad.append((p, "differs"))
    n += 1
extra = []
for dp, _dn, fn in os.walk(os.path.join(root, "ops/zkp-mvp/gate-tinyllama/staging_v25")):
    for f in fn:
        r = os.path.relpath(os.path.join(dp, f), root)
        if "__pycache__" not in r and r not in {l.split("\t")[1].strip() for l in open(tree)}:
            extra.append(r)
print("checked", n, "mismatches", bad, "untracked", extra)
