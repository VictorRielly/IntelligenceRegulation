#!/usr/bin/env python3
"""[gate round 23, re-review note N-1] S3 (Fact 2.1, five regimes, the frozen nl_check through the frozen v23
`zk60_native_rg_tokennl.s3_pairs`) at EVERY distinct (N, d) of all 23 block slots and the 12 classifier slots of the
REAL hate capture, read from its stage files' slot records only (no store, no tables, no checkpoint): the five pairs
only the legacy block slots use at the real shape are among them.  NOT a privacy result."""
import json, os, sys, time
sys.dont_write_bytecode = True
sys.path.insert(0, "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v23/scripts")
import zk60_native_rg_tokennl as TN  # noqa: E402
cap, out = sys.argv[1], sys.argv[2]
NL, NF = TN.load_nl()
run = json.load(open(os.path.join(cap, "run.json")))
n_st = run["stages"]
pairs_by = {"classifier": set(), "block_all_23": set()}
slot_pairs = {}
for k in range(n_st):
    s = json.load(open(os.path.join(cap, f"stage-{k:02d}.json")))
    for a in s["arguments"]:
        p = (a["main"] + a["extension"], a["degree"])
        if s["stage_kind"] in ("IN-C", "OUT-C"):
            pairs_by["classifier"].add(p)
        else:
            pairs_by["block_all_23"].add(p)
            slot_pairs.setdefault(a["slot"], set()).add(p)
t0 = time.time()
allp = sorted(pairs_by["classifier"] | pairs_by["block_all_23"])
s3 = TN.s3_pairs(NL, NF, allp)
named = [(8, 3), (12, 3), (15, 2), (20, 2), (20, 3)]
rec = {"what": __doc__.strip().splitlines()[0], "capture": os.path.basename(cap), "privacy_acceptance": False,
       "pairs_classifier": sorted(pairs_by["classifier"]), "pairs_block_all_23": sorted(pairs_by["block_all_23"]),
       "per_block_slot_pairs_equal_across_26_blocks": all(len(v) == 1 for v in slot_pairs.values()),
       "review_named_legacy_pairs_present": {str(p): p in pairs_by["block_all_23"] for p in named},
       "S3_fact21": s3, "seconds": round(time.time() - t0, 1)}
rec["ok"] = s3["tight"] == s3["checks"]
rec["status"] = "PASS" if rec["ok"] else "NOT-OK"
open(out, "w").write(json.dumps(rec, indent=1, default=str) + "\n")
print(json.dumps({k: rec[k] for k in ("status", "pairs_block_all_23", "review_named_legacy_pairs_present", "per_block_slot_pairs_equal_across_26_blocks", "seconds")}), s3["tight"], s3["checks"])
