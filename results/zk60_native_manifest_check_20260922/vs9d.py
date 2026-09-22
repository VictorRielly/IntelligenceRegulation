#!/usr/bin/env python3
"""Round 9e, S5: the fixed tool's no-shim runs against round 9d's two records.

    python3 results/zk60_native_manifest_check_20260922/vs9d.py

Round 9d had to run each gate TWICE on the integrator's bundle: once on a
staged copy carrying a `validation.json` with a one-element `accepted` list,
where the manifest check fired, and once straight at the delivered directory,
where it reported `absent` and was skipped.  The fix removes the reason for
the first run.  Two comparisons, leaf by leaf, per gate:

  * against 9d's AS-DELIVERED record (same command, same directory, old tool):
    the manifest block must change -- from `{"validation_json": "absent"}` to
    the cross-check itself -- and NOTHING else may change except `seconds` and
    the tool hashes the edit moved.
  * against 9d's STAGED record (the shimmed copy): the fixed tool must
    reproduce, WITHOUT the shim, exactly what the shim produced -- so only
    `captures_dir`, `seconds` and the tool hashes may differ, and the manifest
    block must now be identical.

Exit 0 only if every difference falls in the allowed classes.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
NINE_D = os.path.join(
    os.path.dirname(HERE), "zk60_native_d22_replay_20260922")
ALLOWED_PREFIXES = ("/seconds", "/captures_dir", "/manifest", "/tool_sha256")


def bucket_of(path):
    """`/seconds` also catches the joint-view stages' own wall clocks."""
    if path.split("/")[-1] == "seconds":
        return "/seconds"
    for pref in ALLOWED_PREFIXES:
        if path == pref or path.startswith(pref + "/"):
            return pref
    return None


def walk(a, b, path, out):
    if type(a) is not type(b):
        out.append((path, repr(a)[:120], repr(b)[:120]))
        return
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a:
                out.append((path + "/" + str(k), "<absent>", repr(b[k])[:120]))
            elif k not in b:
                out.append((path + "/" + str(k), repr(a[k])[:120], "<absent>"))
            else:
                walk(a[k], b[k], path + "/" + str(k), out)
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append((path + "/len", len(a), len(b)))
            return
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, path + "/" + str(i), out)
    elif a != b:
        out.append((path, repr(a)[:120], repr(b)[:120]))


def compare(title, old_path, new_path, expect_manifest_identical):
    print("=" * 72)
    print(title)
    print(f"  9d   : {old_path}")
    print(f"  9e   : {new_path}")
    old = json.load(open(old_path))
    new = json.load(open(new_path))
    rows = []
    walk(old, new, "", rows)
    buckets = {}
    unexpected = []
    for p, x, y in rows:
        pref = bucket_of(p)
        if pref is None:
            unexpected.append((p, x, y))
        else:
            buckets.setdefault(pref, []).append((p, x, y))
    for pref in ALLOWED_PREFIXES:
        rs = buckets.get(pref, [])
        print(f"  {pref:<14} {len(rs)} differing leaf/leaves")
        for p, x, y in rs:
            print(f"      {p}\n        9d {x}\n        9e {y}")
    print(f"  UNEXPECTED     {len(unexpected)}")
    for p, x, y in unexpected:
        print(f"      {p}\n        9d {x}\n        9e {y}")
    bad = len(unexpected)
    if expect_manifest_identical and buckets.get("/manifest"):
        print("  FAIL: the manifest block should be IDENTICAL to the staged "
              "run's and is not")
        bad += 1
    if not expect_manifest_identical and not buckets.get("/manifest"):
        print("  FAIL: the manifest block should have CHANGED and did not")
        bad += 1
    return bad


def main():
    bad = 0
    bad += compare(
        "P10 privacy gate, the delivered directory: 9d as-delivered (check "
        "skipped) vs 9e (check fires on its own)",
        os.path.join(NINE_D, "p10_as_delivered", "privacy_gate.json"),
        os.path.join(HERE, "p10_as_delivered_fixed", "privacy_gate.json"),
        expect_manifest_identical=False)
    bad += compare(
        "P10 privacy gate: 9d STAGED (the shim made the check fire) vs 9e "
        "with no shim at all",
        os.path.join(NINE_D, "p10_staged", "privacy_gate.json"),
        os.path.join(HERE, "p10_as_delivered_fixed", "privacy_gate.json"),
        expect_manifest_identical=True)
    bad += compare(
        "joint-view gate, the delivered directory: 9d as-delivered vs 9e",
        os.path.join(NINE_D, "jointview_as_delivered", "joint_view.json"),
        os.path.join(HERE, "jointview_as_delivered_fixed", "joint_view.json"),
        expect_manifest_identical=False)
    bad += compare(
        "joint-view gate: 9d STAGED vs 9e with no shim at all",
        os.path.join(NINE_D, "jointview_staged", "joint_view.json"),
        os.path.join(HERE, "jointview_as_delivered_fixed", "joint_view.json"),
        expect_manifest_identical=True)
    print("=" * 72)
    print("VERDICT:", "every difference is in an allowed class" if not bad
          else f"{bad} problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
