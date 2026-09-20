#!/usr/bin/env python3
"""A field-level diff of two RUN-gate records, so that "nothing about the old
bundles changed" is a computed statement and not a claim.

    python3 scripts/zk60_native_rg_recdiff.py OLD.json NEW.json [--out D.json]

It walks both records as trees and lists every leaf whose path exists in only
one of them, or whose value differs.  The caller reads the list; this tool
grades nothing.
"""

from __future__ import annotations

import argparse
import json


def _walk(node, path, out):
    if isinstance(node, dict):
        for kk in node:
            _walk(node[kk], path + [str(kk)], out)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            _walk(v, path + [f"[{i}]"], out)
    else:
        out["/".join(path)] = node


def diff(a: dict, b: dict) -> dict:
    fa, fb = {}, {}
    _walk(a, [], fa)
    _walk(b, [], fb)
    only_a = sorted(set(fa) - set(fb))
    only_b = sorted(set(fb) - set(fa))
    changed = sorted(p for p in set(fa) & set(fb) if fa[p] != fb[p])
    return {
        "leaves_old": len(fa),
        "leaves_new": len(fb),
        "only_in_the_old_record": only_a,
        "only_in_the_new_record": only_b,
        "changed": [
            {"path": p, "old": fa[p], "new": fb[p]}
            for p in changed
        ],
        "identical_leaves": len(set(fa) & set(fb)) - len(changed),
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("--out")
    args = ap.parse_args(argv)
    with open(args.old) as fh:
        a = json.load(fh)
    with open(args.new) as fh:
        b = json.load(fh)
    d = diff(a, b)
    text = json.dumps(d, indent=1, sort_keys=True)
    if args.out:
        with open(args.out, "w") as fh:
            fh.write(text + "\n")
    print(f"identical leaves: {d['identical_leaves']}")
    print(f"only in the old record: {len(d['only_in_the_old_record'])}")
    print(f"only in the new record: {len(d['only_in_the_new_record'])}")
    print(f"changed: {len(d['changed'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
