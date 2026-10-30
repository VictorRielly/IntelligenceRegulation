"""Complete the 50-case relation battery with a non-vacuous dictionary mutation.

Retain the original equivalent-row acceptance failure and all49 prior passes.
New negative and positive control use one later test-only source revision.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys
import regression_checks_direct as prior

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GUARD = ROOT / "scripts/zk60_resource_guard.py"

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()

def main():
    assert (HERE / "CLI_BUILD_ACCEPTANCE_2.done").read_text().strip() == "0"
    build = json.loads((HERE / "CLI_BUILD_ACCEPTANCE_2.json").read_text())
    pin = json.loads((HERE / "sol-r14-cli-build-2.source.json").read_text())
    original = json.loads((HERE / "sol-r14-capture-build-1.source.json").read_text())
    binary = HERE / "checkpoints/cli-build-2/hashline.test.bin"
    unchanged = []
    for part in ["argument_split", "split_protocol", "split_geometry", "split_endpoint", "split_profile", "split_wire"]:
        name = f"hashline/src/private_block/{part}.rs"
        assert pin["files"][name] == original["files"][name]
        unchanged.append(name)
    retained = []
    original_binary_sha = sha(HERE / "checkpoints/capture-build-1/hashline.test.bin")
    for cases in prior.GROUPS.values():
        for dd, case in cases:
            if case == "dictionary-counts":
                continue
            label = "sol-r14-regression-" + ("dd" if dd else "non-dd") + "-" + case + "-1"
            assert (HERE / (label + ".validated.done")).read_text().strip() == "0"
            row = json.loads((HERE / (label + ".result.json")).read_text())
            assert row["source"] == original["tree_sha256"] and row["dd"] == dd and row["case"] == case
            assert row["binary_sha256"] == original_binary_sha
            assert row["guard"]["exit"] == 0 and row["receipt"]["expected_accept"] is False
            assert row["receipt"]["canonical_frame_decoded"] and row["receipt"]["native_verifier_used"]
            assert sha(HERE / row["fixture"] / "segment0.bin") == row["receipt_sha256"]
            retained.append(row)
    assert len(retained) == 49
    def check():
        assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
        assert sha(binary) == build["test_binary_sha256"]
        for name, want in pin["files"].items():
            assert sha(HERE / "cli-candidate-working-tree" / name) == want
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()
    out = HERE / "dictionary-corrected-2"
    assert not out.exists()
    out.mkdir()
    records = []
    for case, expected in [("dictionary-counts", False), ("dictionary-alias-counts", True)]:
        check()
        label = "sol-r14-regression-dd-" + case + "-2"
        fixture = out / case
        command = [sys.executable, str(GUARD), "run", "--class", "cpu", "--label", label,
                   "--need-gib", "7.5", "--cap-gib", "10", "--wait-secs", "21600", "--max-secs", "1200",
                   "--log", str(out / (case + ".log")), "--done", str(out / (case + ".done")),
                   "--result-json", str(out / (case + ".guard.json")), "--", "/usr/bin/env", "RAYON_NUM_THREADS=8",
                   "OPENBLAS_NUM_THREADS=1", "HL_R14_DD=1", "HL_R14_REGRESSION=" + case,
                   "HL_R14_ATTACK_OUTPUT=" + str(fixture), str(binary), prior.TEST,
                   "--exact", "--ignored", "--nocapture", "--test-threads=1"]
        record = out / (case + ".command.json")
        assert not record.exists()
        record.write_text(json.dumps({"command": command, "source": pin["tree_sha256"],
                                      "binary_sha256": sha(binary), "runner_sha256": sha(Path(__file__))}, indent=2) + "\n")
        result = subprocess.run(command, cwd=ROOT)
        check()
        if result.returncode:
            sys.exit(result.returncode)
        log = (out / (case + ".log")).read_text()
        assert "1 passed; 0 failed" in log
        assert ("R14_ATTACK_REFUSAL " + case + ":" in log) != expected
        assert "R14_DICTIONARY_COUNT_TUPLES alias=" + str(expected).lower() in log
        receipts = [json.loads(line.split("R14_MALICIOUS_RECEIPT ", 1)[1]) for line in log.splitlines() if "R14_MALICIOUS_RECEIPT " in line]
        assert len(receipts) == 1
        receipt = receipts[0]
        assert receipt["expected_accept"] == expected and receipt["canonical_frame_decoded"] and receipt["native_verifier_used"]
        assert (fixture / "segment0.bin").stat().st_size == receipt["bytes"]
        row = {"label": label, "case": case, "dd": True, "source": pin["tree_sha256"],
               "binary_sha256": sha(binary), "receipt": receipt, "fixture": str(fixture.relative_to(HERE)),
               "receipt_sha256": sha(fixture / "segment0.bin"), "guard": json.loads((out / (case + ".guard.json")).read_text())}
        records.append(row)
        (out / (case + ".result.json")).write_text(json.dumps(row, indent=2) + "\n")
        (out / (case + ".validated.done")).write_text("0\n")
    report = {"utc": datetime.now(timezone.utc).isoformat(), "base_source": original["tree_sha256"],
              "corrected_source": pin["tree_sha256"], "unchanged_math_and_codec_files": unchanged,
              "cases": retained + [records[0]], "positive_equivalent_dictionary_rows": records[1],
              "preserved_failure": "sol-r14-regression-dd-dictionary-counts-1.log",
              "original_failed_frame_retained": False,
              "final_candidate_single_source_regression_run": False, "privacy_accepted": False, "release_accepted": False,
              "scope": "50 complete canonical native T128 malicious relation receipts rejected, with exact source pins per case. Original dictionary-count mutation was a legal duplicate-zero tuple move; corrected distinct E/P tuples reject, while the explicitly retained equivalent-row control accepts. No verifier/protocol change or privacy acceptance."}
    assert len(report["cases"]) == 50
    (HERE / "NATIVE_RELATION_REGRESSIONS.json").write_text(json.dumps(report, indent=2) + "\n")
    (HERE / "NATIVE_RELATION_REGRESSIONS.done").write_text("0\n")
    (out / "ACCEPTANCE.json").write_text(json.dumps(report, indent=2) + "\n")
    (out / "ACCEPTANCE.done").write_text("0\n")
    print("Native R14 relation regressions PASS50/0 plus accepted equivalent-row dictionary control")

if __name__ == "__main__":
    main()
