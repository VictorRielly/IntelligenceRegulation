#!/usr/bin/env python3
"""[round 8] Patch and source manifest of the gate's tk7 copy (token round-7 frozen tree) against the native-plus-token lane's
frozen R7 tree, plus the capture's source-pin list (run_capture.rs
OWN_SOURCE_FILES + SHARED_SOURCE_FILES, parsed from the FROZEN R7 file) with
each pin's sha256 in the frozen R7 tree, in this copy, and in the frozen R5b
tree. Adapted from ../r6/record_sources.py (P-18 helper), itself from ../r5b.
    python3 record_sources.py <tag>
Writes next to this script, never overwriting:
  trained-1b-gate-tk7-vs-frozen-tk7.<tag>.patch
  trained-1b-gate-tk7.sources.<tag>.sha256
  tk7-source-pins.<tag>.json"""
import hashlib, json, os, re, subprocess, sys
E = os.path.dirname(os.path.abspath(__file__))
OLD = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/frozen-r7"
R5B = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r7"  # the gate R7 copy (accepted by D33)
NEW = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk7"
tag = sys.argv[1]
pp = os.path.join(E, f"trained-1b-gate-tk7-vs-frozen-tk7.{tag}.patch")
mp = os.path.join(E, f"trained-1b-gate-tk7.sources.{tag}.sha256")
jp = os.path.join(E, f"tk7-source-pins.{tag}.json")
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
    r7, cp, r5 = sha(os.path.join(OLD, rel)), sha(os.path.join(NEW, rel)), sha(os.path.join(R5B, rel))
    rows.append({"pin": name, "path_in_tree": rel, "sha256_r7_frozen": r7, "sha256_gate_copy": cp,
                 "sha256_gate_r7_copy": r5, "copy_differs_from_r7": cp != r7, "tk7_frozen_differs_from_gate_r7": r7 != r5})
doc = {"note": "the run capture's source pins (run_capture.rs OWN_SOURCE_FILES + SHARED_SOURCE_FILES of the frozen R7 tree), sha256 per tree; the gate copy differs only where the capture patch touched a pinned file (run_capture.rs)",
       "count": len(rows), "r7_tree": OLD, "gate_copy": NEW, "gate_r7_copy": R5B,
       "copy_differs_from_r7": [r["pin"] for r in rows if r["copy_differs_from_r7"]],
       "tk7_frozen_differs_from_gate_r7": [r["pin"] for r in rows if r["tk7_frozen_differs_from_gate_r7"]],
       "pins": rows}
json.dump(doc, open(jp, "w"), indent=1)
print(f"pins {len(rows)}; copy differs from R7 in {doc['copy_differs_from_r7']}; frozen tk7 differs from the gate R7 copy in {doc['tk7_frozen_differs_from_gate_r7']}")
