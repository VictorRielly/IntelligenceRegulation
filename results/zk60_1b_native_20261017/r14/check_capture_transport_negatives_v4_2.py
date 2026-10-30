"""Streaming and explicit-contract negative controls on retained native captures."""
from pathlib import Path
import copy
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
BUNDLE = HERE / "native-captures/non-dd"
VALIDATOR = HERE / "validate_capture_v4.py"
OUTPUT = HERE / "CAPTURE_TRANSPORT_NEGATIVES_v4_2.json"
assert not OUTPUT.exists()
PIN = HERE / "sol-r14-capture-build-1.source.json"
TREE = HERE / "checkpoints/capture-build-1/tree"
validator_hash = hashlib.sha256(VALIDATOR.read_bytes()).hexdigest()
run = json.loads((BUNDLE / "run.json").read_text())
stage = json.loads((BUNDLE / "stage0.json").read_text())
results = []
cases = ["unknown-key", "binding", "component-tag", "logup-word", "source-pin", "receipt-middle",
         "duplicate-source-pin", "missing-source-pin", "wrong-stage-count", "wrong-trusted-source"]
for case in cases:
    with tempfile.TemporaryDirectory(prefix="transport-negative-v4-", dir=HERE) as tmp:
        tmp = Path(tmp)
        for source in BUNDLE.iterdir():
            (tmp / source.name).symlink_to(source)
        pin, tree, blocks = PIN, TREE, "3"
        if case == "logup-word":
            value = copy.deepcopy(stage)
            value["logup"][0][1] = (1 << 64) - (1 << 32) + 1
            path = tmp / "stage0.json"
            path.unlink()
            path.write_text(json.dumps(value))
        elif case == "receipt-middle":
            path = tmp / "segment0.bin"
            path.unlink()
            shutil.copyfile(BUNDLE / "segment0.bin", path)
            with path.open("r+b") as frame:
                frame.seek(90001)
                byte = frame.read(1)
                frame.seek(90001)
                frame.write(bytes([byte[0] ^ 1]))
        elif case == "wrong-stage-count":
            blocks = "26"
        elif case == "wrong-trusted-source":
            pin = HERE / "sol-r14-final-build-1.source.json"
            tree = HERE / "checkpoints/final-build-1/tree"
        else:
            value = copy.deepcopy(run)
            if case == "unknown-key":
                value["unapproved_private_plane"] = []
            elif case == "binding":
                value["binding"][0] ^= 1
            elif case == "component-tag":
                value["profiles"][0]["physical_planes"][0]["cm"] = 2
            elif case == "source-pin":
                value["source_pins"][0]["sha256"] = "0" * 64
            elif case == "duplicate-source-pin":
                value["source_pins"].append(copy.deepcopy(value["source_pins"][0]))
            elif case == "missing-source-pin":
                value["source_pins"].pop()
            path = tmp / "run.json"
            path.unlink()
            path.write_text(json.dumps(value))
        result = subprocess.run([sys.executable, str(VALIDATOR), str(tmp), str(tmp / "result.json"),
                                 "--source-pin", str(pin), "--source-tree", str(tree),
                                 "--expected-blocks", blocks], capture_output=True, text=True, timeout=60)
        assert result.returncode != 0 and not (tmp / "result.json").exists(), case
        assert "AssertionError" in result.stderr, (case, result.stderr[-1000:])
        assert hashlib.sha256(VALIDATOR.read_bytes()).hexdigest() == validator_hash
        results.append({"case": case, "exit": result.returncode, "result_emitted": False,
                        "stderr_sha256": hashlib.sha256(result.stderr.encode()).hexdigest()})
OUTPUT.write_text(json.dumps({"validator_sha256": validator_hash, "cases": results,
    "scope": "Ten transport/source/stage-contract controls reject without emitting acceptance. Public synthetic retained3stage bundle. Not native mathematical forgery or privacy acceptance.",
    "privacy_accepted": False}, indent=2) + "\n")
print(json.dumps({"transport_negatives": len(results), "rejected": len(results)}))
