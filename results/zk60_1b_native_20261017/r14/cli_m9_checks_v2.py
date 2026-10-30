"""Native publication-race checks against retained unverified actual-L25 CLI runs."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TREE = HERE / "cli-candidate-working-tree"
NATIVE = HERE / "cli-native-2"
GUARD = ROOT / "scripts/zk60_resource_guard.py"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assert (NATIVE / "ACCEPTANCE.done").read_text().strip() == "0"
    pin = json.loads((HERE / "sol-r14-cli-build-2.source.json").read_text())
    build = json.loads((HERE / "CLI_BUILD_ACCEPTANCE_2.json").read_text())
    assert build["source"] == pin["tree_sha256"]
    binary = HERE / "checkpoints/cli-build-2/hashline.test.bin"
    def check():
        assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
        assert sha(binary) == build["test_binary_sha256"]
        for name, want in pin["files"].items():
            assert sha(TREE / name) == want
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()
    records = []
    for dd in [False, True]:
        check()
        mode = "dd" if dd else "non-dd"
        name = mode + "-m9"
        label = "sol-r14-cli-2-" + name
        command = [sys.executable, str(GUARD), "run", "--class", "cpu", "--label", label,
                   "--need-gib", "2.5", "--cap-gib", "5", "--wait-secs", "21600", "--max-secs", "1200",
                   "--log", str(NATIVE / (name + ".log")), "--done", str(NATIVE / (name + ".done")),
                   "--result-json", str(NATIVE / (name + ".guard.json")), "--", "/usr/bin/env",
                   "RAYON_NUM_THREADS=8", "OPENBLAS_NUM_THREADS=1", "HL_R14_DD=" + str(int(dd)),
                   "HL_R14_CLI_ARTIFACT=" + str(NATIVE / (mode + "-m9-input")),
                   "HL_R14_CLI_EXPORT=" + str(ROOT / "results/zk60_shieldstral_export_20261026/native_low_h24_t128"),
                   "HL_R14_CLI_M9_OUTPUT=" + str(NATIVE / (mode + "-m9-controls")), str(binary),
                   "private_block::trained_block::split_cli::tests::split_cli_publication_names_only_the_segment_bytes_consumed_by_verification",
                   "--exact", "--ignored", "--nocapture", "--test-threads=1"]
        record = NATIVE / (name + ".command.json")
        assert not record.exists()
        record.write_text(json.dumps({"command": command, "source": pin["tree_sha256"],
                                      "binary_sha256": sha(binary), "runner_sha256": sha(Path(__file__))}, indent=2) + "\n")
        result = subprocess.run(command, cwd=ROOT)
        check()
        if result.returncode:
            sys.exit(result.returncode)
        log = (NATIVE / (name + ".log")).read_text()
        assert "1 passed; 0 failed" in log
        assert "R14_CLI_M9 consumed_hash_publication_and_manifest_rewrite_refusal PASS" in log
        row = {"dd": dd, "guard": json.loads((NATIVE / (name + ".guard.json")).read_text()),
               "log_sha256": sha(NATIVE / (name + ".log"))}
        records.append(row)
        (NATIVE / (name + ".validated.done")).write_text("0\n")
    report = {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"], "cases": records,
              "scope": "Native experimental CLI DD/nonDD actual-L25 publication controls: a post-verify segment+manifest rewrite refuses without publication; a segment-only swap publishes the consumed hash, then fresh verification rejects until restored. No full26/privacy/release acceptance."}
    (NATIVE / "M9_ACCEPTANCE.json").write_text(json.dumps(report, indent=2) + "\n")
    (NATIVE / "M9_ACCEPTANCE.done").write_text("0\n")
    print("Experimental R14 CLI native publication-race gates PASS2/0")

if __name__ == "__main__":
    main()
