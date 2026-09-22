#!/usr/bin/env python3
"""Round 9d, task T2: the delivered bundle's own source pins, checked twice.

    python3 results/zk60_native_d22_replay_20260922/pins_check.py > pins_check.txt

Read-only.  Two independent questions, neither of which trusts the other:

  A. Is the tree the bundle was made from the tree `4751b93` names?
     Every entry of `capture-validation.json[source_hashes]` is compared with
     the SHA-256 of the blob `git show 4751b93:<path>` returns from the main
     repository.  A single mismatch would mean the bundle was produced from a
     tree that is not the one D22 covers, and the bundle would not be evidence
     for D22 whatever the gate then said about it.

  B. Is every file the D22 pin set names at a digest the toy gate ACCEPTS?
     The pin set is the union of
     `zk60_native_mask_commit.SOURCE_PINS + PATH_PINS` (30 files; 29 of them
     on the block profile's path, the thirtieth being the private-attention
     argument the other two captures reach) and
     `zk60_native_terminal_polys.SOURCE_PINS` (8, six of them already in the
     first set).  For each, three comparisons: the pin of record, the
     `ALSO_ACCEPTED` second digest if there is one, and the bundle's own
     `source_hashes` entry.
"""
import hashlib
import json
import os
import subprocess
import sys

MAIN = "/home/victor/IntelligenceRegulation"
HERE = os.path.dirname(os.path.abspath(__file__))
LANE = os.path.dirname(os.path.dirname(HERE))
BUNDLE_DIR = os.path.join(MAIN, "results/zk60_security_probe_repin_20260922")
COMMIT = "4751b93"

sys.path.insert(0, os.path.join(LANE, "scripts"))
import zk60_native_mask_commit as mc  # noqa: E402
import zk60_native_terminal_polys as tp  # noqa: E402


def blob_sha(path):
    """SHA-256 of the file's committed bytes at COMMIT, from the main repo."""
    try:
        data = subprocess.check_output(
            ["git", "--no-pager", "-C", MAIN, "show", f"{COMMIT}:{path}"],
            stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return None
    return hashlib.sha256(data).hexdigest()


def main():
    man = json.load(open(os.path.join(BUNDLE_DIR, "capture-validation.json")))
    src = man["source_hashes"]
    full = subprocess.check_output(
        ["git", "--no-pager", "-C", MAIN, "rev-parse", COMMIT], text=True).strip()

    print("== 0. the commit ==")
    print(f"rev-parse {COMMIT} = {full}")
    print(f"capture-validation.json[source_commit] = {man['source_commit']}")
    print(f"agree: {full == man['source_commit']}")
    cap = json.load(open(os.path.join(
        BUNDLE_DIR, "captures",
        "10b9d4be3c0af4a44c21789a30fddd716e0d8c63948e4056c6154d3d852ce64b.json")))
    print(f"bundle[source_commit]                  = {cap['source_commit']}")
    print(f"agree: {full == cap['source_commit']}")

    print()
    print("== A. every source hash the bundle records, against the blobs at "
          f"{COMMIT} ==")
    bad = []
    for path in sorted(src):
        want = src[path]
        got = blob_sha(path)
        if got != want:
            bad.append((path, want, got))
    print(f"files recorded by the bundle: {len(src)}")
    print(f"equal to the blob at {COMMIT}: {len(src) - len(bad)}")
    print(f"MISMATCH: {len(bad)}")
    for path, want, got in bad:
        print(f"  {path}\n    bundle {want}\n    {COMMIT}  {got}")

    print()
    print("== B. the D22 pin set, file by file ==")
    pins = {}
    for p in list(mc.SOURCE_PINS):
        pins[p.path] = ("mask_commit/SOURCE_PINS", p.sha256)
    for p in list(mc.PATH_PINS):
        pins.setdefault(p.path, ("mask_commit/PATH_PINS", p.sha256))
    for p in list(tp.SOURCE_PINS):
        if p.path in pins:
            pins[p.path] = (pins[p.path][0] + "+terminal_polys", pins[p.path][1])
            assert pins[p.path][1] == p.sha256, p.path
        else:
            pins[p.path] = ("terminal_polys", p.sha256)
    print(f"distinct pinned paths: {len(pins)} "
          f"(mask_commit {len(mc.SOURCE_PINS)} + {len(mc.PATH_PINS)}, "
          f"terminal_polys {len(tp.SOURCE_PINS)})")
    print()
    hdr = f"{'path':52} {'in bundle':9} {'verdict'}"
    print(hdr)
    print("-" * len(hdr))
    counts = {"pin of record": 0, "second accepted digest": 0,
              "NOT ACCEPTED": 0, "absent from the bundle": 0}
    rows = []
    for path in sorted(pins):
        where, pin = pins[path]
        also = mc.ALSO_ACCEPTED.get(path, {})
        got = src.get(path)
        blob = blob_sha(path)
        if got is None:
            verdict = "absent from the bundle"
        elif got == pin:
            verdict = "pin of record"
        elif got in also:
            verdict = "second accepted digest"
        else:
            verdict = "NOT ACCEPTED"
        counts[verdict] += 1
        agree = "yes" if got == blob else ("n/a" if got is None else "NO")
        rows.append((path, where, pin, got, blob, verdict, agree))
        print(f"{path:52} {agree:9} {verdict}")
    print()
    for k, v in counts.items():
        print(f"{k}: {v}")

    print()
    print("== B.1 the files whose digest is the SECOND accepted one ==")
    for path, where, pin, got, blob, verdict, agree in rows:
        if verdict == "second accepted digest":
            why = mc.ALSO_ACCEPTED[path][got][1]
            print(f"{path}\n  pin of record {pin}\n  bundle        {got}\n"
                  f"  why accepted: {why[:200]}")

    print()
    print("== C. artifacts and the binary ==")
    for rel, rec in sorted(man["artifacts"].items()):
        p = os.path.join(BUNDLE_DIR, rel)
        h = hashlib.sha256(open(p, "rb").read()).hexdigest()
        n = os.path.getsize(p)
        print(f"{rel}\n  manifest {rec['sha256']} {rec['bytes']} B\n"
              f"  on disk  {h} {n} B  -> {'equal' if (h, n) == (rec['sha256'], rec['bytes']) else 'DIFFERS'}")
    bpath = man["verifier_test_binary"]
    print(f"verifier binary {bpath}")
    if os.path.exists(bpath):
        h = hashlib.sha256(open(bpath, "rb").read()).hexdigest()
        print(f"  manifest {man['verifier_sha256']}\n  on disk  {h}"
              f"  -> {'equal' if h == man['verifier_sha256'] else 'DIFFERS'}")
    else:
        print("  not on disk now (the run is what it is; recorded, not re-checked)")

    return 1 if (bad or counts["NOT ACCEPTED"] or counts["absent from the bundle"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
