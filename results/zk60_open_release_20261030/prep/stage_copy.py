#!/usr/bin/env python3
"""Plan step 3: copy every candidate_files.tsv row with decision != exclude into the
staging tree, and check each copy's sha256 against the inventory.

Read-only over the private repo. Refuses to run if the staging dir already exists.
Usage: python3 -I stage_copy.py [staging_dir]   (default /home/victor/ir-public)
Writes prep/stage_copy.json (counts, mismatches).
"""
import csv
import hashlib
import json
import os
import shutil
import sys

R = "/home/victor/IntelligenceRegulation/"
HERE = os.path.dirname(os.path.abspath(__file__))
TSV = R + "results/zk60_open_release_20261030/candidate_files.tsv"
D = sys.argv[1] if len(sys.argv) > 1 else "/home/victor/ir-public"
FORBIDDEN = (".testnet-private", "zk60-owner-private", "/.venv/", "/target/", ".git/")

if os.path.exists(D):
    sys.exit(f"refusing: {D} already exists")


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


rows = list(csv.DictReader(open(TSV), delimiter="\t"))
copied, nbytes, mism, refused = 0, 0, [], []
for r in rows:
    if r["decision"] == "exclude":
        continue
    src = R + r["source_path"]
    if any(x in src for x in FORBIDDEN) or any(x in r["public_path"] for x in FORBIDDEN):
        refused.append(r["public_path"])
        continue
    dst = os.path.join(D, r["public_path"])
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    copied += 1
    nbytes += os.path.getsize(dst)
    if r["sha256"] and sha(dst) != r["sha256"]:
        mism.append(r["public_path"])
out = {"staging": D, "rows": len(rows), "copied": copied, "bytes": nbytes,
       "sha256_mismatch_vs_inventory": mism, "refused_forbidden": refused}
json.dump(out, open(os.path.join(HERE, "stage_copy.json"), "w"), indent=1)
print(json.dumps({k: (v if not isinstance(v, list) else len(v)) for k, v in out.items()}))
