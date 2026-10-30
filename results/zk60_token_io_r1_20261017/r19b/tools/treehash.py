#!/usr/bin/env python3
"""treehash.py DIR OUT.json: the SHA-256 of every file under DIR (relative paths) and of the sorted `digest  path` list.
Token round 19 (reused in 19b): the real receipt's bytes before and after each verify (a verify must leave them unchanged)."""
import hashlib, json, os, sys
d, out = sys.argv[1], sys.argv[2]
files = {}
for root, _, fs in os.walk(d):
    for f in fs:
        p, h = os.path.join(root, f), hashlib.sha256()
        with open(p, "rb") as fh:
            for b in iter(lambda: fh.read(1 << 20), b""):
                h.update(b)
        files[os.path.relpath(p, d)] = h.hexdigest()
listing = "".join(f"{files[k]}  {k}\n" for k in sorted(files))
rec = {"dir": d, "files": len(files), "bytes": sum(os.path.getsize(os.path.join(d, k)) for k in files), "tree_sha256": hashlib.sha256(listing.encode()).hexdigest(), "digests": files}
json.dump(rec, open(out, "w"), indent=1, sort_keys=True)
print(json.dumps({k: rec[k] for k in ("dir", "files", "bytes", "tree_sha256")}))
