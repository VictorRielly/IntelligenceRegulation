#!/usr/bin/env python3
"""[gate round 10, the frozen-r9 re-pin] Patch and source manifest of the
gate's tk9 copy (the token lane's frozen round-9 tree) against frozen-r9, plus
the capture's source-pin list (run_capture.rs OWN_SOURCE_FILES +
SHARED_SOURCE_FILES, parsed from the FROZEN r9 file) with each pin's sha256 in
frozen-r9, in this copy, in the gate's tk7 copy and in frozen-r7.  Adapted
from ../tk7/record_sources.py.
    python3 record_sources.py <tag>
Writes next to this script, never overwriting:
  trained-1b-gate-tk9-vs-frozen-r9.<tag>.patch
  trained-1b-gate-tk9.sources.<tag>.sha256
  tk9-source-pins.<tag>.json"""
import hashlib, json, os, re, subprocess, sys
E = os.path.dirname(os.path.abspath(__file__))
OLD = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/frozen-r9"
R7 = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/frozen-r7"
TK7 = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk7"
NEW = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk9"
tag = sys.argv[1]
pp = os.path.join(E, f"trained-1b-gate-tk9-vs-frozen-r9.{tag}.patch")
mp = os.path.join(E, f"trained-1b-gate-tk9.sources.{tag}.sha256")
jp = os.path.join(E, f"tk9-source-pins.{tag}.json")
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
    r9, cp, k7, r7 = (sha(os.path.join(t, rel)) for t in (OLD, NEW, TK7, R7))
    rows.append({"pin": name, "path_in_tree": rel, "sha256_r9_frozen": r9, "sha256_gate_copy": cp,
                 "sha256_gate_tk7_copy": k7, "sha256_r7_frozen": r7,
                 "copy_differs_from_r9": cp != r9, "differs_from_the_gate_tk7_copy": cp != k7})
doc = {"note": "the run capture's source pins (run_capture.rs OWN_SOURCE_FILES + SHARED_SOURCE_FILES of frozen-r9), sha256 per tree; the gate copy differs from frozen-r9 only where the capture patch touched a pinned file (run_capture.rs)",
       "count": len(rows), "r9_tree": OLD, "gate_copy": NEW, "gate_tk7_copy": TK7, "r7_tree": R7,
       "copy_differs_from_r9": [r["pin"] for r in rows if r["copy_differs_from_r9"]],
       "differs_from_the_gate_tk7_copy": [r["pin"] for r in rows if r["differs_from_the_gate_tk7_copy"]],
       "pins": rows}
json.dump(doc, open(jp, "w"), indent=1)
print(f"pins {len(rows)}; copy differs from r9 in {doc['copy_differs_from_r9']}; differs from the gate tk7 copy in {doc['differs_from_the_gate_tk7_copy']}")
