"""Run the integrated component demo, retaining real-process acceptance evidence."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ARTIFACTS = ROOT / "results/zk60_mvp_20260915_demo"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run():
    env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
    env.update(CARGO_NET_OFFLINE="true", CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2")
    report = dict(status="running", stages=[], full_private_mvp=False,
                  full_privacy_review_complete=False)
    for name, command, expected in (
        ("demo_unit_tests", [sys.executable, "-m", "unittest", "discover", "-s", "tests",
                             "-p", "test_zk60_p1_demo*.py", "-v"], 0),
        ("demo_real", ["flock", "/tmp/zk-heavy.lock", sys.executable, "scripts/zk60_p1_demo.py",
                       "--output", str(ARTIFACTS)], 0),
        ("demo_existing_output", [sys.executable, "scripts/zk60_p1_demo.py",
                                  "--output", str(ARTIFACTS)], 1),
    ):
        start = time.monotonic()
        log = OUT / (name + ".log")
        with log.open("x") as stream:
            process = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        report["stages"].append(dict(name=name, command=command, exit_code=process.returncode,
                                     expected_exit_code=expected, elapsed_s=time.monotonic()-start,
                                     log_sha256=sha(log)))
        if name == "demo_real" and process.returncode == 0:
            report["demo_manifest_sha256"] = sha(ARTIFACTS / "manifest.json")
        (OUT / "demo_validation.json").write_text(json.dumps(report, indent=2) + "\n")
        print(name, process.returncode, flush=True)
        if process.returncode != expected:
            raise RuntimeError("failed stage: " + name)
    manifest = json.loads((ARTIFACTS / "manifest.json").read_text())
    assert sha(ARTIFACTS / "manifest.json") == report["demo_manifest_sha256"]
    assert manifest["status"] == "passed" and len(manifest["rejection_controls"]) == 6
    for item in manifest["artifacts"]:
        relative = item["path"].removeprefix("<output>/")
        assert sha(ARTIFACTS / relative) == item["sha256"]
    (OUT / "demo_manifest.json").write_bytes((ARTIFACTS / "manifest.json").read_bytes())
    report["source_sha256"] = {p: sha(ROOT / p) for p in (
        "scripts/zk60_p1_demo.py", "tests/test_zk60_p1_demo.py", "tests/test_zk60_p1_demo_contract.py",
        "hashline/examples/zk60_bound_ffn.rs")}
    report["status"] = "passed"
    (OUT / "demo_validation.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    if sys.argv[1:] == ["--detach"]:
        with (OUT / "demo_runner.log").open("x") as log:
            child = subprocess.Popen([sys.executable, str(Path(__file__).resolve())], cwd=ROOT,
                                     stdin=subprocess.DEVNULL, stdout=log,
                                     stderr=subprocess.STDOUT, start_new_session=True)
        print(child.pid)
        raise SystemExit(0)
    code = 1
    try:
        run()
        code = 0
    finally:
        (OUT / "demo_validation.done").write_text(str(code) + "\n")
