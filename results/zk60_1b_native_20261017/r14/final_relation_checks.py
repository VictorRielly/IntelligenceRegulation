"""Rerun all relation receipts on the one final source and binary."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys
import regression_checks_direct as cases

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "final-relations-1"
GUARD = ROOT / "scripts/zk60_resource_guard.py"
GUARD_SHA = "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")

def main():
    build = json.loads((HERE / "final-validation-1/ACCEPTANCE.json").read_text())
    assert (HERE / "final-validation-1/ACCEPTANCE.done").read_text().strip() == "0"
    pin = json.loads((HERE / "sol-r14-final-build-1.source.json").read_text())
    tree = HERE / "checkpoints/final-build-1/tree"
    binary = HERE / "checkpoints/final-build-1/hashline.test.bin"
    binary_sha = sha(binary)
    assert binary_sha == build["test_binary_sha256"] and pin["tree_sha256"] == build["source"]
    assert not OUT.exists()
    OUT.mkdir()
    source_pins = {p.name: sha(p) for p in [Path(__file__), HERE / "regression_checks_direct.py"]}
    def check():
        assert sha(GUARD) == GUARD_SHA and sha(binary) == binary_sha
        for name, want in pin["files"].items():
            assert sha(tree / name) == want, name
        for name, want in source_pins.items():
            assert sha(HERE / name) == want, name
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()
    records = []
    all_cases = [case for group in cases.GROUPS.values() for case in group]
    assert len(all_cases) == len(set(all_cases)) == 50
    for dd, case in [*all_cases, (True, "dictionary-alias-counts")]:
        expected_accept = case == "dictionary-alias-counts"
        mode = "dd" if dd else "non-dd"
        name = mode + "-" + case
        fixture = OUT / "receipts" / name
        label = "sol-r14-final-relation-" + name + "-1"
        command = [sys.executable, str(GUARD), "run", "--class", "cpu", "--label", label,
                   "--need-gib", "7.5", "--cap-gib", "10", "--wait-secs", "21600", "--max-secs", "1200",
                   "--log", str(OUT / (name + ".log")), "--done", str(OUT / (name + ".done")),
                   "--result-json", str(OUT / (name + ".guard.json")), "--", "/usr/bin/env",
                   "RAYON_NUM_THREADS=8", "OPENBLAS_NUM_THREADS=1", "HL_R14_DD=" + str(int(dd)),
                   "HL_R14_REGRESSION=" + case, "HL_R14_ATTACK_OUTPUT=" + str(fixture),
                   str(binary), cases.TEST, "--exact", "--ignored", "--nocapture", "--test-threads=1"]
        check()
        save(OUT / (name + ".command.json"), {"command": command, "source": pin["tree_sha256"],
             "binary_sha256": binary_sha, "runner_source_sha256": source_pins})
        result = subprocess.run(command, cwd=ROOT)
        check()
        if result.returncode:
            sys.exit(result.returncode)
        log = (OUT / (name + ".log")).read_text()
        assert "1 passed; 0 failed" in log
        assert ("R14_ATTACK_REFUSAL " + case + ":" in log) != expected_accept
        receipt = [json.loads(line.split("R14_MALICIOUS_RECEIPT ", 1)[1]) for line in log.splitlines()
                   if "R14_MALICIOUS_RECEIPT " in line]
        assert len(receipt) == 1
        receipt = receipt[0]
        assert receipt["dd"] == dd and receipt["case"] == case
        assert receipt["expected_accept"] is expected_accept
        assert receipt["canonical_frame_decoded"] and receipt["native_verifier_used"]
        frame = fixture / "segment0.bin"
        assert frame.stat().st_size == receipt["bytes"]
        guard = json.loads((OUT / (name + ".guard.json")).read_text())
        assert guard["exit"] == guard["child_rc"] == 0 and not guard["guard_killed"]
        row = {"case": case, "dd": dd, "receipt": receipt, "source": pin["tree_sha256"],
               "binary_sha256": binary_sha, "frame": str(frame.relative_to(HERE)),
               "receipt_sha256": sha(frame), "guard": guard}
        records.append(row)
        save(OUT / (name + ".result.json"), row)
        (OUT / (name + ".validated.done")).write_text("0\n")
        save(OUT / "PROGRESS.json", records)
        print(name, "PASS", len(records), "/51", flush=True)
    assert len(records) == 51
    save(OUT / "ACCEPTANCE.json", {"utc": datetime.now(timezone.utc).isoformat(),
         "source": pin["tree_sha256"], "binary_sha256": binary_sha, "cases": records[:50],
         "positive_equivalent_dictionary_rows": records[50], "runner_source_sha256": source_pins,
         "final_candidate_single_source_regression_run": True, "privacy_accepted": False,
         "scope": "All50 complete canonical malicious relation receipts reject on the final candidate; one equivalent dictionary-row control accepts. Public synthetic T128, DD/nonDD. Independent security review and privacy acceptance remain required."})
    (OUT / "ACCEPTANCE.done").write_text("0\n")
    print("Final-source native relation receipts PASS50 rejections plus1 accepted alias", flush=True)

if __name__ == "__main__":
    main()
