"""Capture and check both verified actual full26 artifacts; no privacy approval."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "full26-captures-1"
GUARD = ROOT / "scripts/zk60_resource_guard.py"
EXPORT = ROOT / "results/zk60_shieldstral_export_20261026/native_low_h24_t128"
TEST = "private_block::trained_block::split_cli::tests::split_cli_actual_full26_native_capture_and_rejected_bundle_suppression"

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
    build_path = HERE / "final-validation-1/ACCEPTANCE.json"
    native_path = HERE / "full26-native-1/ACCEPTANCE.json"
    assert native_path.with_suffix(".done").read_text().strip() == "0"
    native = json.loads(native_path.read_text())
    build = json.loads(build_path.read_text())
    pin_path = HERE / "sol-r14-final-build-1.source.json"
    pin = json.loads(pin_path.read_text())
    assert native["source"] == build["source"] == pin["tree_sha256"]
    tree = HERE / "checkpoints/final-build-1/tree"
    binary = HERE / "checkpoints/final-build-1/hashline.test.bin"
    scripts = ["capture_contract_v4.py", "validate_capture_v4.py", "native_mask_checks_v4.py",
               "native_claim_checks_v4.py", "local_row_rank_v4.py", Path(__file__).name]
    script_pins = {name: sha(HERE / name) for name in scripts}
    fixed = {p: sha(p) for p in [build_path, native_path, pin_path]}
    records = []
    OUT.mkdir()
    def check():
        assert sha(GUARD) == "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
        assert sha(binary) == build["test_binary_sha256"]
        for path, want in fixed.items():
            assert sha(path) == want
        for name, want in script_pins.items():
            assert sha(HERE / name) == want
        for name, want in pin["files"].items():
            assert sha(tree / name) == want, name
        assert not (HERE / "HOLD").exists() and not (HERE.parent / "HOLD").exists()
    def run(name, command, job_class, need, cap):
        check()
        wrapped = [sys.executable, str(GUARD), "run", "--class", job_class,
                   "--label", "sol-r14-full26-" + name + "-1", "--need-gib", str(need), "--cap-gib", str(cap),
                   "--wait-secs", "21600", "--max-secs", "1800", "--log", str(OUT / (name + ".log")),
                   "--done", str(OUT / (name + ".done")), "--result-json", str(OUT / (name + ".guard.json")),
                   "--", "/usr/bin/env", "OPENBLAS_NUM_THREADS=1", "OMP_NUM_THREADS=1", *command]
        save(OUT / (name + ".command.json"), {"command": wrapped, "source": pin["tree_sha256"],
             "binary_sha256": build["test_binary_sha256"], "script_sha256": script_pins})
        result = subprocess.run(wrapped, cwd=ROOT)
        check()
        if result.returncode:
            sys.exit(result.returncode)
        guard = json.loads((OUT / (name + ".guard.json")).read_text())
        assert guard["exit"] == guard["child_rc"] == 0 and not guard["guard_killed"]
        records.append({"name": name, "guard": guard, "log_sha256": sha(OUT / (name + ".log"))})
        save(OUT / "PROGRESS.json", records)
        return (OUT / (name + ".log")).read_text()
    summaries = []
    for row in native["modes"]:
        dd = row["dd"]
        mode = "dd" if dd else "non-dd"
        artifact = HERE / row["artifact"]
        for segment in row["segments"]:
            assert sha(artifact / f"segment-{segment['index']:03}.bin") == segment["sha256"]
        bundle = OUT / mode
        log = run(mode + "-capture", ["/usr/bin/env", "RAYON_NUM_THREADS=8", "HL_R14_DD=" + str(int(dd)),
            "HL_R14_CAPTURE_EXPORT=" + str(EXPORT), "HL_R14_CAPTURE_ARTIFACT=" + str(artifact),
            "HL_R14_CAPTURE_OUTPUT=" + str(bundle), "HL_R14_CAPTURE_EXPECT_MODEL=" + row["statement_identity"],
            "HL_R14_CAPTURE_EXPECT_BINDING=" + row["binding"], str(binary), TEST,
            "--exact", "--ignored", "--nocapture", "--test-threads=1"], "cpu", 5.1, 7)
        assert "1 passed; 0 failed" in log
        events = [json.loads(line.split("R14_FULL26_NATIVE_CAPTURE ", 1)[1]) for line in log.splitlines()
                  if "R14_FULL26_NATIVE_CAPTURE " in line]
        assert len(events) == 1
        event = events[0]
        assert event["dd"] == dd and event["stages"] == 26 and event["test_synthetic_waiver"] is False
        assert event["accepted_without_observer"] is True and event["rejected_bundle_suppressed"] is True
        assert event["group_counts"].count(3) == 12 and event["group_counts"].count(4) == 14
        (OUT / (mode + "-capture.validated.done")).write_text("0\n")
        common = ["--source-pin", str(pin_path), "--source-tree", str(tree), "--expected-blocks", "26"]
        checked = {}
        for kind, script in [("transport", "validate_capture_v4.py"), ("mask", "native_mask_checks_v4.py"),
                             ("claims", "native_claim_checks_v4.py"), ("local-rows", "local_row_rank_v4.py")]:
            output = OUT / (mode + "-" + kind + ".json")
            args = ([str(bundle), str(output)] if kind in ["transport", "local-rows"] else
                    ["--bundle", str(bundle), "--output", str(output)])
            name = mode + "-" + kind
            run(name, [sys.executable, str(HERE / script), *args, *common], "light", 0.8, 1.5)
            report = json.loads(output.read_text())
            assert report["source"] == pin["tree_sha256"]
            if kind == "transport":
                assert report["stages"] == len(report["receipts"]) == 26
                assert len(report["observations"]) == 79
            elif kind == "local-rows":
                assert len(report["roles"]) == 79 and report["privacy_acceptance"] is False
            else:
                assert len(report["stages"]) == 26 and report["privacy_acceptance"] is False
                if kind == "claims":
                    assert report["peak_cached_stage_json"] <= 2
            checked[kind] = {"file": output.name, "sha256": sha(output)}
            (OUT / (name + ".validated.done")).write_text("0\n")
        summaries.append({"dd": dd, "capture": event, "checks": checked,
                          "array_bytes": (bundle / "arrays.bin").stat().st_size,
                          "run_sha256": sha(bundle / "run.json")})
        print(mode, "full26 capture/transport/M/claim/local-row gates PASS", flush=True)
    save(OUT / "ACCEPTANCE.json", {"utc": datetime.now(timezone.utc).isoformat(), "source": pin["tree_sha256"],
         "binary_sha256": build["test_binary_sha256"], "script_sha256": script_pins,
         "native_acceptance_sha256": fixed[native_path], "modes": summaries, "cases": records,
         "privacy_accepted": False,
         "scope": "Actual public S2 model and numerical fixture, all26 native stages DD/nonDD with strict model/binding. Verification with/without observer consumes identical receipts; canonical native tamper cannot export a bundle. V4 transport, exact captured M functionals/budgets, private claim provenance/public gates and local row-mask precheck pass. Does not reconstruct complete host polynomials, global H/column/joint rank, CFS lemma or NL1; independent security/privacy review and registration remain required."})
    (OUT / "ACCEPTANCE.done").write_text("0\n")

if __name__ == "__main__":
    main()
