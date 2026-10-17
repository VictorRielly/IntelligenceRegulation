#!/usr/bin/env python3
"""Audit retained A/B records and summarize observations; does not run proofs."""
import hashlib
import json
from pathlib import Path
import statistics

HERE = Path(__file__).resolve().parent
OUT = HERE / "dense-ab-1"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    comparison = json.loads((OUT / "comparison.json").read_text())
    assert comparison["state"] == "passed"
    assert (OUT / "run.done").read_text().strip() == "0"
    assert digest(HERE / "benchmark.py") == comparison["runner_sha256"]
    assert len(comparison["runs"]) == 6
    rows = []
    for run in comparison["runs"]:
        log = OUT / (run["name"] + ".log")
        assert digest(log) == run["log_sha256"], log
        text = log.read_text()
        assert run["exit_code"] == 0 and "1 passed; 0 failed" in text
        assert run["receipt_bytes"] == 40_783_352
        phases = {}
        for line in text.splitlines():
            if line.startswith("PB-TIMING prove |"):
                fields = [field.strip() for field in line.split("|")]
                if len(fields) > 3:
                    try:
                        phases[fields[1]] = float(fields[3])
                    except ValueError:
                        pass
        prove = phases["WALL CLOCK OF THE CALL"]
        serialization = phases["encode to bytes (wire::encode)"]
        softmax = [v for k, v in phases.items() if k.startswith("slot 17 ")]
        assert len(softmax) == 1
        rows.append({**run, "prove_phase_seconds": prove,
                     "serialization_seconds": serialization,
                     "softmax_slot_seconds": softmax[0],
                     "known_witness_prove_serialization_seconds":
                         run["witness_seconds"] + prove + serialization})
    measures = ("prove_phase_seconds", "softmax_slot_seconds", "wall_seconds",
                "known_witness_prove_serialization_seconds")
    means = {arm: {key: statistics.mean(r[key] for r in rows if r["arm"] == arm)
                   for key in measures} for arm in ("old", "new")}
    summary = {
        "state": "passed",
        "comparison_sha256": digest(OUT / "comparison.json"),
        "summarizer_sha256": digest(Path(__file__)),
        "six_log_hashes_and_runner_hash_verified": True,
        "runs": rows, "non_warm_samples_per_arm": 2,
        "non_warm_means": means,
        "observed_time_reduction_percent": {
            key: 100 * (1 - means["new"][key] / means["old"][key]) for key in measures},
        "scope": "Shared two-thread CPU, one synthetic dense 125M-geometry block, T512; same binary with fusion off/on in separate processes",
        "limits": ["Small-slot test oracles included in the test binary",
                   "Two samples per arm; no statistical confidence or p95 claim",
                   "Known phase sum is not an enclosing end-to-end request clock",
                   "Process wall includes verification and other test work",
                   "No GPU, trained 8B, larger privacy acceptance or integration claim"],
    }
    (OUT / "measured-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"state": summary["state"], "means": means,
                      "observed_time_reduction_percent": summary["observed_time_reduction_percent"]}, indent=2))


if __name__ == "__main__":
    main()
