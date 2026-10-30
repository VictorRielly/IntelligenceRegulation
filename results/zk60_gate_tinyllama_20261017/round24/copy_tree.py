#!/usr/bin/env python3
"""[gate round 24] Make the gate's capture tree `ops/zkp-mvp/gate-tinyllama/capture-tree-r19b/` = token
frozen-r19b byte for byte (306 files; the frozen tree has no `target/`, and none is copied: D46), then
re-hash it against `manifest_final_r19b.sha256` (306 / 0 / 0 expected, no unlisted file).  Refuses to
overwrite an existing tree.  No gate patch: frozen-r19b carries the adopted H19 hooks and the P-18 hook.

    python3 copy_tree.py   -> round24/COPY_TREE.json
"""
import hashlib
import json
import os
import shutil
import sys

TOK = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
SRC = TOK + "/frozen-r19b"
DST = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/capture-tree-r19b"
MAN = TOK + "/manifest_final_r19b.sha256"
OUT = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round24/COPY_TREE.json"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for c in iter(lambda: fh.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def main():
    if os.path.exists(DST):
        raise SystemExit(f"{DST} exists; not overwritten")
    shutil.copytree(SRC, DST, ignore=shutil.ignore_patterns("target"), symlinks=True)
    listed = {}
    for ln in open(MAN):
        h, p = ln.rstrip("\n").split("  ", 1)
        listed[p] = h
    moved = [p for p, h in listed.items() if not os.path.isfile(os.path.join(DST, p)) or sha(os.path.join(DST, p)) != h]
    on_disk = set()
    for d, _ds, fs in os.walk(DST):
        for f in fs:
            on_disk.add(os.path.relpath(os.path.join(d, f), DST))
    extra = sorted(on_disk - set(listed))
    rec = {"src": SRC, "dst": DST, "manifest": MAN, "manifest_list_sha256": sha(MAN), "listed": len(listed),
           "moved_or_missing": moved, "unlisted": extra, "ok": not moved and not extra,
           "bytes": sum(os.path.getsize(os.path.join(DST, p)) for p in on_disk)}
    with open(OUT, "w") as fh:
        json.dump(rec, fh, indent=1)
    print(json.dumps({k: rec[k] for k in ("listed", "moved_or_missing", "unlisted", "ok", "bytes")}))
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
