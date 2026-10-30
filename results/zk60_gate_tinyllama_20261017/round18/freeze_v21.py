#!/usr/bin/env python3
"""[gate round 18] Freeze tools v21: staging_v21 -> frozen_v21 (scripts,
tests, counts, original; no __pycache__), the manifest in the v1-v20 layout
(`v4/freeze.py`'s file list), the check, and the three patches
(v20 -> v21 scripts / tests, vs original).  Refuses to overwrite anything.

    python3 freeze_v21.py
"""
import hashlib
import os
import shutil
import subprocess
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
GATE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama"
sys.path.insert(0, E + "/v4")
import freeze as F  # noqa: E402

STAGING, FROZEN = GATE + "/staging_v21", GATE + "/frozen_v21"
MAN = E + "/gate-tinyllama.tools.frozen.v21.sha256"


def sha(p):
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def main():
    for p in (FROZEN, MAN):
        if os.path.exists(p):
            raise SystemExit(f"{p} exists; a freeze is never overwritten")
    shutil.copytree(STAGING, FROZEN, ignore=shutil.ignore_patterns("__pycache__"))
    files = F.files(FROZEN)
    with open(MAN, "w") as fh:
        for p in files:
            fh.write(f"{sha(os.path.join(FROZEN, p))}  {p}\n")
    print(f"{len(files)} files -> {MAN}  sha256 {sha(MAN)}")
    rc = F.main(["check", MAN, FROZEN])
    if rc:
        raise SystemExit("the frozen copy does not match its manifest")
    # staging == frozen, file for file
    bad = [p for p in files if sha(os.path.join(STAGING, p)) != sha(os.path.join(FROZEN, p))]
    print("staging vs frozen differing:", bad)
    for old, new, out in (("frozen_v20/scripts", "frozen_v21/scripts", "gate-tinyllama-v20-to-v21.scripts.patch"),
                          ("frozen_v20/tests", "frozen_v21/tests", "gate-tinyllama-v20-to-v21.tests.patch"),
                          ("original", "frozen_v21/scripts", "gate-tinyllama-vs-original.v21.patch")):
        o = os.path.join(E, out)
        if os.path.exists(o):
            raise SystemExit(f"{o} exists")
        p = subprocess.run(["diff", "-ruN", "-x", "__pycache__", old, new], cwd=GATE, capture_output=True)
        with open(o, "wb") as fh:
            fh.write(p.stdout)
        print(f"{out}: diff exit {p.returncode}; {len(p.stdout)} B; sha256 {sha(o)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
