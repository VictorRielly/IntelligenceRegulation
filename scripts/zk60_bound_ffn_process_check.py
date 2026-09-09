#!/usr/bin/env python3
"""Verify saved bound-FFN receipts in isolated CPU processes.

Public synthetic fixture only. The trusted fixture caller writes endpoint policy
before FFN proving; the verifier trusts that separate file and caller context.
No endpoint secrets cross processes. Run under the shared heavy lock.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    binary = args.binary.resolve(strict=True)
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
    env["RAYON_NUM_THREADS"] = "2"
    record = {
        "schema": 1, "profile": "ffn-v3-mr1-fresh-io-poc/2",
        "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
        "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "fixture": "public-synthetic-T32-d16-f16", "cases": [], "receipts": [],
        "trusted_policy": "separate endpoint file saved by trusted fixture caller before FFN proving",
        "full_private_block": False, "privacy_review_complete": False,
    }

    def save():
        (out / "result.json").write_text(json.dumps(record, indent=2) + "\n")

    def run(name, arguments, accept=True):
        cwd = out / name
        cwd.mkdir()
        command = [str(binary), *map(str, arguments)]
        p = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=180)
        passed = p.returncode == (0 if accept else 1)
        record["cases"].append({"name": name, "command": command, "cwd": str(cwd),
                                "exit_code": p.returncode, "expected_accept": accept,
                                "passed": passed, "stdout": p.stdout, "stderr": p.stderr})
        save()
        if not passed:
            raise AssertionError(f"{name}: exit {p.returncode}: {p.stderr}")
        return json.loads(p.stdout) if accept else None

    prepared = run("prepare", ["prepare"])
    assert prepared["proving_executed"] is False
    public_root = prepared["public_weight_root"]
    context = "18" * 32
    for mode in ("p1", "p3"):
        weights = public_root if mode == "p1" else "fresh"
        policy, receipt = out / f"{mode}.expected", out / f"{mode}.receipt"
        made = run(f"{mode}_prove", ["prove", mode, context, policy, receipt])
        raw, expected = receipt.read_bytes(), policy.read_bytes()
        assert len(expected) == 112 and len(raw) == made["wire_bytes"]
        assert made["policy_saved_before_proving"] is True
        assert expected[48:80].hex() == made["input_root"]
        assert expected[80:112].hex() == made["output_root"]
        record["receipts"].append({"mode": mode, "path": str(receipt), "bytes": len(raw),
                                   "sha256": hashlib.sha256(raw).hexdigest(),
                                   "expected_path": str(policy),
                                   "expected_sha256": hashlib.sha256(expected).hexdigest()})
        accepted = run(f"{mode}_verify", ["verify", mode, weights, context, policy, receipt])
        assert accepted["proving_executed"] is False and accepted["verified_from_bytes"] is True
        run(f"{mode}_context", ["verify", mode, weights, "19" * 32, policy, receipt], False)
        run(f"{mode}_weights", ["verify", mode, "00" * 32, context, policy, receipt], False)
        other = "p3" if mode == "p1" else "p1"
        run(f"{mode}_mode", ["verify", other, "fresh" if other == "p3" else public_root,
                            context, policy, receipt], False)
        for label, offset in (("input", 48), ("output", 80), ("scale", 44), ("policy_context", 8)):
            changed = bytearray(expected)
            changed[offset] ^= 1
            path = out / f"{mode}_{label}.expected"
            path.write_bytes(changed)
            run(f"{mode}_{label}", ["verify", mode, weights, context, path, receipt], False)
        path = out / f"{mode}_swapped.expected"
        path.write_bytes(expected[:48] + expected[80:] + expected[48:80])
        run(f"{mode}_swapped", ["verify", mode, weights, context, path, receipt], False)
        corrupt, huge = bytearray(raw), bytearray(raw)
        corrupt[-1] ^= 1
        huge[72:80] = b"\xff" * 8
        for label, value in (("tampered", corrupt), ("huge_rows", huge),
                             ("truncated", raw[:-1]), ("trailing", raw + b"\x00")):
            path = out / f"{mode}_{label}.receipt"
            path.write_bytes(value)
            run(f"{mode}_{label}", ["verify", mode, weights, context, policy, path], False)
        run(f"{mode}_overwrite", ["prove", mode, context, policy, receipt], False)
        assert receipt.read_bytes() == raw and policy.read_bytes() == expected
    record["status"] = "passed"
    save()
    print(json.dumps({"status": "passed", "cases": len(record["cases"]), "result": str(out / "result.json")}))


if __name__ == "__main__":
    main()
