"""Resume audit and fresh IO evidence; never overwrite historical captures/results."""
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
CAPTURES = ROOT / "results/zk60_round22_captures"
MANIFEST = ROOT / "results/zk60_round22_captures.json"
REPORT = ROOT / "results/zk60_round22_validation.json"
SOURCE = "1f0ff3680c4cda88f1744343e24eb93cdddfcba4"
ENV = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
ENV.update(CARGO_BUILD_JOBS="2", RAYON_NUM_THREADS="2", RUST_TEST_THREADS="2",
           CARGO_TARGET_DIR=str(ROOT / "hashline/target/storage-tests"))
resource.setrlimit(resource.RLIMIT_AS, (8 * 1024**3, 8 * 1024**3))
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()


def save(path, value):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, indent=2) + "\n")
    tmp.replace(path)


report = json.loads(REPORT.read_text()) if REPORT.exists() else {
    "schema": 1, "source_commit": SOURCE, "stages": [],
    "original_tmp_captures_available": False,
    "original_capture_bytes_reproduced": False,
    "fresh_randomness": True, "runtime_protocol_changed": False,
    "full_privacy_review_complete": False,
}


def stage(name, command, expected=0, overrides=None):
    log = OUT / (name + ".log")
    if any(s["name"] == name for s in report["stages"]):
        raise RuntimeError("stage already recorded: " + name)
    start = time.monotonic()
    with log.open("wb") as stream:
        result = subprocess.run(command, cwd=ROOT, env=dict(ENV, **(overrides or {})),
                                stdout=stream, stderr=subprocess.STDOUT)
    report["stages"].append(dict(name=name, command=command, exit_code=result.returncode,
                                expected_exit_code=expected, environment_overrides=overrides or {},
                                elapsed_s=time.monotonic()-start, log_sha256=sha(log)))
    save(REPORT, report)
    print(name, result.returncode, flush=True)
    if result.returncode != expected:
        raise RuntimeError(name + " failed; see " + str(log))


def capture():
    old = json.loads((ROOT / "results/zk60_round21_validation.json").read_text())
    checks = 0
    base = ROOT / "results/zk60_round21_evidence"
    index = json.loads((base / "index.json").read_text())
    for name, item in index["files"].items():
        assert sha(base / name) == item["sha256"]
        assert (base / name).stat().st_size == item["bytes"]
        checks += 1
    for group in ("source_sha256", "tools"):
        for name, digest in old[group].items():
            assert sha(ROOT / name) == digest, name
            checks += 1
    for key, path in (("cfs_result_sha256", "results/zk60_round21_io_cfs.json"),
                      ("history_result_sha256", "results/zk60_privacy_history_audit.json"),
                      ("test_sha256", "tests/test_zk60_io_cfs_composition.py"),
                      ("evidence_index_sha256", "results/zk60_round21_evidence/index.json")):
        assert sha(ROOT / path) == old[key]
        checks += 1
    for entry in old["stages"]:
        assert entry["exit_code"] == entry["expected_exit_code"]
        assert sha(base / (entry["name"] + ".log")) == entry["log_sha256"]
        checks += 1
    assert (base / "validation.done").read_text().strip() == "0"
    assert not subprocess.check_output(["git", "diff", SOURCE, "--", "hashline", "zkp-core"], cwd=ROOT)
    report["round21_audit"] = {"hash_checks": checks, "stages": len(old["stages"]), "status": "passed"}
    report["source_sha256"] = old["source_sha256"]
    report["binary_sha256"] = sha(ROOT / "hashline/target/release/examples/zk60_bound_ffn")
    assert report["binary_sha256"] == old["binary_sha256"]
    CAPTURES.mkdir(exist_ok=False)
    stage("rust_bound_io", ["flock", "/tmp/zk-heavy.lock", "/home/victor/.cargo/bin/cargo",
          "test", "--release", "--locked", "--offline", "--manifest-path", "hashline/Cargo.toml",
          "--features", "stable-weight-storage", "bound_ffn_", "--", "--test-threads=2", "--nocapture"],
          overrides={"HL_TEST_FFN_IO_OBSERVATIONS": str(CAPTURES), "HL_TEST_SOURCE_COMMIT": SOURCE})
    sys.path.insert(0, str(ROOT / "scripts"))
    import zk60_io_capture_preflight as pre
    checked = pre.run(CAPTURES, SOURCE)
    assert checked["counts"] == {"P1": 2, "P3": 2}
    manifest = dict(schema=1, source_commit=SOURCE, source_sha256=report["source_sha256"],
                    status="complete", privacy_analysis_performed=False, rust_test_count=6,
                    captures=checked, origin="fresh round-22 run, not the missing round-19 artifacts")
    save(MANIFEST, manifest)
    report["fresh_capture_manifest_sha256"] = sha(MANIFEST)
    binary = str(ROOT / "hashline/target/release/examples/zk60_bound_ffn")
    for i, path in enumerate(sorted(CAPTURES.glob("*.json"))):
        cap = json.loads(path.read_bytes())
        policy = path.with_suffix(".expected").read_bytes()
        context = policy[8:40].hex()
        weight = "fresh" if cap["privacy"] == "P3" else bytes(cap["public_w"]["root"]).hex()
        args = [binary, "verify", cap["privacy"].lower(), weight, context]
        stage(f"receipt_{i}", args + [str(path.with_suffix(".expected")), str(path.with_suffix(".receipt"))])
        for side, offset in (("input", 48), ("output", 80)):
            changed = bytearray(policy)
            changed[offset] ^= 1
            target = OUT / f"{i}_wrong_{side}.expected"
            target.write_bytes(changed)
            stage(f"receipt_{i}_wrong_{side}", args + [str(target), str(path.with_suffix(".receipt"))], 1)
        mode = "p1" if cap["privacy"] == "P3" else "p3"
        stage(f"receipt_{i}_wrong_mode", [binary, "verify", mode, "00"*32 if mode == "p1" else "fresh",
              context, str(path.with_suffix(".expected")), str(path.with_suffix(".receipt"))], 1)
    stage("native_freeze", [str(ROOT / "zkmatrix-rs/target/release/ring_matmul"), "freeze-check"],
          overrides={"M125_EXPORT_DIR": str(ROOT / "results/m125_ffn_export_wsl")})
    report["capture_status"] = "passed"


def review():
    assert report["capture_status"] == "passed"
    assert sha(MANIFEST) == report["fresh_capture_manifest_sha256"]
    stage("python_io", ["python3", "-m", "unittest", "discover", "-s", "tests",
                       "-p", "test_zk60_io_*.py", "-v"])
    stage("o8_fresh_tests", ["python3", str(OUT / "review_tests.py")])
    stage("o8_analysis", ["python3", "scripts/zk60_io_review_gate.py", "--captures", str(CAPTURES),
                         "--manifest", str(MANIFEST), "--out", "results/zk60_round22_o8_analysis.json"])
    stage("fresh_openings", ["python3", "scripts/zk60_io_opening_translation.py", "--captures", str(CAPTURES),
                            "--manifest", str(MANIFEST), "--out", "results/zk60_round22_opening_translation.json"])
    stage("fresh_cfs", ["python3", str(OUT / "cfs_checks.py")])
    report["status"] = "passed"
    report["tools"] = {p: sha(ROOT / p) for p in (
        "scripts/zk60_io_review_gate.py", "tests/test_zk60_io_review_gate.py",
        "results/zk60_round22_evidence/validate.py", "results/zk60_round22_evidence/review_tests.py",
        "results/zk60_round22_evidence/cfs_checks.py")}
    report["analysis_results"] = {p: sha(ROOT / p) for p in (
        "results/zk60_round22_o8_analysis.json", "results/zk60_round22_opening_translation.json",
        "results/zk60_round22_io_cfs.json")}


if __name__ == "__main__":
    try:
        {"capture": capture, "review": review}[sys.argv[1]]()
        save(REPORT, report)
        (OUT / (sys.argv[1] + ".done")).write_text("0\n")
    except BaseException:
        (OUT / (sys.argv[1] + ".done")).write_text("1\n")
        raise
