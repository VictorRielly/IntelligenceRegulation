#!/usr/bin/env python3
"""Demo rehearsal: light, CPU-only, no GPU, no model, no heavy proof (~1 s total).

1. Fresh-process verification of the RETAINED 785-byte Groth16 receipts of the
   complete tiny private block and of the synthetic two-block token model
   (zkVM line), plus a one-bit-flipped block receipt that must be refused.
2. The toy native private block (custom line, D22 profile): prove (~0.1 s) into
   a throw-away temporary directory, then verify it in a fresh process, which
   also refuses three corrupted copies. The temporary directory is deleted.

Writes rehearsal-<UTC stamp>.json next to this script (commands, exit codes,
seconds, binary and artifact SHA-256, verbatim stdout). Nothing here reads or
writes a private witness; the toy fixture is public and synthetic.
Run:  python3 results/zk60_vc_readiness_20260929/rehearse.py
"""
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
PUB = REPO / "results/zk60_loop_20260918/block-integration/groth16_public"
WRAP = REPO / "zkvm-block/target/release/zk60-block-wrap"
DEMO = REPO / "scripts/zk60_zkvm_demo.py"
TOY = REPO / "hashline/target/release/examples/zk60_private_block"
IMAGE_ID = (PUB / "wrap-image-id.log").read_text().strip()
TOKEN_PUB = REPO / "results/zk60_loop_20260918/token-integration/token_public"
TOKEN_WRAP = REPO / "zkvm-block/target/release/zk60-token-wrap"
TOKEN_IMAGE_ID = (TOKEN_PUB / "token-v2-image-id.log").read_text().strip()


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def run(name, cmd, expect_zero):
    t = time.monotonic()
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return {"name": name, "command": [str(c) for c in cmd], "exit_code": r.returncode,
            "seconds": round(time.monotonic() - t, 3), "expected_exit_zero": expect_zero,
            "as_expected": (r.returncode == 0) == expect_zero, "stdout": r.stdout, "stderr": r.stderr[-2000:]}


def main():
    steps = []
    verify = [sys.executable, DEMO, "verify", "--profile", "block", "--expected-image-id", IMAGE_ID,
              "--wrap", WRAP, "--policy", PUB / "policy.bin"]
    steps.append(run("groth16-verify-retained", verify + ["--receipt", PUB / "groth16.bin"], True))
    steps.append(run("token-groth16-verify-retained",
                     [sys.executable, DEMO, "verify", "--profile", "token", "--expected-image-id", TOKEN_IMAGE_ID,
                      "--wrap", TOKEN_WRAP, "--policy", TOKEN_PUB / "policy.bin", "--receipt", TOKEN_PUB / "receipt.bin"], True))
    work = Path(tempfile.mkdtemp(prefix="zk60-vc-rehearsal-"))
    try:
        bad = bytearray((PUB / "groth16.bin").read_bytes())
        bad[400] ^= 1
        (work / "groth16_flipped.bin").write_bytes(bytes(bad))
        steps.append(run("groth16-verify-one-bit-flipped", verify + ["--receipt", work / "groth16_flipped.bin"], False))
        steps.append(run("toy-private-block-prove", [TOY, "prove", work / "pb"], True))
        steps.append(run("toy-private-block-verify-fresh-process", [TOY, "verify", work / "pb"], True))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    rec = {"utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
           "scope": "demo rehearsal only: tiny synthetic fixtures; no model-scale, GPU or speed claim",
           "binaries": {str(WRAP): sha(WRAP), str(TOKEN_WRAP): sha(TOKEN_WRAP), str(TOY): sha(TOY), str(DEMO): sha(DEMO)},
           "artifacts": {str(PUB / "groth16.bin"): sha(PUB / "groth16.bin"), str(PUB / "policy.bin"): sha(PUB / "policy.bin"),
                         str(TOKEN_PUB / "receipt.bin"): sha(TOKEN_PUB / "receipt.bin"),
                         str(TOKEN_PUB / "policy.bin"): sha(TOKEN_PUB / "policy.bin")},
           "expected_image_id": IMAGE_ID, "token_expected_image_id": TOKEN_IMAGE_ID, "steps": steps,
           "all_as_expected": all(s["as_expected"] for s in steps)}
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    (HERE / f"rehearsal-{stamp}.json").write_text(json.dumps(rec, indent=2) + "\n")
    for s in steps:
        print(f"{s['name']:40s} exit={s['exit_code']} {s['seconds']:.3f}s {'OK' if s['as_expected'] else 'UNEXPECTED'}")
    print("ALL AS EXPECTED" if rec["all_as_expected"] else "REHEARSAL FAILED")
    return 0 if rec["all_as_expected"] else 1


if __name__ == "__main__":
    sys.exit(main())
