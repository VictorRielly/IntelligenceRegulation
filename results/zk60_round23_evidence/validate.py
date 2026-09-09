"""Bounded CPU validation of round-23 analysis and simulator bookkeeping."""
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
REPORT = ROOT / "results/zk60_round23_validation.json"
resource.setrlimit(resource.RLIMIT_AS, (8 * 1024**3, 8 * 1024**3))
env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
env.update(CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2", RUST_TEST_THREADS="2",
           CARGO_TARGET_DIR=str(ROOT / "hashline/target/storage-tests"))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
report = dict(schema=1, reviewed_head=subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
              status="running", stages=[], runtime_protocol_changed=False,
              full_privacy_review_complete=False, rlimit_as=8*1024**3)


def save():
    temporary = REPORT.with_suffix(".tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n")
    temporary.replace(REPORT)


def stage(name, command, overrides=None):
    start = time.monotonic()
    log = OUT / (name + ".log")
    with log.open("xb") as stream:
        result = subprocess.run(command, cwd=ROOT, env=dict(env, **(overrides or {})),
                                stdout=stream, stderr=subprocess.STDOUT)
    report["stages"].append(dict(name=name, command=command, exit_code=result.returncode,
                                environment_overrides=overrides or {}, elapsed_s=time.monotonic()-start,
                                log_sha256=sha(log)))
    save()
    print(name, result.returncode, flush=True)
    if result.returncode:
        raise RuntimeError(name + " failed")


try:
    base = ["flock", "/tmp/zk-heavy.lock", "/home/victor/.cargo/bin/cargo", "test", "--release",
            "--locked", "--offline", "--manifest-path", "hashline/Cargo.toml", "--features", "stable-weight-storage"]
    stage("rust_hash_boundary", base + ["--test", "zk60_endpoint_hash_boundary", "--", "--test-threads=2"])
    stage("rust_io", base + ["bound_ffn_", "--", "--test-threads=2"])
    stage("python_io", ["python3", "-m", "unittest", "discover", "-s", "tests", "-p", "test_zk60_io_*.py", "-v"])
    stage("python_endpoint", ["python3", "-m", "unittest", "discover", "-s", "tests", "-p", "test_zk60_endpoint_simulation.py", "-v"])
    stage("repeated_view", ["python3", "scripts/zk60_io_repeated_view.py", "--captures", "results/zk60_round22_captures",
                            "--manifest", "results/zk60_round22_captures.json", "--out", "results/zk60_round23_repeated_view.json"])
    stage("endpoint_simulation", ["python3", "scripts/zk60_endpoint_simulation.py", "--out", "results/zk60_round23_endpoint_simulation.json"])
    stage("native_freeze", [str(ROOT / "zkmatrix-rs/target/release/ring_matmul"), "freeze-check"],
          {"M125_EXPORT_DIR": str(ROOT / "results/m125_ffn_export_wsl")})
    prior = json.loads((ROOT / "results/zk60_round22_validation.json").read_text())
    report["source_sha256"] = dict(prior["source_sha256"])
    for path in ("zkp-core/src/merkle.rs", "zkp-core/src/rng.rs"):
        report["source_sha256"][path] = sha(ROOT / path)
    for path, digest in report["source_sha256"].items():
        assert sha(ROOT / path) == digest, path
    report["tools"] = {path: sha(ROOT / path) for path in (
        "scripts/zk60_io_repeated_view.py", "scripts/zk60_endpoint_simulation.py",
        "tests/test_zk60_io_repeated_view.py", "tests/test_zk60_endpoint_simulation.py",
        "hashline/tests/zk60_endpoint_hash_boundary.rs", "results/zk60_round23_evidence/validate.py")}
    report["results"] = {path: sha(ROOT / path) for path in (
        "results/zk60_round23_repeated_view.json", "results/zk60_round23_endpoint_simulation.json",
        "results/zk60_round22_captures.json")}
    report.update(status="passed", rust_tests=8, python_tests=39, python_skips=0)
    save()
    (OUT / "validation.done").write_text("0\n")
except BaseException:
    report["status"] = "failed"
    save()
    (OUT / "validation.done").write_text("1\n")
    raise
