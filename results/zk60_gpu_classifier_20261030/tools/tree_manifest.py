#!/usr/bin/env python3
"""GPU classifier lane: sha256 manifest of a source tree (no target dirs), and a diff against a reference manifest.
usage: tree_manifest.py ROOT OUT.sha256 [REFERENCE.sha256]"""
import hashlib, os, sys
root, out = sys.argv[1], sys.argv[2]
rows = []
for d, dirs, files in os.walk(root):
    dirs[:] = sorted(x for x in dirs if x != 'target' and not x.startswith('target-'))
    for f in sorted(files):
        p = os.path.join(d, f)
        h = hashlib.sha256(open(p, 'rb').read()).hexdigest()
        rows.append((os.path.relpath(p, root), h))
rows.sort()
with open(out, 'w') as fh:
    for r, h in rows:
        fh.write(f"{h}  {r}\n")
print(f"{len(rows)} files -> {out}")
if len(sys.argv) > 3:
    ref = {}
    for line in open(sys.argv[3]):
        h, r = line.rstrip('\n').split('  ', 1)
        ref[r] = h
    cur = dict((r, h) for r, h in rows)
    changed = sorted(r for r in cur if r in ref and ref[r] != cur[r])
    added = sorted(r for r in cur if r not in ref)
    removed = sorted(r for r in ref if r not in cur)
    print(f"vs {sys.argv[3]}: {len(changed)} changed, {len(added)} added, {len(removed)} removed")
    for r in changed: print("  changed", r)
    for r in added: print("  added", r)
    for r in removed: print("  removed", r)
