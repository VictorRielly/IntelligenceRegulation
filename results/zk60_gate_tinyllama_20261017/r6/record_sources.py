#!/usr/bin/env python3
"""Patch and source manifest of the gate's R6 copy against the native lane's
frozen R6 tree, plus the capture's source-pin list (run_capture.rs
OWN_SOURCE_FILES + SHARED_SOURCE_FILES, parsed from the FROZEN R6 file) with
each pin's sha256 in the frozen R6 tree, in this copy, and in the frozen R5b
tree. Adapted from ../r5b/record_sources.py.
    python3 record_sources.py <tag>
Writes next to this script, never overwriting:
  trained-1b-gate-r6-vs-frozen-r6.<tag>.patch
  trained-1b-gate-r6.sources.<tag>.sha256
  r6-source-pins.<tag>.json"""
import hashlib, json, os, re, subprocess, sys
E = os.path.dirname(os.path.abspath(__file__))
OLD = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r6/frozen-tree"
R5B = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5b/frozen-tree"
NEW = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r6"
tag = sys.argv[1]
pp = os.path.join(E, f"trained-1b-gate-r6-vs-frozen-r6.{tag}.patch")
mp = os.path.join(E, f"trained-1b-gate-r6.sources.{tag}.sha256")
jp = os.path.join(E, f"r6-source-pins.{tag}.json")
for f in (pp, mp, jp):
    if os.path.exists(f):
        raise SystemExit(f"{f} exists")


def sha(path):
    try:
        return hashlib.sha256(open(path, "rb").read()).hexdigest()
    except FileNotFoundError:
        return None


p = subprocess.run(["diff", "-ruN", "--exclude=target*", OLD, NEW], capture_output=True)
open(pp, "wb").write(p.stdout)
lines = []
for dp, dn, fn in os.walk(NEW):
    dn[:] = sorted(x for x in dn if not x.startswith("target"))
    for n in sorted(fn):
        f = os.path.join(dp, n)
        lines.append((os.path.relpath(f, NEW), sha(f)))
open(mp, "w").write("".join(f"{d}  {r}\n" for r, d in sorted(lines)))
files = [l.split()[-1] for l in p.stdout.decode().splitlines() if l.startswith("diff ")]
print(f"patch {len(p.stdout)} B sha256 {hashlib.sha256(p.stdout).hexdigest()}; files changed {len(files)}")
print(f"sources {len(lines)} files sha256 {hashlib.sha256(open(mp, 'rb').read()).hexdigest()}")
for f in files:
    print("  ", os.path.relpath(f, NEW))

# the capture's source pins, in the order source_files() returns them
src = open(os.path.join(OLD, "hashline/src/private_block/run_capture.rs")).read()


def arr(name):
    m = re.search(r"pub\(super\) const " + name + r": \[&str; (\d+)\] = \[(.*?)\n\];", src, re.S)
    body = "\n".join(l.split("//")[0] for l in m.group(2).splitlines())
    items = re.findall(r'"([^"]+)"', body)
    assert len(items) == int(m.group(1)), (name, len(items), m.group(1))
    return items


pins = arr("OWN_SOURCE_FILES") + arr("SHARED_SOURCE_FILES")
rows = []
for name in pins:
    rel = os.path.normpath(os.path.join("hashline", name))
    r6, cp, r5 = sha(os.path.join(OLD, rel)), sha(os.path.join(NEW, rel)), sha(os.path.join(R5B, rel))
    rows.append({"pin": name, "path_in_tree": rel, "sha256_r6_frozen": r6, "sha256_gate_copy": cp,
                 "sha256_r5b_frozen": r5, "copy_differs_from_r6": cp != r6, "r6_differs_from_r5b": r6 != r5})
doc = {"note": "the run capture's source pins (run_capture.rs OWN_SOURCE_FILES + SHARED_SOURCE_FILES of the frozen R6 tree), sha256 per tree; the gate copy differs only where the capture patch touched a pinned file (run_capture.rs)",
       "count": len(rows), "r6_tree": OLD, "gate_copy": NEW, "r5b_tree": R5B,
       "copy_differs_from_r6": [r["pin"] for r in rows if r["copy_differs_from_r6"]],
       "r6_differs_from_r5b": [r["pin"] for r in rows if r["r6_differs_from_r5b"]],
       "pins": rows}
json.dump(doc, open(jp, "w"), indent=1)
print(f"pins {len(rows)}; copy differs from R6 in {doc['copy_differs_from_r6']}; R6 differs from R5b in {doc['r6_differs_from_r5b']}")
