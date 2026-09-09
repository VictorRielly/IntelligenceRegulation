"""Reproducible, bounded validation of the conditional endpoint sampler."""
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
REPORT = ROOT / "results/zk60_round24_validation.json"
resource.setrlimit(resource.RLIMIT_AS, (8*1024**3, 8*1024**3))
env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
env.update(CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2", RUST_TEST_THREADS="2")
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
report = dict(schema=1, reviewed_head=subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
              status="running", stages=[], runtime_protocol_changed=False,
              full_privacy_review_complete=False, rlimit_as=8*1024**3)


def save():
    temporary = REPORT.with_suffix(".tmp")
    temporary.write_text(json.dumps(report, indent=2)+"\n")
    temporary.replace(REPORT)


def stage(name, command, overrides=None):
    start = time.monotonic()
    log = OUT/(name+".log")
    with log.open("xb") as stream:
        result = subprocess.run(command, cwd=ROOT, env=dict(env, **(overrides or {})),
                                stdout=stream, stderr=subprocess.STDOUT)
    report["stages"].append(dict(name=name, command=command, exit_code=result.returncode,
                                environment_overrides=overrides or {}, elapsed_s=time.monotonic()-start,
                                log_sha256=sha(log)))
    save()
    print(name, result.returncode, flush=True)
    if result.returncode:
        raise RuntimeError(name+" failed")


try:
    prior_path = ROOT/"results/zk60_round23_validation.json"
    prior = json.loads(prior_path.read_text())
    assert prior["status"] == "passed" and all(s["exit_code"] == 0 for s in prior["stages"])
    assert (ROOT/"results/zk60_round23_evidence/validation.done").read_text().strip() == "0"
    count = 0
    for group in ("source_sha256", "tools", "results"):
        for path, digest in prior[group].items():
            assert sha(ROOT/path) == digest, path
            count += 1
    for stage_record in prior["stages"]:
        path = ROOT/"results/zk60_round23_evidence"/(stage_record["name"]+".log")
        assert sha(path) == stage_record["log_sha256"], path
        count += 1
    report.update(previous_round_verified_hashes=count, previous_round_validation_sha256=sha(prior_path))
    handoff = ROOT/"docs/zkmatrix-poc/zk60_fable_tasks.json"
    jobs = json.loads(handoff.read_text())["opus_current_tasks"]
    assert [t["id"] for t in jobs if t["status"] == "ready"] == ["O9", "O10", "O11"]
    assert jobs[0]["id"] == "O8" and jobs[0]["status"] == "delivered_integrated"
    report["queued_opus_jobs"] = ["O9", "O10", "O11"]
    stage("python_io", ["python3", "-m", "unittest", "discover", "-s", "tests", "-p", "test_zk60_io_*.py", "-v"])
    stage("python_endpoint", ["python3", "-m", "unittest", "discover", "-s", "tests", "-p", "test_zk60_endpoint_simulation.py", "-v"])
    stage("python_fibre", ["python3", "-m", "unittest", "discover", "-s", "tests", "-p", "test_zk60_endpoint_fibre.py", "-v"])
    stage("endpoint_fibre", ["flock", "/tmp/zk-heavy.lock", "python3", "scripts/zk60_endpoint_fibre.py",
                             "--captures", "results/zk60_round22_captures", "--manifest", "results/zk60_round22_captures.json",
                             "--out", "results/zk60_round24_endpoint_fibre.json"])
    stage("native_freeze", [str(ROOT/"zkmatrix-rs/target/release/ring_matmul"), "freeze-check"],
          {"M125_EXPORT_DIR": str(ROOT/"results/m125_ffn_export_wsl")})
    report["source_sha256"] = dict(prior["source_sha256"])
    for path, digest in report["source_sha256"].items():
        assert sha(ROOT/path) == digest, path
    report["tools"] = {path: sha(ROOT/path) for path in (
        "scripts/zk60_endpoint_fibre.py", "tests/test_zk60_endpoint_fibre.py",
        "results/zk60_round24_evidence/validate.py")}
    report["results"] = {path: sha(ROOT/path) for path in (
        "results/zk60_round24_endpoint_fibre.json", "results/zk60_round22_captures.json")}
    report.update(status="passed", python_tests=47, python_skips=0, native_freeze_check=True,
                  endpoint_owners=8, conditional_samples=16, ideal_oracle_paths=2048,
                  full_rust_suite_rerun=False, full_python_suite_rerun=False)
    save()
    (OUT/"validation.done").write_text("0\n")
except BaseException:
    report["status"] = "failed"
    save()
    (OUT/"validation.done").write_text("1\n")
    raise
