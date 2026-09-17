"""Retain status-refresh checks without overwriting historical run evidence."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
REPORT = OUT / "validation.json"


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run():
    env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
    env.update(CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2", RUST_TEST_THREADS="2",
               CARGO_NET_OFFLINE="true", M125_EXPORT_DIR=str(ROOT / "results/m125_ffn_export_wsl"))
    report = dict(schema=1, baseline=subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        status="running", stages=[], full_private_mvp=False, full_privacy_review_complete=False)
    previous = json.loads((ROOT / "results/zk60_round25_validation.json").read_text())
    checks = []
    for group in ("source_sha256", "tools", "results"):
        for relative, expected in previous[group].items():
            actual = sha(ROOT / relative)
            checks.append(dict(path=relative, sha256=actual, matched=actual == expected))
    report["round25_hash_checks"] = checks
    if not all(c["matched"] for c in checks):
        raise RuntimeError("round-25 source/evidence mismatch")
    commands = [
        ("build_bound_ffn", [str(Path.home() / ".cargo/bin/cargo"), "build", "--manifest-path",
                             "hashline/Cargo.toml", "--release", "--locked", "--offline",
                             "--example", "zk60_bound_ffn"]),
        ("round25_python", [sys.executable, "results/zk60_round25_evidence/check_tests.py"]),
        ("native_freeze", [str(ROOT / "zkmatrix-rs/target/release/ring_matmul"), "freeze-check"]),
        ("full_python", [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v"]),
    ]
    for name, command in commands:
        log = OUT / (name + ".log")
        start = time.monotonic()
        with log.open("x") as stream:
            p = subprocess.run(["flock", "/tmp/zk-heavy.lock", *command], cwd=ROOT, env=env,
                               stdout=stream, stderr=subprocess.STDOUT)
        report["stages"].append(dict(name=name, command=command, exit_code=p.returncode,
                                     elapsed_s=time.monotonic() - start, log_sha256=sha(log)))
        REPORT.write_text(json.dumps(report, indent=2) + "\n")
        print(name, p.returncode, flush=True)
        if p.returncode:
            report["status"] = "failed"
            REPORT.write_text(json.dumps(report, indent=2) + "\n")
            return 1
    report["binary_sha256"] = sha(ROOT / "hashline/target/release/examples/zk60_bound_ffn")
    report["status"] = "passed"
    REPORT.write_text(json.dumps(report, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--detach"]:
        with (OUT / "runner.log").open("a") as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve())], cwd=ROOT,
                                     stdin=subprocess.DEVNULL, stdout=log,
                                     stderr=subprocess.STDOUT, start_new_session=True)
        print(child.pid)
        raise SystemExit(0)
    code = 1
    try:
        code = run()
    finally:
        (OUT / "validation.done").write_text(str(code) + "\n")
    raise SystemExit(code)
