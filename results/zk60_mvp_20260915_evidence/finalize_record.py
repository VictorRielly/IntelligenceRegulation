"""Summarize completed checks and bind the final integration's source bytes."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def test_result(name):
    text = (OUT / name).read_text()
    count = int(re.search(r"^Ran (\d+) tests", text, re.M)[1])
    result = re.search(r"^OK(?: \(skipped=(\d+)\))?$", text, re.M)
    assert result, name
    return dict(tests=count, skipped=int(result[1] or 0), log_sha256=sha(OUT / name))


base = json.loads((OUT / "validation.json").read_text())
demo = json.loads((OUT / "demo_validation.json").read_text())
stages = json.loads((OUT / "integration_stages.json").read_text())
assert base["status"] == demo["status"] == "passed"
assert (OUT / "validation.done").read_text().strip() == "0"
assert (OUT / "demo_validation.done").read_text().strip() == "0"
assert all(stage["exit_code"] == 0 for stage in stages)
assert not subprocess.check_output(["git", "diff", "--", "hashline", "zkp-core", "zkmatrix-rs"], cwd=ROOT)
paths = [
    "scripts/zk60_p1_demo.py", "scripts/zk60_mvp_security_probe.py",
    "tests/test_zk60_p1_demo.py", "tests/test_zk60_p1_demo_contract.py",
    "tests/test_zk60_mvp_security_probe.py", "tests/test_zk60_mvp_review_boundary.py",
    "docs/zkmatrix-poc/ZK60_MVP_20260915.md", "docs/zkmatrix-poc/ZK60_MVP_REVIEW.md",
    "docs/zkmatrix-poc/ZK60_P1_DEMO.md", "docs/zkmatrix-poc/ZK60_MVP_SECURITY_DECISION.md",
]
probe = json.loads((OUT / "security_probe.json").read_text())
assert probe["tool_sha256"] == sha(ROOT / "scripts/zk60_mvp_security_probe.py")
for path, expected in demo["source_sha256"].items():
    assert sha(ROOT / path) == expected, path
record = dict(
    schema=1, baseline=base["baseline"], status="component_and_bounded_checks_passed",
    delegation_models=["claude-fable-5-1", "claude-opus-5"], delegation_completed=True,
    original_fable_delivery_index_sha256=sha(OUT / "fable_delivery/index.json"),
    component_receipt_bytes=5029244, real_demo_steps=9, real_rejection_controls=6,
    prior_hash_checks=len(base["round25_hash_checks"]),
    full_python=test_result("full_python.log"),
    endpoint_tests=test_result("round25_python.log"),
    fresh_io_tests=test_result("fresh_io_tests.log"),
    demo_tests=test_result("final_demo_tests.log"),
    security_tests=test_result("final_security_tests.log"),
    source_sha256={path: sha(ROOT / path) for path in paths},
    evidence_sha256={p.name: sha(p) for p in sorted(OUT.iterdir())
                     if p.is_file() and p.suffix in (".log", ".json") and p.name != "final_summary.json"},
    production_rust_changed=False, full_private_block=False, model_scale_mvp=False,
    whole_proof_privacy_accepted=False, external_root_requirement_preserved=True,
)
(OUT / "final_summary.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps({key: record[key] for key in (
    "status", "full_python", "demo_tests", "security_tests", "model_scale_mvp")}))
