"""Regenerate inventory, typed slot degrees and claim groups on final binary."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "final-census-1"
GUARD = ROOT / "scripts/zk60_resource_guard.py"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assert not OUT.exists()
    OUT.mkdir()
    build = json.loads((HERE / "final-validation-1/ACCEPTANCE.json").read_text())
    pin = json.loads((HERE / "sol-r14-final-build-1.source.json").read_text())
    binary = HERE / "checkpoints/final-build-1/hashline.test.bin"
    tree = HERE / "checkpoints/final-build-1/tree"
    assert build["source"] == pin["tree_sha256"]
    script_sha = sha(Path(__file__))
    def check():
        assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
        assert sha(binary) == build["test_binary_sha256"] and sha(Path(__file__)) == script_sha
        for name, want in pin["files"].items():
            assert sha(tree / name) == want
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()
    text = ""
    guards = []
    for name, test in [("inventory", "private_block::split_layout::tests::native_split_inventory_census"),
                       ("definitions", "private_block::argument::split_definition_tests::split_actual_definitions_match_all_physical_sites_sources_hosts_and_degrees")]:
        check()
        command = [sys.executable, str(GUARD), "run", "--class", "light", "--label", "sol-r14-final-census-" + name + "-1",
                   "--need-gib", "0.8", "--cap-gib", "1.5", "--wait-secs", "21600", "--max-secs", "600",
                   "--log", str(OUT / (name + ".log")), "--done", str(OUT / (name + ".done")),
                   "--result-json", str(OUT / (name + ".guard.json")), "--", "/usr/bin/env", "RAYON_NUM_THREADS=1",
                   str(binary), test, "--exact", "--nocapture", "--test-threads=1"]
        (OUT / (name + ".command.json")).write_text(json.dumps({"command": command, "source": pin["tree_sha256"],
             "binary_sha256": build["test_binary_sha256"], "runner_sha256": script_sha}, indent=2) + "\n")
        result = subprocess.run(command, cwd=ROOT)
        check()
        if result.returncode:
            sys.exit(result.returncode)
        log = (OUT / (name + ".log")).read_text()
        assert "1 passed; 0 failed" in log
        text += log
        guard = json.loads((OUT / (name + ".guard.json")).read_text())
        assert guard["exit"] == guard["child_rc"] == 0 and not guard["guard_killed"]
        guards.append(guard)
        (OUT / (name + ".validated.done")).write_text("0\n")
    report = {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"], "files": pin["count"],
              "binary_sha256": build["test_binary_sha256"], "guards": guards, "runner_sha256": script_sha}
    prior = json.loads((HERE / "NATIVE_BUILDERS_CENSUS.json").read_text())
    for field, marker, count in [("inventory", "R14_SPLIT_CENSUS ", 12), ("slot_definitions", "R14_ACTUAL_SLOT ", 126),
                                 ("groups", "R14_NATIVE_GROUPS ", 4)]:
        rows = [json.loads(line.split(marker, 1)[1]) for line in text.splitlines() if marker in line]
        assert len(rows) == count, (field, len(rows))
        assert rows == prior[field], (field, "census changed")
        report[field] = rows
    report.update(privacy_accepted=False, scope="Final compiled native inventory,126 physical slot definitions/degrees and4 claim-group schedules exactly match the retained builder census. Counted geometry, not a proof of soundness or privacy.")
    (OUT / "ACCEPTANCE.json").write_text(json.dumps(report, indent=2) + "\n")
    (OUT / "ACCEPTANCE.done").write_text("0\n")
    print("Final-source native inventory/slot/group census PASS unchanged", flush=True)

if __name__ == "__main__":
    main()
