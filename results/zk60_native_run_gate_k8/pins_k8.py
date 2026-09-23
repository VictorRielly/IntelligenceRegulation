#!/usr/bin/env python3
"""ROUND 9i, K1: the rung-K8 bundles' 38 source pins against the lane's
committed blobs, and against the last capture commit this gate read.

    python3 results/zk60_native_run_gate_k8/pins_k8.py > pins_k8.txt

Read-only against the lane worktree (`git show <commit>:<path>`, never its
working tree).  Prints: whether both bundles pin identical sets; whether
every pin equals the blob at `99a8de8`; which pins differ from the rung-E32
bundles' (the last pins this gate accepted, blobs at `6d71b40`); and the
`--numstat` of each moved file between the two commits.
"""

import hashlib
import json
import subprocess

L = "/home/victor/wt-zk60-block125m"
B = L + "/results/zk60_run_captures_20260920"
K8 = L + "/results/zk60_run_captures_20260922_k8"


def pins(d):
    with open(d + "/manifest.json") as fh:
        m = json.load(fh)
    return {p["file"]: p["sha256"] for p in m["source_pins"]}, m["source_commit"]


def repo_path(f):
    return f[3:] if f.startswith("../") else "hashline/" + f


def blob_sha(commit, f):
    r = subprocess.run(["git", "--no-pager", "-C", L, "show",
                        f"{commit}:{repo_path(f)}"], capture_output=True)
    return hashlib.sha256(r.stdout).hexdigest() if r.returncode == 0 else None


e32, ce = pins(B + "/run-q-dense-e32")
s, cs = pins(K8 + "/run-s-dense-k8")
t, ct = pins(K8 + "/run-t-zero-k8")
print(f"source_commit: rung-E32 {ce}, run-s {cs}, run-t {ct}")
print(f"run-s and run-t pin identical sets: {s == t} ({len(s)} pins)")
bad = [f for f in s if blob_sha("99a8de8", f) != s[f]]
print(f"pins not equal to the blob at 99a8de8: {bad} ({len(s) - len(bad)} of {len(s)} equal)")
e32_blob_bad = [f for f in e32 if blob_sha("6d71b40", f) != e32[f]]
print(f"rung-E32 pins not equal to the blob at 6d71b40: {e32_blob_bad}")
moved = sorted(f for f in set(s) | set(e32) if s.get(f) != e32.get(f))
print(f"moved since the rung-E32 bundles: {len(moved)}")
for f in moved:
    ns = subprocess.run(["git", "--no-pager", "-C", L, "diff", "--numstat",
                         "6d71b40", "99a8de8", "--", repo_path(f)],
                        capture_output=True, text=True).stdout.strip()
    print(f"  {f}: {e32.get(f, '-')[:16]} -> {s.get(f, '-')[:16]}   numstat: {ns}")
