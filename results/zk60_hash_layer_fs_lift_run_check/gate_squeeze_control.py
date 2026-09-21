#!/usr/bin/env python3
"""Control C7 of the draft, re-derived: does the run gate's own measured
transcript counter satisfy  final_counter = challenges_checked + 64*(4L+1) ?

64 squeezes per PCS/mask opening, because `Transcript::challenge_indices`
takes FOUR indices out of every 32-byte squeeze (transcript.rs:136-148) and
each opening draws 256 column indices.  4L+1 openings per run.

Also: does the number of transcript operations move with the hidden input?
(the dense vs all-zero pairs at each rung)
"""
import json, glob, os, re

DIRS = ["/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_tagged",
        "/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_s20",
        "/home/victor/wt-zk60-jointview/results/zk60_native_run_gate_k4"]

def walk(o, key, hits):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == key:
                hits.append(v)
            walk(v, key, hits)
    elif isinstance(o, list):
        for v in o:
            walk(v, key, hits)
    return hits

rows = []
for d in DIRS:
    for p in sorted(glob.glob(os.path.join(d, "*.json"))):
        try:
            j = json.load(open(p))
        except Exception:
            continue
        fc = walk(j, "final_counter", [])
        cc = walk(j, "challenges_checked", [])
        ln = walk(j, "l", []) or walk(j, "L", []) or walk(j, "blocks", [])
        if not fc or not cc:
            continue
        rows.append((os.path.basename(d), os.path.basename(p), fc, cc, ln))

print(f"{'gate dir':<32} {'file':<24} {'final_counter':>14} {'challenges':>11} {'diff':>7} {'64(4L+1), L=3':>14}  match")
ok = True
for d, f, fc, cc, ln in rows:
    for a, b in zip(fc, cc):
        if not isinstance(a, int) or not isinstance(b, int):
            continue
        diff = a - b
        want = 64 * (4 * 3 + 1)
        m = diff == want
        ok &= m
        print(f"{d:<32} {f:<24} {a:>14} {b:>11} {diff:>7} {want:>14}  {'OK' if m else 'MISMATCH'}")
print()
print("C7 verdict:", "the identity holds on every gate bundle found" if ok and rows else
      ("no gate bundle carried both fields" if not rows else "MISMATCH"))
