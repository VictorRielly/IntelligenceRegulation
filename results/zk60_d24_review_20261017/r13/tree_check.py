"""Recompute a frozen tree's file list and tree hash against manifest_frozen.json.

Tree hash = sha256 over sorted "path hash\n" lines (the convention used since R5).
Usage: python3 tree_check.py <tree-root> <manifest_frozen.json>
"""
import hashlib
import json
import os
import sys

root, manifest = sys.argv[1], sys.argv[2]
m = json.load(open(manifest))
files = {}
for dp, dns, fns in os.walk(root):
    rel = os.path.relpath(dp, root)
    parts = [] if rel == "." else rel.split(os.sep)
    if parts and (parts[0].startswith("target") or parts[0] == ".git"):
        dns[:] = []
        continue
    dns[:] = [d for d in dns if not d.startswith("target") and d != ".git"]
    for f in fns:
        p = os.path.join(dp, f)
        rp = os.path.relpath(p, root)
        if os.path.islink(p):
            files[rp] = "SYMLINK"
            continue
        h = hashlib.sha256(open(p, "rb").read()).hexdigest()
        files[rp] = h
want = m["files"]
extra = sorted(set(files) - set(want))
missing = sorted(set(want) - set(files))
diff = sorted(k for k in set(files) & set(want) if files[k] != want[k])
lines = "".join(f"{k} {want[k]}\n" for k in sorted(want))
tree = hashlib.sha256(lines.encode()).hexdigest()
lines2 = "".join(f"{k}  {want[k]}\n" for k in sorted(want))
tree2 = hashlib.sha256(lines2.encode()).hexdigest()
print(json.dumps({
    "root": root,
    "found": len(files),
    "manifest_count": m["count"],
    "extra": extra[:20],
    "n_extra": len(extra),
    "missing": missing,
    "differ": diff,
    "tree_sha256_recomputed_single_space": tree,
    "tree_sha256_recomputed_double_space": tree2,
    "tree_sha256_manifest": m["tree_sha256"],
    "match": tree == m["tree_sha256"] or tree2 == m["tree_sha256"],
}, indent=1))
