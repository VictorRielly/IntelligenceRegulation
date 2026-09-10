"""Bounded integration validation; all stages and final exits are retained."""
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
REPORT = ROOT/"results/zk60_round25_validation.json"
resource.setrlimit(resource.RLIMIT_AS, (8*1024**3, 8*1024**3))
env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
env.update(CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2", RUST_TEST_THREADS="2")
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
report = dict(schema=1, reviewed_head=subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
              status="running", stages=[], rlimit_as=8*1024**3,
              runtime_protocol_changed=False, full_privacy_review_complete=False)


def save():
    temporary = REPORT.with_suffix(".tmp")
    temporary.write_text(json.dumps(report, indent=2)+"\n")
    temporary.replace(REPORT)


def stage(name, command, overrides=None):
    log = OUT/(name+".log")
    start = time.monotonic()
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
    prior = json.loads((ROOT/"results/zk60_round24_validation.json").read_text())
    assert prior["status"] == "passed" and all(s["exit_code"] == 0 for s in prior["stages"])
    assert (ROOT/"results/zk60_round24_evidence/validation.done").read_text().strip() == "0"
    count = 0
    for group in ("source_sha256", "tools", "results"):
        for path, digest in prior[group].items():
            assert sha(ROOT/path) == digest, path
            count += 1
    for s in prior["stages"]:
        assert sha(ROOT/"results/zk60_round24_evidence"/(s["name"]+".log")) == s["log_sha256"]
        count += 1
    report["previous_round_verified_hashes"] = count
    hashes = []
    for stem in ("endpoint_experiment", "oracle_bookkeeping", "repeated_view"):
        path = ROOT/("results/zk60_opus_"+stem+"_review.json")
        review = json.loads(path.read_text())
        for group in ("source_sha256", "input_sha256"):
            for p, digest in review.get(group, {}).items():
                probe = subprocess.run(["git", "cat-file", "-e", "c5eb201:"+p], capture_output=True)
                ref = "c5eb201" if probe.returncode == 0 else "b8fbf4b"
                data = subprocess.check_output(["git", "show", ref+":"+p])
                assert hashlib.sha256(data).hexdigest() == digest, p
                hashes.append(dict(path=p, reference=ref, sha256=digest))
    assert len(hashes) == 28
    report["review_hash_checks"] = hashes
    jobs = json.loads((ROOT/"docs/zkmatrix-poc/zk60_fable_tasks.json").read_text())["opus_current_tasks"]
    assert [t["id"] for t in jobs if t["status"] == "ready"] == ["O12", "O13", "O14"]
    stage("affected_python", ["python3", str(OUT/"check_tests.py")])
    stage("endpoint_views", ["flock", "/tmp/zk-heavy.lock", "python3", "scripts/zk60_endpoint_view.py",
                              "--captures", "results/zk60_round22_captures", "--manifest", "results/zk60_round22_captures.json",
                              "--out", "results/zk60_round25_endpoint_views.json"])
    stage("review_recomputation", ["flock", "/tmp/zk-heavy.lock", "python3", str(OUT/"recompute_reviews.py")])
    stage("native_freeze", [str(ROOT/"zkmatrix-rs/target/release/ring_matmul"), "freeze-check"],
          {"M125_EXPORT_DIR": str(ROOT/"results/m125_ffn_export_wsl")})
    report["source_sha256"] = dict(prior["source_sha256"])
    report["source_sha256"]["zkp-core/src/field.rs"] = sha(ROOT/"zkp-core/src/field.rs")
    for path, digest in prior["source_sha256"].items():
        assert sha(ROOT/path) == digest, path
    report["tools"] = {path: sha(ROOT/path) for path in (
        "scripts/zk60_endpoint_view.py", "tests/test_zk60_endpoint_view.py",
        "results/zk60_round25_evidence/validate.py", "results/zk60_round25_evidence/check_tests.py",
        "results/zk60_round25_evidence/recompute_reviews.py")}
    report["results"] = {path: sha(ROOT/path) for path in (
        "results/zk60_round25_endpoint_views.json", "results/zk60_round25_review_recomputation.json",
        "results/zk60_opus_endpoint_experiment_review.json", "results/zk60_opus_oracle_bookkeeping_review.json",
        "results/zk60_opus_repeated_view_review.json", "results/zk60_opus_io_capture_analysis_round22.json")}
    report.update(status="passed", python_tests=75, python_skips=0, endpoint_owners=8,
                  generated_field_views=8, alternate_data_completions=8, ideal_oracle_paths=2048,
                  full_rust_suite_rerun=False, full_python_suite_rerun=False)
    save()
    (OUT/"validation.done").write_text("0\n")
except BaseException:
    report["status"] = "failed"
    save()
    (OUT/"validation.done").write_text("1\n")
    raise
