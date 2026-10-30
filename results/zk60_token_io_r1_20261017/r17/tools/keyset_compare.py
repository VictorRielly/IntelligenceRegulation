#!/usr/bin/env python3
"""Token round 17: the JSON key sets of two capture bundles (run.json, stage-NN.json, manifest.json, every depth).
usage: keyset_compare.py NEW_BUNDLE OLD_BUNDLE OUT_JSON — prints the keys NEW has that OLD has not (must be none)."""
import json, os, sys


def keys(o, out):
    if isinstance(o, dict):
        for k, v in o.items():
            out.add(k)
            keys(v, out)
    elif isinstance(o, list):
        for v in o:
            keys(v, out)
    return out


def bundle_keys(d):
    out = {}
    for n in sorted(os.listdir(d)):
        if n.endswith(".json"):
            kind = "stage" if n.startswith("stage-") else n
            out.setdefault(kind, set())
            keys(json.load(open(os.path.join(d, n))), out[kind])
    return out


new, old = bundle_keys(sys.argv[1]), bundle_keys(sys.argv[2])
rec = {"new": sys.argv[1], "old": sys.argv[2], "per_file_kind": {}}
extra_total = 0
for kind in sorted(set(new) | set(old)):
    a, b = new.get(kind, set()), old.get(kind, set())
    rec["per_file_kind"][kind] = {"keys_new": len(a), "keys_old": len(b), "only_in_new": sorted(a - b), "only_in_old": sorted(b - a)}
    extra_total += len(a - b)
rec["keys_only_in_new"] = extra_total
json.dump(rec, open(sys.argv[3], "w"), indent=1, sort_keys=True)
print(json.dumps(rec, indent=1, sort_keys=True))
