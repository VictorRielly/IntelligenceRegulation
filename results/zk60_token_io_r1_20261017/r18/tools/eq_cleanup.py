"""Token round 18, A5_PATCH_REVIEW.md section 4.3 step 11: delete the FIXED-ENTROPY receipts (they hide nothing), the
fail control's leftovers (none expected), the activations and every owner directory, once the comparison is recorded.
Kept: the logs, guard JSONs, compare output and digests under results/.../r18/logs/eq/, the public entropy files and the
candidate binary copy (removed after the freeze).

usage: eq_cleanup.py OUT.json        (refuses unless compare.exit is 0 and digests.json exists)
"""
import json, os, shutil, sys

EQ = "/home/victor/zk60-artifacts/token-io/r18-a5-eq"
OWN = "/home/victor/zk60-owner-private/token-io/r18-a5-eq"
LE = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r18/logs/eq"
TARGETS = [EQ + "/batch", EQ + "/single", EQ + "/r16b", EQ + "/fail", OWN]


def size(p):
    n = 0
    for root, _, files in os.walk(p):
        for f in files:
            n += os.lstat(os.path.join(root, f)).st_size
    return n


def main():
    if open(LE + "/compare.exit").read().strip() != "0" or not os.path.isfile(LE + "/digests.json"):
        sys.exit("refused: the comparison is not recorded (compare.exit 0 and digests.json)")
    rec = []
    for t in TARGETS:
        assert t.startswith(EQ + "/") or t == OWN, t
        if os.path.lexists(t):
            files = sum(len(f) for _, _, f in os.walk(t))
            rec.append({"path": t, "files": files, "bytes": size(t)})
            shutil.rmtree(t)
        else:
            rec.append({"path": t, "absent": True})
    left = sorted(os.listdir(EQ))
    json.dump({"removed": rec, "left_in_eq": left, "own_exists": os.path.lexists(OWN)}, open(sys.argv[1], "w"), indent=1)
    print(json.dumps({"removed": rec, "left_in_eq": left}))


if __name__ == "__main__":
    main()
