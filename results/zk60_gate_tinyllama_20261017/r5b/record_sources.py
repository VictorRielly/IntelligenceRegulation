#!/usr/bin/env python3
"""Patch and source manifest of the gate's R5 copy against the native lane's
frozen R5 tree.   python3 record_sources.py <tag>   (writes
trained-1b-gate-r5b-vs-frozen-r5b.<tag>.patch and trained-1b-gate-r5b.sources.<tag>.sha256
next to this script; never overwrites)."""
import hashlib, os, subprocess, sys
E = os.path.dirname(os.path.abspath(__file__))
OLD = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5b/frozen-tree"
NEW = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r5b"
tag = sys.argv[1]
pp = os.path.join(E, f"trained-1b-gate-r5b-vs-frozen-r5b.{tag}.patch")
mp = os.path.join(E, f"trained-1b-gate-r5b.sources.{tag}.sha256")
for f in (pp, mp):
    if os.path.exists(f):
        raise SystemExit(f"{f} exists")
p = subprocess.run(["diff", "-ruN", "--exclude=target", OLD, NEW], capture_output=True)
open(pp, "wb").write(p.stdout)
lines = []
for dp, dn, fn in os.walk(NEW):
    dn[:] = sorted(x for x in dn if not x.startswith("target"))
    for n in sorted(fn):
        f = os.path.join(dp, n)
        lines.append((os.path.relpath(f, NEW), hashlib.sha256(open(f, "rb").read()).hexdigest()))
open(mp, "w").write("".join(f"{d}  {r}\n" for r, d in sorted(lines)))
files = [l.split()[-1] for l in p.stdout.decode().splitlines() if l.startswith("diff ")]
print(f"patch {len(p.stdout)} B sha256 {hashlib.sha256(p.stdout).hexdigest()}; files changed {len(files)}")
print(f"sources {len(lines)} files sha256 {hashlib.sha256(open(mp,'rb').read()).hexdigest()}")
for f in files:
    print("  ", os.path.relpath(f, NEW))
