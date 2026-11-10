"""Fetch named files of FlashProve at the pinned commit 9e2bdd8f (the commit the project's port names) and verify
each against the git blob SHA-1 recorded in the project's own snapshot of the upstream tree
(results/zk60_astra_20261026/flashprove_comparison_20261104/upstream_tree.json, main checkout; untracked there).

Usage: python3 -I fetch_flashprove.py <out_dir> <path> [<path> ...]
Writes each file under <out_dir>/<path>, prints one line per file: OK/MISMATCH, git blob, sha256, bytes.
Nothing is executed from the downloaded files; they are data.
"""
import hashlib
import json
import os
import sys
import urllib.request

COMMIT = "9e2bdd8ff5bf9c62f18263d7dac189b0400b260c"
TREE = ("/Users/victorrielly/IntelligenceRegulation/results/zk60_astra_20261026/"
        "flashprove_comparison_20261104/upstream_tree.json")


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def main() -> int:
    out = sys.argv[1]
    paths = sys.argv[2:]
    tree = {e["path"]: e for e in json.load(open(TREE))["tree"] if e["type"] == "blob"}
    bad = 0
    for p in paths:
        if p not in tree:
            print("NOT-IN-TREE", p)
            bad += 1
            continue
        url = f"https://raw.githubusercontent.com/anthropics/FlashProve/{COMMIT}/{p}"
        req = urllib.request.Request(url, headers={"User-Agent": "lean-audit-fetch"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        gb = git_blob(data)
        ok = gb == tree[p]["sha"]
        dst = os.path.join(out, p)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as f:
            f.write(data)
        print("OK" if ok else "MISMATCH", p, gb, hashlib.sha256(data).hexdigest(), len(data))
        bad += 0 if ok else 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
