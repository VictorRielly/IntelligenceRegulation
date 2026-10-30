#!/usr/bin/env python3
"""[gate round 24] D46 clean-up after the round's checks are recorded:
1. record the test-only r19b P-18 capture (its manifest.json and README.md copied, every file's size and
   SHA-256 re-hashed against its manifest, the named binary) -> round24/CAPTURE_P18_R19B.json and
   round24/capture_p18_r19b/{manifest.json,README.md};
2. delete that capture (test-only: D46 "delete test-only receipts once their check is recorded");
3. delete the regenerable build output `capture-tree-r19b/hashline/target/` (the tree itself, 20.6 MB of
   sources = frozen-r19b, is kept for a re-capture);
writing what was removed (files, bytes) -> round24/CLEANUP.json.  Refuses to delete before the v24 gate's record
of the capture exists with status PASS.
"""
import hashlib
import json
import os
import shutil
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
P = E + "/round24"
CAPDIR = "/home/victor/zk60-artifacts/token-io/captures/classify-rc3-cli-p18-r19b-gate24"
TARGET = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/capture-tree-r19b/hashline/target"
GATE_REC = P + "/v24/v24-classify-rc3-cli-p18-r19b-gate24.json"


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for c in iter(lambda: fh.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def tally(d):
    n, b = 0, 0
    for root, _ds, fs in os.walk(d):
        for f in fs:
            n += 1
            b += os.lstat(os.path.join(root, f)).st_size
    return n, b


def main():
    rec = json.load(open(GATE_REC))
    if rec.get("status") != "PASS":
        raise SystemExit(f"the v24 gate record is {rec.get('status')!r}, not PASS: nothing deleted")
    man = json.load(open(os.path.join(CAPDIR, "manifest.json")))
    files = []
    for e in man["files"]:
        p = os.path.join(CAPDIR, e["file"])
        files.append({"file": e["file"], "bytes": os.path.getsize(p), "sha256": sha(p), "manifest_sha256": e["sha256"],
                      "equal": sha(p) == e["sha256"]})
    os.makedirs(P + "/capture_p18_r19b", exist_ok=True)
    for f in ("manifest.json", "README.md"):
        shutil.copy2(os.path.join(CAPDIR, f), os.path.join(P, "capture_p18_r19b", f))
    readme = open(os.path.join(CAPDIR, "README.md")).read()
    out = {"capture": CAPDIR, "schema": man["schema"], "profile": man["profile"], "blocks": man["blocks"],
           "source_commit": man["source_commit"], "source_pins": len(man["source_pins"]),
           "manifest_sha256": sha(os.path.join(CAPDIR, "manifest.json")), "readme_sha256": sha(os.path.join(CAPDIR, "README.md")),
           "files": files, "all_equal": all(x["equal"] for x in files), "total_bytes": sum(x["bytes"] for x in files),
           "readme_names_r19b_binary": "zk60_classify.r19b.release.bin (sha256 6d65d32ea783e36db2458ccce2d459cb29a91bcb45a89c4e23e484914126d609)" in readme,
           "v24_gate_record": os.path.relpath(GATE_REC, E), "v24_gate_record_sha256": sha(GATE_REC), "v24_status": rec["status"],
           "copies": ["round24/capture_p18_r19b/manifest.json", "round24/capture_p18_r19b/README.md"]}
    if not out["all_equal"]:
        raise SystemExit("a capture file differs from its manifest: nothing deleted")
    with open(P + "/CAPTURE_P18_R19B.json", "w") as fh:
        json.dump(out, fh, indent=1)
    removed = []
    for d in (CAPDIR, TARGET):
        if os.path.isdir(d):
            n, b = tally(d)
            shutil.rmtree(d)
            removed.append({"path": d, "files": n, "bytes": b, "gone": not os.path.exists(d)})
    with open(P + "/CLEANUP.json", "w") as fh:
        json.dump({"removed": removed, "kept": ["ops/zkp-mvp/gate-tinyllama/capture-tree-r19b (sources only, = frozen-r19b)"]},
                  fh, indent=1)
    print(json.dumps({"recorded": P + "/CAPTURE_P18_R19B.json", "removed": removed}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
