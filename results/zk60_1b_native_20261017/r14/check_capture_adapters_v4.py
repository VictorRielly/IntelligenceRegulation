"""Regress stage/source-parameterized capture checkers on retained native views."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "capture-adapters-v4"
GUARD = ROOT / "scripts/zk60_resource_guard.py"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assert not OUT.exists()
    OUT.mkdir()
    pin = HERE / "sol-r14-capture-build-1.source.json"
    tree = HERE / "checkpoints/capture-build-1/tree"
    records = []
    scripts = ["capture_contract_v4.py", "validate_capture_v4.py", "native_mask_checks_v4.py",
               "native_claim_checks_v4.py", "local_row_rank_v4.py", "test_capture_streams_v4.py"]
    pins = {name: sha(HERE / name) for name in scripts}
    for mode in ["non-dd", "dd"]:
        bundle = HERE / "native-captures" / mode
        common = ["--source-pin", str(pin), "--source-tree", str(tree), "--expected-blocks", "3"]
        for kind, script in [("transport", "validate_capture_v4.py"), ("mask", "native_mask_checks_v4.py"),
                             ("claims", "native_claim_checks_v4.py"), ("local-rows", "local_row_rank_v4.py")]:
            name = mode + "-" + kind
            result_path = OUT / (name + ".json")
            if kind in ["transport", "local-rows"]:
                args = [str(bundle), str(result_path), *common]
            else:
                args = ["--bundle", str(bundle), "--output", str(result_path), *common]
            command = [sys.executable, str(GUARD), "run", "--class", "light", "--label", "sol-r14-capture-v4-" + name,
                "--need-gib", "0.8", "--cap-gib", "1.5", "--wait-secs", "21600", "--max-secs", "600",
                "--log", str(OUT / (name + ".log")), "--done", str(OUT / (name + ".done")),
                "--result-json", str(OUT / (name + ".guard.json")), "--", "/usr/bin/env", "OPENBLAS_NUM_THREADS=1",
                "OMP_NUM_THREADS=1", sys.executable, str(HERE / script), *args]
            assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
            for source, want in pins.items():
                assert sha(HERE / source) == want
            (OUT / (name + ".command.json")).write_text(json.dumps({"command": command, "script_sha256": pins}, indent=2) + "\n")
            result = subprocess.run(command, cwd=ROOT)
            if result.returncode:
                sys.exit(result.returncode)
            current = json.loads(result_path.read_text())
            if kind == "transport":
                previous = json.loads((HERE / f"NATIVE_CAPTURE_{mode}_VALIDATION_v3.json").read_text())
                for field in ["source", "array_objects", "array_bytes", "observations", "receipts", "keys"]:
                    assert current[field] == previous[field], field
            elif kind == "mask":
                previous = json.loads((HERE / f"NATIVE_MASK_{mode}_v3.json").read_text())
                for field in ["stages", "message_positions", "encoding_domain_positions", "random_pad_positions_per_mask_row"]:
                    assert current[field] == previous[field], field
            elif kind == "claims":
                previous = json.loads((HERE / f"NATIVE_CLAIMS_{mode}_v3.json").read_text())
                for field in ["stages", "published_claims_checked", "exclusive_site_pairs_checked"]:
                    assert current[field] == previous[field], field
                assert current["peak_cached_stage_json"] <= 2
            else:
                previous = json.loads((HERE / f"LOCAL_ROW_PRECHECK_{mode}_v3.json").read_text())
                assert current["roles"] == previous["roles"]
            records.append({"name": name, "guard": json.loads((OUT / (name + ".guard.json")).read_text()),
                            "report_sha256": sha(result_path), "previous_result_matched": True})
            (OUT / (name + ".validated.done")).write_text("0\n")
            print(name, "PASS baseline unchanged", flush=True)
    (OUT / "ACCEPTANCE.json").write_text(json.dumps({"utc": datetime.now(timezone.utc).isoformat(),
        "script_sha256": pins, "cases": records, "scope": "Version4 checkers reproduce all retained3stage DD/nonDD transport, mask, claim and local-row results while taking an explicit trusted source/stage contract; claim JSON cache holds at most2 stages. Full26 and privacy acceptance remain separate.",
        "privacy_accepted": False}, indent=2) + "\n")
    (OUT / "ACCEPTANCE.done").write_text("0\n")
    print("Capture version4 baseline regression PASS8/0", flush=True)

if __name__ == "__main__":
    main()
