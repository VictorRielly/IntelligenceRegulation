#!/usr/bin/env python3
"""[gate round 24] Install frozen tools v24 in the gate's WORKING COPY
(ops/zkp-mvp/gate-tinyllama/{scripts,tests,counts}), as round 20 installed the previous version.
Copies every manifest-listed file from frozen_v24/ (no other file is touched, nothing deleted), then
checks the working copy against the v24 manifest (80 / 0 / 0 expected).

    python3 r24_install_wc.py
"""
import os
import shutil
import subprocess
import sys

E = "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017"
GT = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama"
MAN = E + "/gate-tinyllama.tools.frozen.v24.sha256"


def main():
    files = [ln.split(None, 1)[1].strip() for ln in open(MAN)]
    for p in files:
        shutil.copy2(os.path.join(GT, "frozen_v24", p), os.path.join(GT, p))
    print(f"{len(files)} files installed from frozen_v24 into the working copy")
    return subprocess.run([sys.executable, E + "/v4/freeze.py", "check", MAN, GT]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
