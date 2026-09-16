#!/usr/bin/env python3
"""One-command gate for the round-2 MVP security delivery (the joint view).

Runs, in order, the five test modules and the four tools of
docs/zkmatrix-poc/ZK60_MVP_JOINT_VIEW.md against the retained round-22
captures, records every command, exit code, log SHA-256 and tool SHA-256 in
<evidence>/validation.json, and writes <evidence>/validation.done holding the
overall exit code. Only completed successful stages count; a nonzero stage
stops the run and is recorded as the failure.

This is an execution record, not a privacy theorem. The tools it runs are
fixed-challenge, independent-uniform-randomness diagnostics plus oracle
bookkeeping and finite-model lemma checks; see the memo for their limits.

    python3 scripts/zk60_mvp_joint_view_gate.py \
        --captures /home/victor/IntelligenceRegulation/results/zk60_round22_captures \
        --manifest /home/victor/IntelligenceRegulation/results/zk60_round22_captures.json \
        --evidence results/zk60_mvp_joint_view_evidence
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
PY = sys.executable

TOOLS = [
    "scripts/zk60_blake3_pure.py",
    "scripts/zk60_transcript_replay.py",
    "scripts/zk60_joint_view.py",
    "scripts/zk60_joint_cfs_view.py",
    "scripts/zk60_root_simulator.py",
    "scripts/zk60_mvp_joint_view_gate.py",
    "tests/test_zk60_transcript_replay.py",
    "tests/test_zk60_joint_view.py",
    "tests/test_zk60_joint_cfs_view.py",
    "tests/test_zk60_root_simulator.py",
    "tests/test_zk60_sequential_kernel.py",
]


def sha256_path(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def stages(captures, manifest, evidence):
    ev = str(evidence)
    replay = f"{ev}/transcript_replay/gate_replay.json"
    tests = [
        ("test_transcript_replay", "test_zk60_transcript_replay.py"),
        ("test_joint_view", "test_zk60_joint_view.py"),
        ("test_joint_cfs_view", "test_zk60_joint_cfs_view.py"),
        ("test_root_simulator", "test_zk60_root_simulator.py"),
        ("test_sequential_kernel", "test_zk60_sequential_kernel.py"),
    ]
    out = [
        (name, [PY, "-m", "unittest", "discover", "-s", str(ROOT / "tests"), "-p", pat, "-v"])
        for name, pat in tests
    ]
    out += [
        ("transcript_replay_wheel", [PY, str(ROOT / "scripts/zk60_transcript_replay.py"),
                                     "--captures", captures, "--manifest", manifest, "--out", replay]),
        ("transcript_replay_pure", [PY, str(ROOT / "scripts/zk60_transcript_replay.py"),
                                    "--captures", captures, "--manifest", manifest,
                                    "--backend", "pure", "--no-history",
                                    "--out", f"{ev}/transcript_replay/gate_replay_pure.json"]),
        ("joint_pcs_view", [PY, str(ROOT / "scripts/zk60_joint_view.py"),
                            "--captures", captures, "--manifest", manifest,
                            "--out", f"{ev}/pcs_view/gate_joint_view.json"]),
        ("joint_cfs_view_captured", [PY, str(ROOT / "scripts/zk60_joint_cfs_view.py"),
                                     "--captures", captures, "--manifest", manifest,
                                     "--challenges", replay,
                                     "--out", f"{ev}/cfs_view/gate_joint_cfs_view_captured.json"]),
        ("root_simulator", [PY, str(ROOT / "scripts/zk60_root_simulator.py"),
                            "--out", f"{ev}/simulator/gate_root_simulator.json"]),
    ]
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--captures", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--evidence", default="results/zk60_mvp_joint_view_evidence")
    args = ap.parse_args(argv)
    evidence = Path(args.evidence)
    if not evidence.is_absolute():
        evidence = ROOT / evidence
    for sub in ("transcript_replay", "pcs_view", "cfs_view", "simulator"):
        (evidence / sub).mkdir(parents=True, exist_ok=True)
    for stale in ("validation.json", "validation.done"):
        if (evidence / stale).exists():
            (evidence / stale).unlink()
    record = {
        "schema": 1,
        "kind": "zk60-mvp-joint-view-gate",
        "python": sys.version.split()[0],
        "root": str(ROOT),
        "captures": args.captures,
        "manifest": args.manifest,
        "manifest_sha256": sha256_path(args.manifest),
        "tool_sha256": {t: sha256_path(ROOT / t) for t in TOOLS if (ROOT / t).exists()},
        "missing_tools": [t for t in TOOLS if not (ROOT / t).exists()],
        "stages": [],
        "status": "incomplete",
    }
    code = 0
    for name, cmd in stages(args.captures, args.manifest, evidence):
        log = evidence / f"gate_{name}.log"
        t0 = time.time()
        with open(log, "wb") as lf:
            proc = subprocess.run(cmd, stdout=lf, stderr=subprocess.STDOUT, cwd=str(ROOT),
                                  env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
        entry = {
            "name": name, "command": cmd, "exit_code": proc.returncode,
            "seconds": round(time.time() - t0, 3),
            "log": str(log.relative_to(ROOT)), "log_sha256": sha256_path(log),
        }
        record["stages"].append(entry)
        print(f"{name} exit={proc.returncode} {entry['seconds']}s", flush=True)
        if proc.returncode != 0:
            code = proc.returncode
            record["status"] = f"failed at {name}"
            break
    else:
        record["status"] = "passed"
    for entry in record["stages"]:
        out = None
        cmd = entry["command"]
        if "--out" in cmd:
            out = cmd[cmd.index("--out") + 1]
        if out and Path(out).exists():
            entry["result"] = str(Path(out).relative_to(ROOT)) if Path(out).is_relative_to(ROOT) else out
            entry["result_sha256"] = sha256_path(out)
    (evidence / "validation.json").write_text(json.dumps(record, indent=2) + "\n")
    (evidence / "validation.done").write_text(f"{code}\n")
    print(record["status"], flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main())
