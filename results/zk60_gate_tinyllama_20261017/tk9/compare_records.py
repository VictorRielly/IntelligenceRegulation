#!/usr/bin/env python3
"""[gate round 10, the frozen-r9 re-pin] Leaf-by-leaf comparison of two gate
records of the same bundle kind (same layers, same input) written from two
trees.  Reads JSON only.  Every leaf whose value differs is listed, except the
leaves that cannot be equal between two runs or two trees by construction,
which are COUNTED by class, never silently dropped:

  timing      wall-clock and memory figures (seconds, peak RSS, timings);
  identity    file paths, bundle names, tool digests, and 64-hex words
              (roots, salts, digests, the bundles' own source pins);
  random      leaves whose key is one of RANDOM_KEYS: the figures that depend
              on the run's randomness (which columns were opened, the pad
              block and margin) -- the witness comparison's classes.

A leaf missing on one side is listed as differing.

    python3 compare_records.py <out.json> <new.json> <old.json> [<new> <old> ...]
"""
import json
import re
import sys

TIMING_KEYS = {"seconds", "total_seconds", "peak_rss_mb", "timings", "wall", "elapsed",
               "peak_rss_gib", "t", "s", "time"}
IDENTITY_KEYS = {"bundle", "bundle_dir", "tool_sha256", "name", "path", "record", "evidence",
                 "other", "source_commit", "test_source_commit", "dir", "capture_dir"}
RANDOM_KEYS = {"distinct_opened_columns", "distinct_columns", "pad_margin", "pad_block",
               "distinct_opened_columns_within_pad_count", "opened_columns"}
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def walk(a, b, path, out, counts):
    key = path[-1] if path else ""
    if isinstance(key, str) and key in TIMING_KEYS:
        counts["timing"] += 1
        return
    if isinstance(key, str) and key in IDENTITY_KEYS:
        counts["identity"] += 1
        return
    if isinstance(key, str) and key in RANDOM_KEYS:
        if a != b:
            counts["random"] += 1
        return
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b), key=str):
            if k not in a or k not in b:
                out.append({"path": "/".join(map(str, path + [k])), "new": a.get(k, "<absent>") if not isinstance(a.get(k), (dict, list)) else "<object>",
                            "old": b.get(k, "<absent>") if not isinstance(b.get(k), (dict, list)) else "<object>"})
                continue
            walk(a[k], b[k], path + [k], out, counts)
        return
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            out.append({"path": "/".join(map(str, path)) + "#len", "new": len(a), "old": len(b)})
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, path + [i], out, counts)
        return
    if a == b:
        counts["equal"] += 1
        return
    if isinstance(a, str) and isinstance(b, str):
        if (HEX64.match(a) and HEX64.match(b)) or "/home/" in a or "/home/" in b:
            counts["identity"] += 1
            return
        if a.replace("tk9", "tkN") == b.replace("tk7", "tkN").replace("r7", "tkN"):
            counts["identity"] += 1
            return
    out.append({"path": "/".join(map(str, path)), "new": str(a)[:300], "old": str(b)[:300]})


def main(argv):
    res = []
    pairs = argv[1:]
    for new, old in zip(pairs[0::2], pairs[1::2]):
        a, b = json.load(open(new)), json.load(open(old))
        out, counts = [], {"equal": 0, "timing": 0, "identity": 0, "random": 0}
        walk(a, b, [], out, counts)
        res.append({"new": new, "old": old, "leaves_equal": counts["equal"],
                    "skipped_timing": counts["timing"], "skipped_identity": counts["identity"],
                    "differing_random_class": counts["random"], "differing": out,
                    "differing_count": len(out)})
        print(f"{new.split('/')[-1]} vs {old.split('/')[-1]}: equal {counts['equal']}, differing {len(out)}, "
              f"random-class differing {counts['random']}, identity {counts['identity']}, timing {counts['timing']}")
        for d in out[:40]:
            print("   ", d["path"], "| new:", str(d["new"])[:120], "| old:", str(d["old"])[:120])
    json.dump({"what": __doc__.strip().splitlines()[0], "privacy_acceptance": False, "pairs": res},
              open(argv[0], "w"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
