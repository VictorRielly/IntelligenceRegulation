"""D22 condition-7 pre-read of the integrator's shaped snapshot: the pin table.

Read-only.  Reads the pin tables OUT OF the joint-view worktree's four pin
modules (imported with bytecode writing switched off, so nothing is written
there), hashes every pinned path in the extracted snapshot, and compares with
the pin of record, every second accepted digest, and the blobs `git show`
returns at main `4751b93`, lane base `fee1a8d`, stage-36 tip `29cba9a` and the
lane tip.  Also re-verifies the archive and all 179 snapshot hashes.

    python3 results/zk60_d22_preread_snapshot/pins.py [--snapshot DIR]

Writes nothing; prints the tables (kept as pin_table.txt).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys

sys.dont_write_bytecode = True  # the joint-view worktree is READ-ONLY
JV = "/home/victor/wt-zk60-jointview/scripts"
sys.path.insert(0, JV)
import zk60_native_mask_commit as mc  # noqa: E402
import zk60_native_terminal_polys as tp  # noqa: E402
import zk60_native_manifest_pins as mp  # noqa: E402
import zk60_native_profile_pins as pp  # noqa: E402

REPO = "/home/victor/IntelligenceRegulation"
INTEG = os.path.join(REPO, "results/zk60_shaped_integration_20260922")
ARCHIVE_SHA = "c794360a09de1770104d8e40ce043344b25c21498cfe37ed661575a8ac06626a"
REVS = [("main 4751b93", "4751b93"), ("lane fee1a8d", "fee1a8d"),
        ("s36 29cba9a", "29cba9a"), ("lane tip", "zk60-private-block-125m")]


def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def git_blob(rev: str, path: str):
    r = subprocess.run(["git", "--no-pager", "show", f"{rev}:{path}"],
                       cwd=REPO, capture_output=True)
    return r.stdout if r.returncode == 0 else None


def pin_set():
    """path -> {'pin': sha, 'also': {sha: why}, 'tables': [names]}"""
    out = {}

    def add(table, pins, also):
        for p in pins:
            e = out.setdefault(p.path, {"pin": p.sha256, "also": {}, "tables": []})
            if e["pin"] != p.sha256:
                raise SystemExit(f"two tables disagree on {p.path}")
            e["tables"].append(table)
            for d, v in also.get(p.path, {}).items():
                e["also"][d] = v[1] if isinstance(v, tuple) else str(v)

    add("mask_commit.SOURCE_PINS", mc.SOURCE_PINS, mc.ALSO_ACCEPTED)
    add("mask_commit.PATH_PINS", mc.PATH_PINS, mc.ALSO_ACCEPTED)
    add("terminal_polys.SOURCE_PINS", tp.SOURCE_PINS, {})
    add("manifest_pins.MANIFEST_PINS", mp.MANIFEST_PINS, mp.ALSO_ACCEPTED)
    add("profile_pins.PROFILE_PINS", pp.PROFILE_PINS, pp.ALSO_ACCEPTED)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="/tmp/claude-1000/d22-snapshot")
    a = ap.parse_args()
    snap = a.snapshot

    print("== archive ==")
    got = sha(open(os.path.join(INTEG, "reviewed-source.tar.gz"), "rb").read())
    print(f"reviewed-source.tar.gz sha256 {got} expected {ARCHIVE_SHA} "
          f"{'EQUAL' if got == ARCHIVE_SHA else 'MISMATCH'}")
    rs = json.load(open(os.path.join(INTEG, "review-snapshot.json")))
    exp = rs["source_hashes"]
    found = {}
    for dp, _, fn in os.walk(snap):
        for f in fn:
            p = os.path.join(dp, f)
            found[os.path.relpath(p, snap)] = sha(open(p, "rb").read())
    mism = sorted(k for k in exp if found.get(k) != exp[k])
    extra = sorted(set(found) - set(exp))
    print(f"review-snapshot.json: {len(exp)} entries; extracted files "
          f"{len(found)}; mismatched-or-missing {len(mism)} {mism}; extra "
          f"{len(extra)} {extra}")

    pins = pin_set()
    print(f"\n== pin set: {len(pins)} distinct paths "
          f"({sum(1 for p in pins if p.endswith('.rs'))} Rust, "
          f"{sum(1 for p in pins if p.endswith('Cargo.toml'))} manifests) ==")
    # also the recorded-not-accepted expectations of the manifests
    exp_after = {k: v["sha256"] for k, v in mp.EXPECTED_AFTER_INTEGRATION.items()
                 if isinstance(v, dict)}

    rows = []
    for path in sorted(pins):
        e = pins[path]
        raw = open(os.path.join(snap, path), "rb").read() if os.path.exists(
            os.path.join(snap, path)) else None
        s = sha(raw) if raw is not None else None
        revd = {}
        for name, rev in REVS:
            b = git_blob(rev, path)
            revd[name] = sha(b) if b is not None else None
        if s == e["pin"]:
            verdict = "EQUAL (pin of record)"
        elif s in e["also"]:
            verdict = "EQUAL (second accepted)"
        elif s is None:
            verdict = "ABSENT"
        else:
            verdict = "MOVED"
        same = [n for n, _ in REVS if revd[n] == s]
        rows.append((path, e, s, verdict, same, revd))

    w = max(len(r[0]) for r in rows)
    print(f"{'path':<{w}}  {'pin of record':<16} {'2nd accepted':<16} "
          f"{'snapshot':<16} verdict                    snapshot bytes equal to")
    for path, e, s, verdict, same, revd in rows:
        also = ",".join(d[:16] for d in e["also"]) or "-"
        print(f"{path:<{w}}  {e['pin'][:16]} {also:<16} {str(s)[:16]} "
              f"{verdict:<26} {', '.join(same) or 'none of the four'}")
    n_eq = sum(1 for r in rows if r[3].startswith("EQUAL"))
    n_mv = sum(1 for r in rows if r[3] == "MOVED")
    print(f"\nequal {n_eq} / moved {n_mv} / absent "
          f"{sum(1 for r in rows if r[3] == 'ABSENT')}")

    print("\n== moved pins, full digests ==")
    for path, e, s, verdict, same, revd in rows:
        if verdict != "MOVED":
            continue
        print(f"{path}")
        print(f"  pin of record   {e['pin']}")
        for d in e["also"]:
            print(f"  2nd accepted    {d}")
        print(f"  snapshot        {s}")
        for n, _ in REVS:
            print(f"  {n:<15} {revd[n]}")
        if path in exp_after:
            print(f"  EXPECTED_AFTER_INTEGRATION (recorded, not accepted) "
                  f"{exp_after[path]}  "
                  f"{'= snapshot' if exp_after[path] == s else '!= snapshot'}")
        print(f"  tables          {', '.join(e['tables'])}")

    print("\n== every snapshot file vs main 4751b93 and lane fee1a8d ==")
    cls = {}
    for rel in sorted(exp):
        m = git_blob("4751b93", rel)
        l = git_blob("fee1a8d", rel)
        mm = sha(m) if m is not None else None
        ll = sha(l) if l is not None else None
        s = exp[rel]
        if s == mm and s == ll:
            k = "equal both"
        elif s == mm:
            k = "= main only"
        elif s == ll:
            k = "= lane only"
        elif mm is None and ll is None:
            k = "NEW (in neither)"
        else:
            k = "NEITHER (new blob)"
        cls.setdefault(k, []).append(rel + (" [PINNED]" if rel in pins else ""))
    for k in sorted(cls):
        print(f"-- {k}: {len(cls[k])}")
        if k != "equal both":
            for f in cls[k]:
                print(f"   {f}")


if __name__ == "__main__":
    main()
