#!/usr/bin/env python3
"""Recover the validated, unpromoted native GPU candidate from retained evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

REPO = Path(__file__).resolve().parents[1]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def restore(destination: Path, include_driver: bool = False) -> dict:
    if destination.exists():
        raise ValueError(f"destination already exists: {destination}")
    evidence = REPO / "results/zk60_shaped_integration_20260922"
    snapshot = json.loads((evidence / "review-snapshot.json").read_text())
    archive = evidence / snapshot["archive"]
    if sha(archive) != snapshot["archive_sha256"]:
        raise ValueError("reviewed source archive digest differs")
    destination.mkdir(parents=True)
    with tarfile.open(archive) as source:
        for member in source.getmembers():
            target = destination / member.name
            if member.issym() or member.islnk() or not target.resolve().is_relative_to(destination.resolve()):
                raise ValueError(f"unsafe archive member: {member.name}")
            if not (member.isfile() or member.isdir()):
                raise ValueError(f"unsupported archive member: {member.name}")
        source.extractall(destination)
    for relative, digest in snapshot["source_hashes"].items():
        if sha(destination / relative) != digest:
            raise ValueError(f"reviewed source mismatch: {relative}")
    # Successive retained snapshots contain the complete changed files, including
    # new modules. Applying them in order preserves their reviewed dependencies.
    for name in ("zk60_sumcheck_rounds_20260922", "zk60_encode_allocation_20260922",
                 "zk60_grouped_rounds_20260926"):
        changed = REPO / "results" / name / "candidate-v1"
        for path in sorted(changed.rglob("*")):
            if path.is_file():
                target = destination / path.relative_to(changed)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
    gpu = REPO / "results/zk60_sol_gpu_20260927/attempt-2"
    subprocess.run(["patch", "--batch", "--forward", "-p1", "-i", str(gpu / "candidate.patch")],
                   cwd=destination, check=True)
    pins = json.loads((gpu / "pins.json").read_text())["sources"]
    mismatches = [relative for relative, digest in pins.items()
                  if not (destination / relative).is_file() or sha(destination / relative) != digest]
    if mismatches:
        raise ValueError(f"GPU candidate source mismatches: {mismatches}")
    record = {"source_status": "restored-unpromoted-candidate", "destination": str(destination),
              "matched_source_files": len(pins), "sources": pins,
              "archive_sha256": sha(archive), "gpu_patch_sha256": sha(gpu / "candidate.patch"),
              "privacy_scope_extended": False, "trained_8b_proof": False}
    (destination / "restore.json").write_text(json.dumps(record, indent=2) + "\n")
    if include_driver:
        overlay = REPO / "ops/zkp-mvp"
        driver = json.loads((overlay / "driver-overlay.json").read_text())
        for relative, digest in driver["sources"].items():
            original = overlay / "driver-overlay" / relative
            if sha(original) != digest:
                raise ValueError(f"driver overlay source mismatch: {relative}")
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, target)
        record["driver_overlay"] = driver["sources"]
        (destination / "restore.json").write_text(json.dumps(record, indent=2) + "\n")
    return record


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--include-driver", action="store_true")
    args = parser.parse_args()
    record = restore(args.destination.resolve(), args.include_driver)
    print(json.dumps({key: value for key, value in record.items() if key != "sources"}, indent=2))


if __name__ == "__main__":
    main()
