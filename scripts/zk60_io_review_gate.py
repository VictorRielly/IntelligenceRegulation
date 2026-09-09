#!/usr/bin/env python3
"""Fail-closed entry point for the archived O8 linear analysis (not a ZK theorem)."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

import zk60_opus_io_capture as opus

ROOT = Path(__file__).resolve().parents[1]


def require(ok, message):
    if not ok:
        raise ValueError(message)


def check_report(report, expected_proofs):
    pre = report["preflight"]
    require(pre["pass"] is True and bool(pre["checks"])
            and all(c["pass"] is True for c in pre["checks"]), "failed analysis preflight")
    require(not report["refused"], "refused captures")
    for key in ("captures", "cases"):
        items = report[key]
        require(len(items) == 4 and {c["proof_sha256"] for c in items} == expected_proofs,
                "incomplete or duplicate " + key)
        require(Counter(c["privacy"] for c in items) == {"P1": 2, "P3": 2}, "privacy coverage")
    require(report["verdict"]["controls_all_pass"] is True, "model control failure")
    for mode in ("P1", "P3"):
        battery = report["controls"]["ingestion_negatives_" + mode]
        require(battery["count"] == len(battery["controls"]) == 30
                and battery["all_rejected"] is True
                and all(c["rejected"] is True for c in battery["controls"]),
                "ingestion control failure: " + mode)
    require(report["full_privacy_review_complete"] is False and report["u2_closed"] is False,
            "unsupported privacy acceptance")


def run(captures, manifest):
    # Bind archived imports and current Rust to their recorded hashes. Preserve
    # the original O8 tool/result; this wrapper owns the stricter acceptance rule.
    archived = json.loads((ROOT / "results/zk60_opus_io_capture_analysis.json").read_text())
    producer = json.loads((ROOT / "results/zk60_round19_validation.json").read_text())
    pins = {"scripts/" + p: d for p, d in archived["tool_sha256"].items()}
    pins.update(producer["source_sha256"])
    for path, digest in pins.items():
        require(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest,
                "changed analysis dependency: " + path)
    pre = opus.preflight(str(captures), str(manifest), log=lambda *args: None)
    require(pre["pass"] is True and bool(pre["checks"])
            and all(c["pass"] is True for c in pre["checks"]), "failed input preflight")
    expected = set(opus.load_manifest(str(manifest))["entries"])
    require(len(expected) == 4, "expected four distinct receipts")
    report = opus.analyze(str(captures), str(manifest), None)
    check_report(report, expected)
    report["integration_gate"] = {
        "status": "passed", "source_sha256": producer["source_sha256"],
        "gate_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "runner": "Codex integration; archived O8 model unchanged",
        "historical_capture_reproduction_claimed": False,
    }
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = run(args.captures, args.manifest)
        # Refuse to replace an existing accepted artifact on a later invocation.
        with args.out.open("x") as stream:
            json.dump(result, stream, indent=2)
            stream.write("\n")
    except (ValueError, KeyError, TypeError, OSError, opus.C.CaptureError) as error:
        print("REFUSED:", error)
        return 1
    print("PASS: four digest-bound captures, joint model and 60 ingestion controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
