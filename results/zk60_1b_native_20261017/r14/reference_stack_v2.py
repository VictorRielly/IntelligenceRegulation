"""Resumable, source-pinned independent reference for all26 actual S2 layers.

Every heavy leaf is one exact-int64 layer under the shared guard. A failed
recorded leaf requires diagnosis and a new attempt, never a blind retry.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import math
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / "reference-stack-2"
GUARD = ROOT / "scripts/zk60_resource_guard.py"
STEP = HERE / "reference_sequence_step_v2.py"
REFERENCE = ROOT / "results/zk60_d24_review_20261017/r13/reviewer_export_reference.py"
PROFILE = ROOT / "results/zk60_shieldstral_export_20261026/native_low_h24_t128/profile.json"
NATIVE = HERE / "ACTUAL_S2_NATIVE_ACCEPTANCE.json"
GUARD_SHA = "67e9478f55518c2808ff65e5f303f70e155a5f21c5987243a39cf579d1a9a6f3"
REFERENCE_SHA = "d7c175e154cef761e7e574e417c6979634e05243e6abf0357fb3cb2c7cdfe4ac"
PROFILE_SHA = "2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0"

def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for data in iter(lambda: stream.read(1 << 20), b""):
            h.update(data)
    return h.hexdigest()

def save(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--through-layer", type=int, default=0)
    args = parser.parse_args()
    assert 0 <= args.through_layer < 26
    assert sha(GUARD) == GUARD_SHA and sha(REFERENCE) == REFERENCE_SHA and sha(PROFILE) == PROFILE_SHA
    OUT.mkdir(exist_ok=True)
    contract_path = OUT / "CONTRACT.json"
    pins = {str(p.relative_to(ROOT)): sha(p) for p in [GUARD, STEP, REFERENCE, PROFILE, NATIVE, HERE / "reference-stack-1/layer_00.json", Path(__file__)]}
    if contract_path.exists():
        contract = json.loads(contract_path.read_text())
        assert contract["source_sha256"] == pins
    else:
        contract = {"utc": datetime.now(timezone.utc).isoformat(), "source_sha256": pins,
                    "geometry": {"tokens": 128, "width": 3072, "hidden": 9216, "layers": 26},
                    "resource": {"first_layer_class": "cpu", "first_layer_need_gib": 2.6, "first_layer_cap_gib": 5, "later_policy": "ceil((measured L00 peak +0.15GiB)*10)/10; light only ifneed<=1GiB, all numerical threads1; otherwisecpu", "max_secs_per_layer": 1800},
                    "scope": "Actual public S2 weights; explicit public sparse input; unchanged independent reviewer int64 reference. No native full26 proof, classifier, or privacy acceptance."}
        save(contract_path, contract)
    profile = json.loads(PROFILE.read_text())
    assert len(profile["layers"]) == 26
    records = []
    def check():
        for name, want in pins.items():
            assert sha(ROOT / name) == want, name
    def validate(k):
        label = f"sol-r14-reference2-L{k:02}-1"
        assert (OUT / (label + ".done")).read_text().strip() == "0"
        guard = json.loads((OUT / (label + ".guard.json")).read_text())
        assert guard["exit"] == guard["child_rc"] == 0 and not guard["guard_killed"]
        report_path = OUT / f"layer_{k:02}.json"
        report = json.loads(report_path.read_text())
        assert report["layer"] == k and report["profile_sha256"] == PROFILE_SHA
        assert report["reference_sha256"] == REFERENCE_SHA and report["script_sha256"] == sha(STEP)
        assert report["manifest_sha256"] == profile["layers"][k]["manifest_sha256"]
        assert len(report["traces"]) == len({row["site"] for row in report["traces"]}) == 19
        for kind in ["input", "output"]:
            path = OUT / f"x_{'in' if kind == 'input' else 'out'}_L{k:02}.bin"
            assert path.stat().st_size == 128 * 3072 * 2
            assert sha(path) == report[kind + "_sha256"]
        if k:
            previous_path = OUT / f"layer_{k-1:02}.json"
            previous = json.loads(previous_path.read_text())
            assert report["previous_report_sha256"] == sha(previous_path)
            assert report["input_sha256"] == previous["output_sha256"]
        if k == 0:
            baseline = json.loads((HERE / "reference-stack-1/layer_00.json").read_text())
            assert {row["site"]: row["sha256"] for row in report["traces"]} == {row["site"]: row["sha256"] for row in baseline["traces"]}
            assert report["input_sha256"] == baseline["input_sha256"] and report["output_sha256"] == baseline["output_sha256"]
        return {"layer": k, "label": label, "report_sha256": sha(report_path),
                "input_sha256": report["input_sha256"], "output_sha256": report["output_sha256"], "guard": guard}
    for k in range(args.through_layer + 1):
        check()
        label = f"sol-r14-reference2-L{k:02}-1"
        validated = OUT / (label + ".validated.done")
        if validated.exists():
            assert validated.read_text().strip() == "0"
            records.append(validate(k))
            continue
        command_path = OUT / (label + ".command.json")
        assert not command_path.exists(), "recorded incomplete/failed leaf: inspect original handle/result before a new attempt"
        while (HERE / "HOLD").exists() or (HERE.parent / "HOLD").exists():
            check()
            print(datetime.now(timezone.utc).isoformat(), label, "waiting for hold", flush=True)
            time.sleep(10)
        job_class, need, cap = "cpu", 2.6, 5
        if k:
            measured = records[0]["guard"]["peak_rss_gib"]
            assert measured > 0, "missing memory measurement cannot justify a smaller admission"
            need = math.ceil((measured + 0.15) * 10) / 10
            cap = max(1.5, need + 0.7)
            if need <= 1:
                job_class = "light"
        command = [sys.executable, str(GUARD), "run", "--class", job_class, "--label", label,
                   "--need-gib", str(need), "--cap-gib", str(cap), "--wait-secs", "21600", "--max-secs", "1800",
                   "--log", str(OUT / (label + ".log")), "--done", str(OUT / (label + ".done")),
                   "--result-json", str(OUT / (label + ".guard.json")), "--", "/usr/bin/env",
                   "OPENBLAS_NUM_THREADS=1", "OMP_NUM_THREADS=1", "MKL_NUM_THREADS=1",
                   sys.executable, str(STEP), "--layer", str(k), "--output", str(OUT),
                   "--reference-sha256", REFERENCE_SHA]
        save(command_path, {"command": command, "contract_sha256": sha(contract_path), "runner_sha256": sha(Path(__file__))})
        result = subprocess.run(command, cwd=ROOT)
        check()
        if result.returncode:
            sys.exit(result.returncode)
        row = validate(k)
        records.append(row)
        save(OUT / (label + ".result.json"), row)
        validated.write_text("0\n")
        save(OUT / "PROGRESS.json", {"utc": datetime.now(timezone.utc).isoformat(), "completed_layers": records})
        print(label, "PASS19sites", flush=True)
    if args.through_layer == 25:
        arrays = {}
        for k in range(26):
            for kind in ["in", "out"]:
                name = f"x_{kind}_L{k:02}"
                path = OUT / (name + ".bin")
                arrays[name] = {"file": path.name, "dtype": "int16", "shape": [128, 3072], "sha256": sha(path)}
        save(OUT / "manifest.json", {"arrays": arrays})
        save(OUT / "ACCEPTANCE.json", {"utc": datetime.now(timezone.utc).isoformat(), "contract_sha256": sha(contract_path),
             "layers": records, "manifest_sha256": sha(OUT / "manifest.json"), "native_full_stack_proved": False,
             "privacy_accepted": False, "scope": contract["scope"]})
        (OUT / "ACCEPTANCE.done").write_text("0\n")
        print("All26 independent exact-integer reference layers PASS; native proof still required", flush=True)

if __name__ == "__main__":
    main()
