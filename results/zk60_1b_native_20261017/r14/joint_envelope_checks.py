"""Separate binding/root-ownership/transport controls for retained receipts.

These are not counted as native mathematical relation forgeries. Single-core
light admission uses retained fresh-verifier peak0.43GiB plus0.5GiB margin.
"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import shutil
import subprocess
import sys
from joint_receipt_checks import opening_len

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "joint-envelopes-1"
GUARD = ROOT / "scripts/zk60_resource_guard.py"

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")

def main():
    assert not OUT.exists()
    OUT.mkdir()
    build = json.loads((HERE / "final-validation-1/ACCEPTANCE.json").read_text())
    pin = json.loads((HERE / "sol-r14-final-build-1.source.json").read_text())
    binary = HERE / "checkpoints/final-build-1/hashline.test.bin"
    tree = HERE / "checkpoints/final-build-1/tree"
    assert build["source"] == pin["tree_sha256"]
    sources = {p.name: sha(p) for p in [Path(__file__), HERE / "joint_receipt_checks.py"]}
    records = []
    def check():
        assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
        assert sha(binary) == build["test_binary_sha256"]
        for name, want in pin["files"].items():
            assert sha(tree / name) == want
        for name, want in sources.items():
            assert sha(HERE / name) == want
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()
    def run(name, dd, artifact, category, reason):
        check()
        variant = "dd" if dd else "non_dd"
        test = "private_block::argument::split_run_tests::split_run_t128_" + variant + "_fresh_verify_from_dir"
        command = [sys.executable, str(GUARD), "run", "--class", "light", "--label", "sol-r14-envelope-" + name + "-1",
                   "--need-gib", "1", "--cap-gib", "1.5", "--wait-secs", "21600", "--max-secs", "600",
                   "--log", str(OUT / (name + ".log")), "--done", str(OUT / (name + ".done")),
                   "--result-json", str(OUT / (name + ".guard.json")), "--", "/usr/bin/env", "RAYON_NUM_THREADS=1",
                   "HL_R14_RUN_INPUT=" + str(artifact), str(binary), test, "--exact", "--ignored", "--nocapture", "--test-threads=1"]
        save(OUT / (name + ".command.json"), {"command": command, "source": pin["tree_sha256"], "script_sha256": sources,
             "resource_basis": "Retained stream fresh max0.43GiB +0.5GiB margin, rounded to1GiB; single numerical thread."})
        result = subprocess.run(command, cwd=ROOT)
        check()
        expected = 101 if reason else 0
        assert result.returncode == expected, (name, result.returncode, expected)
        log = (OUT / (name + ".log")).read_text()
        assert ("0 passed; 1 failed" if reason else "1 passed; 0 failed") in log
        if reason:
            assert reason in log, (name, log[-1000:])
        guard = json.loads((OUT / (name + ".guard.json")).read_text())
        assert guard["exit"] == guard["child_rc"] == expected and not guard["guard_killed"]
        records.append({"case": name, "category": category, "reason": reason, "expected_native_test_exit": expected,
                        "guard": guard, "log_sha256": sha(OUT / (name + ".log"))})
        save(OUT / "PROGRESS.json", records)
        (OUT / (name + ".validated.done")).write_text("0\n")
        print(name, "PASS expected acceptance/refusal", flush=True)
    for dd in [False, True]:
        mode = "dd" if dd else "non-dd"
        original = HERE / "stream-fixtures" / mode
        pins = {p.name: sha(p) for p in original.iterdir()}
        text = (original / "statement.txt").read_text()
        metadata = dict(line.split("=", 1) for line in text.splitlines()[1:])
        run(mode + "-honest", dd, original, "positive", None)
        cases = [("boundary-duplicate-endpoint-root", "root_ownership", "R14 run: repeated commitment root"),
                 ("boundary-duplicate-block-root", "root_ownership", "R14 run: repeated commitment root"),
                 ("boundary-drop-root", "transport_exact_length", "fixture file is not bounded regular exact-size input"),
                 ("endpoint-drop-opening", "transport_exact_length", "fixture file is not bounded regular exact-size input"),
                 ("endpoint-swap-roots", "statement_binding", "fixture routing binding differs"),
                 ("endpoint-duplicate-root", "root_ownership", "R14 run: repeated commitment root"),
                 ("stage-swap", "transport_exact_length", "fixture file is not bounded regular exact-size input"),
                 ("stage-duplicate", "transport_exact_length", "fixture file is not bounded regular exact-size input")]
        for case, category, reason in cases:
            name = mode + "-" + case
            artifact = OUT / name
            artifact.mkdir()
            first = bytearray((original / "segment0.bin").read_bytes())
            statement = text
            if case == "boundary-duplicate-endpoint-root":
                first[120:152] = bytes.fromhex(metadata["input_root"])
            elif case == "boundary-duplicate-block-root":
                first[120:152] = first[152:184]
            elif case == "boundary-drop-root":
                del first[120:152]
            elif case == "endpoint-drop-opening":
                del first[-32-opening_len(2, 31):-32]
            elif case == "endpoint-swap-roots":
                statement = "\n".join("input_root=" + metadata["output_root"] if line.startswith("input_root=") else
                                      "output_root=" + metadata["input_root"] if line.startswith("output_root=") else line
                                      for line in text.splitlines()) + "\n"
            elif case == "endpoint-duplicate-root":
                statement = text.replace("output_root=" + metadata["output_root"], "output_root=" + metadata["input_root"])
            elif case == "stage-swap":
                first = bytearray((original / "segment1.bin").read_bytes())
            (artifact / "statement.txt").write_text(statement)
            (artifact / "segment0.bin").write_bytes(first)
            if case in ["stage-swap", "stage-duplicate"]:
                os.link(original / "segment0.bin", artifact / "segment1.bin")
            else:
                os.link(original / "segment1.bin", artifact / "segment1.bin")
            run(name, dd, artifact, category, reason)
        assert {p.name: sha(p) for p in original.iterdir()} == pins
    assert len(records) == 18
    save(OUT / "ACCEPTANCE.json", {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"],
         "binary_sha256": build["test_binary_sha256"], "script_sha256": sources, "cases": records,
         "privacy_accepted": False, "scope": "Final-source fresh native verifier accepts2 honest retained public synthetic streams.16 endpoint/boundary duplicate/drop/swap controls refuse at explicitly classified statement binding, repeated-root ownership or exact-length transport gates. These are separate from mathematical relation attacks and keyed-Merkle opened-row attacks. No trained/full26/privacy acceptance."})
    (OUT / "ACCEPTANCE.done").write_text("0\n")

if __name__ == "__main__":
    main()
