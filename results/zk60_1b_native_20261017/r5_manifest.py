"""NATIVE lane round 5: sha256 manifest of the working copy's sources.

usage: python3 r5_manifest.py <out.json> [note]
Hashes every file under ops/zkp-mvp/trained-1b/ except build outputs
(target*/) so a reviewer can copy the exact tree (or check a copy against it).
"""
import hashlib
import json
import os
import sys
import time

ROOT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b"


def main():
    global ROOT
    out = sys.argv[1]
    note = sys.argv[2] if len(sys.argv) > 2 else ""
    if len(sys.argv) > 3:
        ROOT = sys.argv[3]
    files = {}
    for dp, dn, fn in os.walk(ROOT):
        dn[:] = sorted(d for d in dn if not d.startswith("target"))
        for n in sorted(fn):
            p = os.path.join(dp, n)
            if os.path.islink(p):
                continue
            with open(p, "rb") as f:
                files[os.path.relpath(p, ROOT)] = hashlib.sha256(f.read()).hexdigest()
    tree = hashlib.sha256("".join(f"{k} {v}\n" for k, v in sorted(files.items())).encode()).hexdigest()
    doc = {
        "note": note,
        "root": ROOT,
        "written_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "tree_sha256": tree,
        "count": len(files),
        "files": files,
    }
    with open(out, "w") as f:
        json.dump(doc, f, indent=1, sort_keys=True)
    print(f"{out}: {len(files)} files, tree {tree}")


if __name__ == "__main__":
    main()
