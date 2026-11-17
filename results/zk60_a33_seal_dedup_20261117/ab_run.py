#!/usr/bin/env python3
"""A33 G5: the A B A B timing leaves, through guarded.py (the resource guard, class gpu).

usage: ab_run.py <arm serve1|serve4> <unpatched binary> <patched binary> [order ABAB]

The leaf, its environment and the guard arguments are Batch 7's (run_batch7_guarded.py lines 871 and 903-915):
  leaf = <binary> --ignored --exact --nocapture private_block::run::fork::tests::a22::a22_stream_ab
  env  = HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32
         HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32 HL_A22_AB_PASSES=6 HL_A22_AB=<arm>
  guard = class gpu; serve1 --need-gib 36 --cap-gib 48 --max-secs 420; serve4 40 / 52 / 600; default poll.
Not set (Batch 7 set it for its own trace analysis): HL_A27_GPU_TRACE.
The unpatched binary's SHA-256 is checked before every run; the patched binary's SHA-256 is recorded.
"""
import hashlib
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEST = "private_block::run::fork::tests::a22::a22_stream_ab"
BASE_SHA = "aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11"
ARMS = {"serve1": ("36", "48", "420"), "serve4": ("40", "52", "600")}


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def main() -> int:
    arm, a_bin, b_bin = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    order = sys.argv[4] if len(sys.argv) > 4 else "ABAB"
    prefix = sys.argv[5] if len(sys.argv) > 5 else ""  # "m_" = the runs on the merged tree (base 2ae06f54)
    need, cap, mx = ARMS[arm]
    b_sha = sha(b_bin)
    log = HERE / "raw" / f"{prefix}{arm}_binaries.txt"
    log.write_text(f"A (unpatched) {a_bin} sha256 {BASE_SHA}\nB (patched)   {b_bin} sha256 {b_sha}\norder {order}\n")
    counts = {"A": 0, "B": 0}
    for i, who in enumerate(order, 1):
        counts[who] += 1
        binp = a_bin if who == "A" else b_bin
        if who == "A" and sha(a_bin) != BASE_SHA:
            print("ABORT: the unpatched binary's hash differs")
            return 98
        label = f"{prefix}{arm}_{i}{who}"
        rc = subprocess.run([
            sys.executable, "-B", str(HERE / "guarded.py"), label, "gpu", need, cap, mx,
            "HL_GPU=1", "HL_GPU_REQUIRED=1", "HL_PB_ORACLE=0", "HL_METAL_TIMING=0", "HL_D55_PROFILE=W16R2_8B_T128_H24",
            "HL_D55_L=32", "HL_D55_WORKERS=6", "HL_A19_BUDGET_GIB=32", "HL_A22_AB_PASSES=6", f"HL_A22_AB={arm}",
            "--", str(binp), "--ignored", "--exact", "--nocapture", TEST,
        ]).returncode
        if rc != 0:
            print(f"ABORT: {label} exited {rc}")
            return rc
    return 0


if __name__ == "__main__":
    sys.exit(main())
