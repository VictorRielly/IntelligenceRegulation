#!/usr/bin/env python3
"""D59 condition (5) privacy re-check (2026-11-02): keep each test-only capture bundle's manifest.json (every
file's bytes and SHA-256, the source pins) and README.md in the results; the bundles themselves stay in the
session scratchpad (tens of MB each, test-only, synthetic)."""
import hashlib
import os
import shutil

B = "/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles"
OUT = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f/results/zk60_w16r2_20261101/privacy_recheck_bundle_manifests"
for name in sorted(os.listdir(B)):
    d = os.path.join(B, name)
    for fn in ("manifest.json", "README.md"):
        src = os.path.join(d, fn)
        dst = os.path.join(OUT, f"{name}.{fn}")
        shutil.copyfile(src, dst)
    with open(os.path.join(d, "manifest.json"), "rb") as fh:
        print(name, "manifest sha256", hashlib.sha256(fh.read()).hexdigest())
