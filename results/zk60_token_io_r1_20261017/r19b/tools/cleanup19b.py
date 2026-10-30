#!/usr/bin/env python3
"""Token round 19b (round 19's cleanup19.py re-rooted): delete the FIXED-ENTROPY test receipt of the bytes check, its owner directory, the activations and
the prepared request (D46: test-only receipts are deleted once the check is recorded). Kept: logs, guard JSONs,
bytes.json under results/.../r19b/logs/bytes/, the public entropy files, the candidate binary (removed after the freeze).

usage: cleanup19.py OUT.json        (refuses unless bytes/compare.exit is 0 and bytes.json exists)
"""
import json, os, shutil, sys
EQ = "/home/victor/zk60-artifacts/token-io/r19b"
OWN = "/home/victor/zk60-owner-private/token-io/r19b"
LB = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19b/logs/bytes"
TARGETS = [EQ + "/single", EQ + "/batch", OWN]
def size(p):
    return sum(os.lstat(os.path.join(r, f)).st_size for r, _, fs in os.walk(p) for f in fs)
if open(LB + "/compare.exit").read().strip() != "0" or not os.path.isfile(LB + "/bytes.json"):
    sys.exit("refused: the comparison is not recorded")
rec = []
for t in TARGETS:
    if os.path.lexists(t):
        rec.append({"path": t, "files": sum(len(f) for _, _, f in os.walk(t)), "bytes": size(t)})
        shutil.rmtree(t)
    else:
        rec.append({"path": t, "absent": True})
json.dump({"removed": rec, "left_in_eq": sorted(os.listdir(EQ))}, open(sys.argv[1], "w"), indent=1)
print(json.dumps({"removed": rec, "left_in_eq": sorted(os.listdir(EQ))}))
