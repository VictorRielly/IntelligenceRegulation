#!/usr/bin/env python3
"""Stage 32's bundle self-check: what a gate sees in the two rung-W14 bundles.

Reads the bundles OFF DISK (they live outside the repository, at about 130 MB
each) and prints, with no reference to the Rust that wrote them:

 1. the manifests -- every file's length and SHA-256, and the source pin;
 2. what is NEW: the 2^14 row width in the commitments a reader sees first;
 3. what is the SAME as the older bundles: correction C-6's Dom::D counts and
    stage 30's unpadded arm, so the pair is a regression for both;
 4. the two stages of each bundle agree on the schedule;
 5. the declarations a gate reads first;
 6. every slot, rung-W14 against rung-C6 (stage 0).

Usage: python3 v32_bundle_check.py <w14-dense> <w14-zero> <c6-dense>
"""
import hashlib
import json
import os
import sys

SLOTS = 23


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def check_manifest(d):
    m = json.load(open(os.path.join(d, "manifest.json")))
    bad = []
    for f in m["files"]:
        p = os.path.join(d, f["file"])
        n = os.path.getsize(p)
        if n != f["bytes"]:
            bad.append(f"{f['file']}: {n} B on disk against {f['bytes']} recorded")
        elif sha256(p) != f["sha256"]:
            bad.append(f"{f['file']}: SHA-256 differs")
    on_disk = sum(os.path.getsize(os.path.join(d, x)) for x in os.listdir(d))
    return m, bad, on_disk


def stage(d, k):
    return json.load(open(os.path.join(d, f"stage-{k:02d}.json")))


def sched(a):
    return (a["main"], a["extension"], a["degree"], len(a["definition_challenges"]), len(a["terminals"]))


def main():
    dense, zero, c6 = sys.argv[1], sys.argv[2], sys.argv[3]
    w = 78
    print("=" * w)
    print("STAGE 32 BUNDLE SELF-CHECK - the two rung-W14 bundles")
    print("=" * w)
    print("\n-- 1. the manifests --")
    for d in (dense, zero):
        m, bad, on_disk = check_manifest(d)
        tag = os.path.basename(d)
        print(f"  {tag}: source pin {m['source_commit']}, {len(m['source_pins'])} source files pinned, "
              f"{len(m['files'])} bundle files {'all matching their length and SHA-256' if not bad else 'WITH ' + str(len(bad)) + ' MISMATCHES'}; "
              f"{on_disk} B on disk ({on_disk / 1e6:.1f} MB), manifest total_bytes {m['total_bytes']}")
        for b in bad:
            print(f"    XX {b}")

    print("\n-- 2. what is NEW: the 125M row width in the commitments --")
    for d, name in ((dense, "rung-W14"), (c6, "rung-C6")):
        s = stage(d, 0)
        print(f"  {name}: log_cols {s['log_cols']} (message 2^{s['log_cols']}, encoded 2^{s['log_cols'] + 2}), "
              f"A {s['a_rows']} rows, H {s['h_rows']} rows")

    print("\n-- 3. what is the SAME: C-6's Dom::D counts and stage 30's unpadded arm --")
    sw, sc = stage(dense, 0), stage(c6, 0)
    for k in (14, 15, 16, 18, 2):
        aw, ac = sw["arguments"][k], sc["arguments"][k]
        print(f"  slot {k:02d} [{aw['name']}]: rung-W14 deg {aw['degree']}, {len(aw['definition_challenges'])} draws, "
              f"{len(aw['terminals'])} terminals | rung-C6 deg {ac['degree']}, {len(ac['definition_challenges'])} draws, "
              f"{len(ac['terminals'])} terminals")

    print("\n-- 4. the two stages of each bundle agree on the schedule --")
    for d in (dense, zero):
        a, b = stage(d, 0), stage(d, 1)
        same = all(sched(a["arguments"][k]) == sched(b["arguments"][k]) for k in range(SLOTS))
        print(f"  {os.path.basename(d)}: the two stages carry the same schedule and the same draw counts on all {SLOTS} slots: {same}")

    print("\n-- 5. the declarations a gate reads first --")
    for d in (dense, zero):
        r = json.load(open(os.path.join(d, "run.json")))
        print(f"  {os.path.basename(d)}: schema {r['schema']}, run profile {r['profile']}, "
              f"keyed hash rule {r['hash_tag']['rule'] == 'blake3-keyed/1'}, public tables' values {r['public_tables_included']}, "
              f"blocks {r['blocks']}")

    print("\n-- 6. every slot, rung-W14 against rung-C6 (stage 0) --")
    diff = [k for k in range(SLOTS) if sched(sw["arguments"][k]) != sched(sc["arguments"][k])]
    print(f"  slots whose schedule, draw count or terminal count differs: {diff}")
    for k in range(SLOTS):
        a, c = sw["arguments"][k], sc["arguments"][k]
        mark = "  " if k not in diff else "* "
        print(f"  {mark}slot {k:02d} [{a['name']}]: rung-W14 {sched(a)} | rung-C6 {sched(c)}")
    print("\n  (the tuple is (main rounds, extension rounds, degree, definition challenges, terminals))")
    print("\nNo privacy claim: these bundles are the INPUT to the independent gate, never its verdict (ruling T-6).")


if __name__ == "__main__":
    main()
