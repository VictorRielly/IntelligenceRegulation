#!/usr/bin/env python3
"""G-7 sub-lane: the gate-owned copy of the native lane's frozen R5b tree.

    python3 tree_tools.py verify            -> copy_verify_g7.json
    python3 tree_tools.py record <tag>      -> trained-1b-gate-g7-vs-frozen-r5b.<tag>.patch
                                               trained-1b-gate-g7.sources.<tag>.sha256

`verify` checks every file of the copy against R5b's manifest
(`r5b/manifest_frozen.json`, 218 files): digest mismatches, files missing,
files present but unlisted (target dirs excluded). `record` writes the patch
of the copy against the frozen tree and a sources manifest; it never
overwrites an existing file. Nothing here is a privacy result.
"""
import hashlib
import json
import os
import subprocess
import sys

E = os.path.dirname(os.path.abspath(__file__))
FROZEN = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5b/frozen-tree"
MANIFEST = "/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r5b/manifest_frozen.json"
COPY = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-g7"


def walk(root):
    out = {}
    for dp, dn, fn in os.walk(root):
        dn[:] = sorted(x for x in dn if not x.startswith("target"))
        for n in sorted(fn):
            f = os.path.join(dp, n)
            out[os.path.relpath(f, root)] = hashlib.sha256(open(f, "rb").read()).hexdigest()
    return out


def verify():
    m = json.load(open(MANIFEST))
    listed = m["files"]
    have = walk(COPY)
    mism = sorted(p for p, d in listed.items() if p in have and have[p] != d)
    missing = sorted(p for p in listed if p not in have)
    unlisted = sorted(p for p in have if p not in listed)
    rec = {
        "manifest": MANIFEST,
        "manifest_sha256": hashlib.sha256(open(MANIFEST, "rb").read()).hexdigest(),
        "tree_sha256_declared": m.get("tree_sha256"),
        "root": COPY,
        "listed": len(listed),
        "count_declared": m.get("count"),
        "equal": len(listed) - len(mism) - len(missing),
        "digest_mismatch": mism,
        "missing": missing,
        "unlisted": unlisted,
        "ok": not (mism or missing or unlisted),
    }
    out = os.path.join(E, "copy_verify_g7.json")
    if os.path.exists(out):
        out = os.path.join(E, "copy_verify_g7.again.json")
    json.dump(rec, open(out, "w"), indent=1)
    print(json.dumps({k: v for k, v in rec.items()}, indent=1))
    return 0 if rec["ok"] else 1


def record(tag):
    pp = os.path.join(E, f"trained-1b-gate-g7-vs-frozen-r5b.{tag}.patch")
    mp = os.path.join(E, f"trained-1b-gate-g7.sources.{tag}.sha256")
    for f in (pp, mp):
        if os.path.exists(f):
            raise SystemExit(f"{f} exists")
    p = subprocess.run(["diff", "-ruN", "--exclude=target", FROZEN, COPY], capture_output=True)
    open(pp, "wb").write(p.stdout)
    have = walk(COPY)
    open(mp, "w").write("".join(f"{d}  {r}\n" for r, d in sorted(have.items())))
    files = [l.split()[-1] for l in p.stdout.decode().splitlines() if l.startswith("diff ")]
    print(f"patch {len(p.stdout)} B sha256 {hashlib.sha256(p.stdout).hexdigest()}; files changed {len(files)}")
    print(f"sources {len(have)} files sha256 {hashlib.sha256(open(mp, 'rb').read()).hexdigest()}")
    for f in files:
        print("  ", os.path.relpath(f, COPY))
    return 0


if __name__ == "__main__":
    if sys.argv[1:2] == ["verify"]:
        sys.exit(verify())
    if sys.argv[1:2] == ["record"] and len(sys.argv) == 3:
        sys.exit(record(sys.argv[2]))
    raise SystemExit(__doc__)
