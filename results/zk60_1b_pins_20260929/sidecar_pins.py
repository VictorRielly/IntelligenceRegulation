#!/usr/bin/env python3
"""Check the checkpoint's small side files against the pinned revision.

For every local file other than model.safetensors (verified by main) and the
fetch log/marker, compare its git blob SHA-1 (and LFS SHA-256 where the
provider lists one) with provider_metadata.json at rev fe8a4ea1.
Output: sidecar_pins.json. Exit 0 only if every listed file matches.
"""
import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
CKPT = Path("/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1")
META = json.loads((REPO / "results/zk60_1b_checkpoint_20260927/provider_metadata.json").read_text())
SKIP = {"model.safetensors", "fetch.log", "fetch.done"}


def main():
    sib = {s["rfilename"]: s for s in META["siblings"]}
    rows, ok = [], True
    for path in sorted(CKPT.iterdir()):
        if path.name in SKIP:
            continue
        data = path.read_bytes()
        pin = sib.get(path.name)
        row = {"file": path.name, "bytes": len(data),
               "sha256": hashlib.sha256(data).hexdigest(),
               "git_blob_sha1": hashlib.sha1(b"blob %d\x00" % len(data) + data).hexdigest()}
        if pin is None:
            row["match"] = False
            row["note"] = "not listed at the pinned revision"
        elif "lfs" in pin:
            row["pinned_lfs_sha256"] = pin["lfs"]["sha256"]
            row["match"] = row["sha256"] == pin["lfs"]["sha256"] and len(data) == pin["lfs"]["size"]
        else:
            row["pinned_blob_sha1"] = pin["blobId"]
            row["match"] = row["git_blob_sha1"] == pin["blobId"] and len(data) == pin["size"]
        ok &= row["match"]
        rows.append(row)
    out = {"revision": META["sha"], "files": rows, "all_match": ok}
    (HERE / "sidecar_pins.json").write_text(json.dumps(out, indent=2) + "\n")
    print(json.dumps(out, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
