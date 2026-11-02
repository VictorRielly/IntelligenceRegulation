#!/usr/bin/env python3
"""TS / CENSUS / bases lane (2026-11-02): copy each new bundle's manifest.json and README.md into bundle_manifests/
and write MANIFEST_SHA256.txt (the bundles themselves stay outside the repository)."""
import hashlib
import os
import shutil

N = "/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases"
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bundle_manifests")
os.makedirs(D, exist_ok=True)
lines = []
for b in sorted(x for x in os.listdir(N) if x.startswith("d55-")):
    os.makedirs(os.path.join(D, b), exist_ok=True)
    for f in ("manifest.json", "README.md"):
        src = os.path.join(N, b, f)
        shutil.copyfile(src, os.path.join(D, b, f))
        lines.append(f"{hashlib.sha256(open(src, 'rb').read()).hexdigest()}  {b}/{f}")
with open(os.path.join(D, "MANIFEST_SHA256.txt"), "w") as fh:
    fh.write("\n".join(lines) + "\n")
print("\n".join(lines))
