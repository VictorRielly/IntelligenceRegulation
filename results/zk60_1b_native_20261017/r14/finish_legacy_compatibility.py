"""Collect successful legacy leaves using exact test identities and outcomes."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
from validate_suite_census import validate

HERE = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    pin = json.loads((HERE / "sol-r14-legacy-full-suite-3.source.json").read_text())
    for name, want in pin["files"].items():
        assert sha(HERE / "compatibility-working-tree" / name) == want
    checkpoint = HERE / "checkpoints/compatibility-suite-3"
    binary_sha = sha(checkpoint / "hashline.test.bin")
    cli_sha = sha(checkpoint / "zk60_trained_block.legacy-cli.bin")
    census = validate(HERE / "sol-r14-legacy-full-suite-3.log", HERE.parent / "r13/release-2-suite.log")
    assert census["passed"] == 834 and census["ignored"] == 71
    names = ["compat-tl", "compat-tl-dd", "compat-8b", "compat-8b-dd"]
    names += [f"cli-verify-{fixture}-{mode}" for fixture in ["r13-low-dense", "r13-h24-wide"] for mode in ["plain", "dd"]]
    labels = ["sol-r14-legacy-full-suite-3", "sol-r14-legacy-goldens-4", "sol-r14-legacy-cli-build-4"]
    labels += ["sol-r14-legacy-" + name + "-4" for name in names]
    records = []
    for label in labels:
        assert (HERE / (label + ".validated.done")).read_text().strip() == "0"
        row = json.loads((HERE / (label + ".result.json")).read_text())
        assert row["guard"]["exit"] == row["guard"]["child_rc"] == 0
        command = json.loads((HERE / (label + ".command.json")).read_text())
        assert command["source"] == pin["tree_sha256"]
        if label in ["sol-r14-legacy-" + name + "-4" for name in names]:
            assert row["cli_sha256"] == cli_sha
            assert row["verified"]["statement_identity"] == row["statement_identity"]
        records.append(row)
    label = "sol-r14-legacy-r12-shield-4"
    assert (HERE / (label + ".done")).read_text().strip() == "0"
    guard = json.loads((HERE / (label + ".guard.json")).read_text())
    assert guard["exit"] == guard["child_rc"] == 0 and not guard["guard_killed"]
    command = json.loads((HERE / (label + ".command.json")).read_text())
    assert command["source"] == pin["tree_sha256"]
    log = (HERE / (label + ".log")).read_text()
    tests = ["f2_saved_shieldstral_t128_dd_receipt_verifies_in_a_fresh_process",
             "f2_saved_shieldstral_t128_receipt_verifies_in_a_fresh_process"]
    assert "2 passed; 0 failed; 0 ignored" in log
    assert all("test private_block::r12_tests::" + name + " ..." in log for name in tests)
    assert log.count("bytes verified; modified segment rejected") == 2
    row = {"label": label, "guard": guard, "retained_R12_Shieldstral_variants": ["DD", "non-DD"],
           "tests": tests, "log_sha256": sha(HERE / (label + ".log"))}
    (HERE / (label + ".result.json")).write_text(json.dumps(row, indent=2) + "\n")
    (HERE / (label + ".validated.done")).write_text("0\n")
    records.append(row)
    assert len(records) == 12
    report = {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"],
              "test_binary_sha256": binary_sha, "legacy_cli_sha256": cli_sha, "cases": records,
              "suite_census": census, "seeded_byte_goldens": 4, "statement_identity_golden": 1,
              "fresh_retained_cli_receipts": 8, "retained_R12_variants": 2,
              "collector_sha256": sha(Path(__file__)),
              "wrapper_repairs": ["WRAPPER3_COUNT_FAILURE.json", "R12 filter matches both explicitly named DD variants, not one; existing successful leaf adopted, no repeat"],
              "scope": "Shared legacy dispatch/argument compatibility at source863: all816baseline passed tests preserved, 18new passing tests, frozen pre-R14 bytes/identities, eight fresh retained R8/R9/R13 CLI receipts and both R12 Shieldstral variants/corruption controls. Experimental CLI source7324 and final release/privacy review are separate."}
    output = HERE / "LEGACY_COMPATIBILITY_ACCEPTANCE.json"
    assert not output.exists()
    output.write_text(json.dumps(report, indent=2) + "\n")
    (HERE / "LEGACY_COMPATIBILITY_ACCEPTANCE.done").write_text("0\n")
    print("Legacy compatibility PASS: Rust834/0/71, goldens5/0, retainedCLI8/0, retainedR12both variants")

if __name__ == "__main__":
    main()
