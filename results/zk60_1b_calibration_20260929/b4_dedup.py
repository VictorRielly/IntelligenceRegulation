#!/usr/bin/env python3
"""Lane B4: share byte-identical files between exports by HARD LINK
(export/FORMAT_CHANGES.md item 3). For every regular file under <target> whose
relative path also exists under <reference> with the SAME sha256, the target
file is replaced (atomically: link to a temporary name, then rename) by a hard
link to the reference file. Files that differ (rope tables, manifests,
profile.json, sequences) are left alone. Never follows or creates symlinks.
Usage: b4_dedup.py <reference export> <target export>..."""

from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for blk in iter(lambda: f.read(1 << 22), b""):
            h.update(blk)
    return h.hexdigest()


def main(ref: Path, targets: list[Path]):
    rep = {}
    for tgt in targets:
        linked, same_inode, differ, saved = 0, 0, [], 0
        for p in sorted(tgt.rglob("*")):
            if p.is_symlink():
                raise SystemExit(f"symlink found: {p}")
            if not p.is_file():
                continue
            rel = p.relative_to(tgt)
            q = ref / rel
            if not q.is_file() or q.is_symlink():
                continue
            if os.stat(p).st_ino == os.stat(q).st_ino:
                same_inode += 1
                continue
            if p.stat().st_size != q.stat().st_size or sha(p) != sha(q):
                differ.append(str(rel))
                continue
            tmp = p.with_name(p.name + ".linktmp")
            os.link(q, tmp)
            os.replace(tmp, p)
            assert os.stat(p).st_ino == os.stat(q).st_ino
            linked += 1
            saved += q.stat().st_size
        rep[str(tgt)] = {"linked_now": linked, "already_linked": same_inode, "bytes_saved_now": saved,
                         "differing_files": len(differ), "differing_examples": differ[:12]}
    print(json.dumps(rep, indent=1))


if __name__ == "__main__":
    main(Path(sys.argv[1]), [Path(a) for a in sys.argv[2:]])
