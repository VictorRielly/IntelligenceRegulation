#!/usr/bin/env python3
"""Exercise the saved fresh-FFN proof in distinct CPU processes.

Run under /tmp/zk-heavy.lock with two build/Rayon threads after building the
zk60_fresh_ffn example. All fixture tensors are public synthetic data. This is
an acceptance check, not a privacy audit or performance benchmark.
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
        "schema": 1, "profile": "ffn-v3-mr1-fresh-poc/1",
        "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
        "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "fixture": "public-synthetic-T32-d16-f16", "cases": [], "proofs": [],
        "full_private_block": False, "privacy_review_complete": False,
    }

    def save():
        (out / "result.json").write_text(json.dumps(record, indent=2) + "\n")

    def run(name, arguments, success=True):
        # Every invocation starts in its own empty directory and exits before
        # the next begins. Only explicit public policy and proof paths cross.
        cwd = out / name
        cwd.mkdir()
        command = [str(binary), *map(str, arguments)]
        proc = subprocess.run(command, cwd=cwd, env=env, text=True,
                              capture_output=True, timeout=180)
        passed = proc.returncode == (0 if success else 1)
        case = {"name": name, "command": command, "cwd": str(cwd),
                "exit_code": proc.returncode, "expected_accept": success,
                "passed": passed, "stdout": proc.stdout, "stderr": proc.stderr}
        record["cases"].append(case)
        save()
        if not passed:
            raise AssertionError(f"{name}: unexpected exit {proc.returncode}: {proc.stderr}")
        return json.loads(proc.stdout) if success else None

    prepared = run("prepare", ["prepare"])
    assert prepared["proving_executed"] is False
    public_root = prepared["public_weight_root"]
    record["prepared_policy"] = prepared
    context = "round17-independent-verifier"
    for mode in ("p1", "p3"):
        root = public_root if mode == "p1" else "fresh"
        proof = out / f"{mode}.proof"
        made = run(f"{mode}_prove", ["prove", mode, context, proof])
        raw = proof.read_bytes()
        assert made["wire_bytes"] == len(raw)
        record["proofs"].append({"mode": mode, "path": str(proof), "bytes": len(raw),
                                 "sha256": hashlib.sha256(raw).hexdigest()})
        verified = run(f"{mode}_verify", ["verify", mode, root, context, proof])
        assert verified["proving_executed"] is False and verified["verified_from_bytes"] is True
        run(f"{mode}_wrong_context", ["verify", mode, root, "other-request", proof], False)
        run(f"{mode}_wrong_policy", ["verify", mode, "00" * 32, context, proof], False)
        other = "p3" if mode == "p1" else "p1"
        other_root = "fresh" if other == "p3" else public_root
        run(f"{mode}_wrong_mode", ["verify", other, other_root, context, proof], False)
        corrupt = bytearray(raw)
        corrupt[-1] ^= 1  # Merkle authentication path, length unchanged.
        huge = bytearray(raw)
        huge[73:81] = b"\xff" * 8  # W commitment row count, length unchanged.
        for label, value in (("tampered", corrupt), ("huge_rows", huge),
                             ("truncated", raw[:-1]), ("trailing", raw + b"\x00")):
            path = out / f"{mode}_{label}.proof"
            path.write_bytes(value)
            run(f"{mode}_{label}", ["verify", mode, root, context, path], False)
        run(f"{mode}_overwrite", ["prove", mode, context, proof], False)
        assert proof.read_bytes() == raw
    record["status"] = "passed"
    save()
    print(json.dumps({"status": "passed", "cases": len(record["cases"]),
                      "result": str(out / "result.json")}))


if __name__ == "__main__":
    main()
