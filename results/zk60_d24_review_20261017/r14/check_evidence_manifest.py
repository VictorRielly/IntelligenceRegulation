"""Re-hash the small (<= 1 MiB) files of the author's immutable EVIDENCE.json.

Larger entries (frames, arrays, receipts) are listed by count and size only;
the reviewer does not read bulk data. Also re-checks the packet tree hash.
"""
import hashlib
import json
import os
import sys

ROOT = "/home/victor/IntelligenceRegulation"
PACKET = ROOT + "/results/zk60_1b_native_20261017/r14/review-author-1"
ev = json.load(open(PACKET + "/EVIDENCE.json"))
small_ok, small_bad, missing, big = 0, [], [], []
for rel, meta in ev.items():
    path = os.path.join(ROOT, rel)
    if not os.path.exists(path):
        missing.append(rel)
        continue
    if meta["bytes"] > 1 << 20:
        big.append((rel, meta["bytes"], os.path.getsize(path) == meta["bytes"]))
        continue
    data = open(path, "rb").read()
    if len(data) == meta["bytes"] and hashlib.sha256(data).hexdigest() == meta["sha256"]:
        small_ok += 1
    else:
        small_bad.append(rel)
manifest_sha = hashlib.sha256(open(PACKET + "/EVIDENCE.json", "rb").read()).hexdigest()
freeze = json.load(open(PACKET + "/AUTHOR_FREEZE.json"))
used = ["final-relations-1/ACCEPTANCE.json", "final-relations-1/dd-dictionary-counts.log",
        "final-relations-1/dd-dictionary-alias-counts.log", "final-arithmetic-2/ACCEPTANCE.json",
        "joint-receipts-2/ACCEPTANCE.json", "joint-envelopes-1/ACCEPTANCE.json",
        "full26-native-1/ACCEPTANCE.json", "full26-native-1/non-dd-prove.log", "full26-native-1/dd-prove.log",
        "final-validation-1/suite.log", "final-census-1/ACCEPTANCE.json", "FULL26_ACTUAL_CONDITIONAL_COUNT.json",
        "LEGACY_COMPATIBILITY_ACCEPTANCE.json", "sol-r14-legacy-full-suite-3.log"]
prefix = "results/zk60_1b_native_20261017/r14/"
out = {"entries": len(ev), "small_rehashed_ok": small_ok, "small_bad": small_bad, "missing": missing,
       "big_entries": len(big), "big_bytes": sum(b for _, b, _ in big), "big_sizes_match": all(m for _, _, m in big),
       "evidence_manifest_sha256": manifest_sha,
       "manifest_matches_freeze": manifest_sha == freeze["evidence_manifest_sha256"],
       "reviewer_used_files_in_manifest": {u: (prefix + u) in ev for u in used}}
json.dump(out, open(sys.argv[1], "w"), indent=1)
print(json.dumps(out, indent=1))
