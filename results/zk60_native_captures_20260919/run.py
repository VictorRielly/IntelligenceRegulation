#!/usr/bin/env python3
"""Retain native public-fixture capture evidence; no GPU or real-model input."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SOURCE = "2b5c65c3c430d6d6dd7ac24ab0c115181e36ca75"
sys.path.insert(0, str(ROOT / "scripts"))
import zk60_native_capture as native


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    binary = Path(sys.argv[1]).resolve()
    if (OUT / "validation.json").exists() or (OUT / "captures").exists():
        raise SystemExit("refusing to overwrite retained evidence")
    subprocess.run(["git", "diff", "--exit-code", SOURCE, "--", "hashline/src", "zkp-core/src", "private-block-kernel/src", "hashline/Cargo.toml", "hashline/Cargo.lock"], cwd=ROOT, check=True)
    paths = sorted({p for base in ("hashline/src", "zkp-core/src", "private-block-kernel/src") for p in (ROOT / base).rglob("*.rs")})
    paths += [ROOT / p for p in ("hashline/Cargo.toml", "hashline/Cargo.lock", "scripts/zk60_native_capture.py", "scripts/zk60_io_capture_preflight.py", "scripts/zk60_fable_cfs_channel.py", "scripts/zk60_fable_joint_rank.py", "tests/test_zk60_native_capture.py")]
    source = {"source_commit": SOURCE, "verifier_test_binary": str(binary.relative_to(ROOT)), "verifier_binary_sha256": digest(binary),
              "files": {str(p.relative_to(ROOT)): digest(p) for p in paths}, "runner_sha256": digest(Path(__file__))}
    (OUT / "source.json").write_text(json.dumps(source, indent=2, sort_keys=True) + "\n")
    env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
    env.update(RAYON_NUM_THREADS="2", HL_TEST_SOURCE_COMMIT=SOURCE)
    runs = []

    def run(name, argv, overrides=None):
        started = time.monotonic()
        with (OUT / (name + ".log")).open("w") as log:
            completed = subprocess.run([str(x) for x in argv], cwd=ROOT, env=env | (overrides or {}), stdout=log, stderr=subprocess.STDOUT, timeout=180)
        (OUT / (name + ".done")).write_text(str(completed.returncode) + "\n")
        result = {"name": name, "argv": [str(x) for x in argv], "exit_code": completed.returncode, "seconds_shared_box_diagnostic": time.monotonic() - started}
        runs.append(result)
        print(json.dumps(result), flush=True)
        if completed.returncode:
            raise SystemExit("failed " + name)

    run("attention-unit", [binary, "private_attention", "--test-threads=2"])
    run("block-unit", [binary, "private_block", "--test-threads=2"])
    run("generate", [binary, "native_capture_roundtrip_and_refusals", "--nocapture"], {"HL_TEST_NATIVE_CAPTURES": str(OUT / "captures")})
    captures = sorted((OUT / "captures").glob("*.json"))
    assert len(captures) == 4
    accepted = [native.check_bundle(p, SOURCE, binary, source["verifier_binary_sha256"]) for p in captures]
    for profile in native.PROFILES:
        assert sum(r["profile"] == profile for r in accepted) == 2
    # Compatibility with saved pre-instrumentation receipts, in fresh processes.
    for module, stem in [("private_attention", "attention"), ("private_block", "block")]:
        fixture = ROOT / "results/zk60_attention_integration_20260919" / (stem + "_public")
        run(stem + "-archived", [binary, "--exact", module + "::capture::native_capture_saved_receipt", "--ignored", "--nocapture"],
            {"HL_TEST_NATIVE_RECEIPT": str(fixture / (stem + "_receipt.bin")), "HL_TEST_NATIVE_EXPECTED": str(fixture / (stem + "_expected.bin"))})
    run("python-capture-controls", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_zk60_native_capture.py", "-v"],
        {"HL_NATIVE_CAPTURE_TEST_BINARY": str(binary), "HL_NATIVE_CAPTURE_FIXTURES": str(OUT / "captures")})
    manifest = {"source_commit": SOURCE, "verifier_binary_sha256": source["verifier_binary_sha256"], "accepted": accepted,
                "runs": runs, "artifacts": {str(p.relative_to(OUT)): {"sha256": digest(p), "bytes": p.stat().st_size} for p in sorted((OUT / "captures").iterdir())},
                "privacy_review_complete": False, "model_scale_or_speed_claim": False}
    (OUT / "validation.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
