#!/usr/bin/env python3
"""B-check of the draft's finding F-1 and of its transcript-domain length table.

Written WITHOUT reading the draft's own script, from the Rust at 8c5922b.
It reads ONLY public fields of the committed capture bundles: each stage's
`start_tag` / `end_tag` (32-byte transcript POSITIONS the verifier re-derives
and compares, run.rs:625 / :765) and each run's `profile` /
`transcript_domain`.  No witness, salt, column, path or private plane is read.

Checks
  F-1a  end_tag(k) == start_tag(k+1) for every k, on every bundle
  F-1b  the 2L tag fields carry exactly L+1 distinct values
  F-1c  the tags are NOT constant (a degenerate way to pass F-1a)
  F-1d  start_tag(0) differs across bundles of the SAME profile that differ
        only in the hidden input  -- a tag is a function of the published
        prefix, so at stage 0 (nothing hidden absorbed yet) the two runs'
        FIRST tags must be EQUAL; later tags must differ.  This is the
        sharper version of the draft's claim N9 and it is not in the draft.
  L-1   the transcript constructor input length 12 + |domain| per profile
        (transcript.rs:29-45: "hashline-v1/" || domain), against the 47-byte
        squeeze class (squeeze_bytes: state(32) || "squeeze"(7) || le64(8)).
"""
import json, glob, os

ROOT = "/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920"
CONSTRUCTOR_PREFIX = len(b"hashline-v1/")          # 12, transcript.rs:31
SQUEEZE_LEN = 32 + len(b"squeeze") + 8             # 47, transcript.rs:103-107
ABSORB_FIXED = 32 + 8 + 8                          # 48, transcript.rs:61-66


def load(bundle):
    run = json.load(open(os.path.join(bundle, "run.json")))
    stages = []
    for sp in sorted(glob.glob(os.path.join(bundle, "stage-*.json"))):
        s = json.load(open(sp))
        stages.append((tuple(s["start_tag"]), tuple(s["end_tag"])))
    return run, stages


rows = []
by_profile = {}
for bundle in sorted(glob.glob(os.path.join(ROOT, "run-*"))):
    if not os.path.isdir(bundle):
        continue
    run, stages = load(bundle)
    L = len(stages)
    starts = [a for a, _ in stages]
    ends = [b for _, b in stages]
    chain = all(ends[k] == starts[k + 1] for k in range(L - 1))
    fields = starts + ends
    distinct = len(set(fields))
    constant = len(set(fields)) == 1
    name = os.path.basename(bundle)
    dom = run["transcript_domain"]
    rows.append(dict(bundle=name, L=L, profile=run["profile"], dom=dom,
                     chain=chain, fields=2 * L, distinct=distinct,
                     expect=L + 1, constant=constant,
                     first=starts[0], last=ends[-1]))
    by_profile.setdefault((run["profile"], L), []).append((name, starts, ends))

w = max(len(r["bundle"]) for r in rows)
print("=== F-1a/b/c: the position-tag chain, per bundle ===")
print(f"{'bundle':<{w}}  L  fields distinct  L+1  chain  non-constant")
for r in rows:
    print(f"{r['bundle']:<{w}} {r['L']:>2} {r['fields']:>7} {r['distinct']:>8} {r['expect']:>4}  "
          f"{'OK' if r['chain'] else 'FAIL':<5}  {'OK' if not r['constant'] else 'FAIL'}")

fails = [r["bundle"] for r in rows if not r["chain"] or r["distinct"] != r["expect"] or r["constant"]]
print()
print("F-1 verdict:", "CONFIRMED on %d bundles" % len(rows) if not fails else "FAILED on %s" % fails)

print()
print("=== F-1d: is the FIRST tag a function of the PUBLIC prefix only? ===")
print("(two runs of the same profile and L that differ only in the hidden input")
print(" must share start_tag(0) -- nothing hidden is absorbed before it -- and")
print(" must differ at every later tag, because roots are absorbed in between)")
for (prof, L), lst in sorted(by_profile.items()):
    if len(lst) < 2:
        continue
    base_name, base_s, base_e = lst[0]
    for name, s, e in lst[1:]:
        same0 = s[0] == base_s[0]
        later = [k for k in range(L) if s[k] != base_s[k]]
        print(f"  {prof.split('/')[-2]:<28} L={L}  {base_name} vs {name}: "
              f"start_tag(0) {'EQUAL' if same0 else 'DIFFERENT'}; "
              f"stages whose start_tag differs: {later}")

print()
print("=== L-1: transcript constructor input lengths (F-2's table) ===")
profiles = sorted({r["profile"] for r in rows})
# the block profiles the lane defines, from run.rs:52-58 and shape.rs
extra = [
    "hashline-zk-mr1/private-run-rung-g-t24-dev/1",
    "hashline-zk-mr1/private-run-rung-k4-t24-dev/1",
    "hashline-zk-mr1/private-run-m125/1",
    "hashline-zk-mr1/private-block-rung-g-t24-dev/1",
    "hashline-zk-mr1/private-block-rung-k4-t24-dev/1",
    "hashline-zk-mr1/private-block-m125/1",
    "hashline-zk-mr1/private-block-t32-poc/1",
]
seen = []
for p in sorted(set(profiles) | set(extra)):
    n = CONSTRUCTOR_PREFIX + len(p.encode())
    flag = ""
    if n == SQUEEZE_LEN:
        flag = "  <<< EQUALS THE SQUEEZE CLASS (47)"
    elif abs(n - SQUEEZE_LEN) == 1:
        flag = "  <-- one byte from 47"
    print(f"  |domain| = {len(p):>2}  constructor = {n:>2}{flag}   {p}")
    seen.append(n)
print(f"  squeeze input is always {SQUEEZE_LEN} bytes; the shortest absorb is {ABSORB_FIXED}")
print("  47 in the constructor class needs |domain| = %d" % (SQUEEZE_LEN - CONSTRUCTOR_PREFIX))
print("  any profile at 47? ", any(n == SQUEEZE_LEN for n in seen))
print("  constructor lengths that also land in the ABSORB class (>= 48):",
      sorted(n for n in set(seen) if n >= ABSORB_FIXED))
