#!/usr/bin/env python3
"""Zero-edit hardware GPU sub-phase breakdown of private-block sumcheck slots (esp. 18 & 14).

Uses ONLY the unmodified reference binary `hashline-a90b6cf7715dc2a7`
(sha256 `aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11`)
under `scripts/zk60_resource_guard.py` (default 5.0 s poll, >= 12.5 s inter-leaf gap).
Raw `HL_A27_GPU_TRACE` TSV files are externalized to
`/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117/`.
"""

from __future__ import annotations

import gzip
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time
from typing import Dict, List

REPO = pathlib.Path("/Users/victorrielly/IntelligenceRegulation")
GUARD = REPO / "scripts/zk60_resource_guard.py"
BIN_U = REPO / "ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7"
EXPECTED_SHA256 = "aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11"

OUT_DIR = REPO / "results/zk60_slot18_14_breakdown_20261117"
RAW_DIR = OUT_DIR / "raw"
EXT_DIR = pathlib.Path("/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117")

WARM_PASSES = 5
INTER_LEAF_SLEEP_S = 13.0


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def check_preconditions() -> None:
    if pathlib.Path("/tmp/HOLD").exists():
        raise SystemExit("ABORT: /tmp/HOLD is present")
    if not BIN_U.exists():
        raise SystemExit(f"ABORT: missing reference binary {BIN_U}")
    got = sha256_file(BIN_U)
    if got != EXPECTED_SHA256:
        raise SystemExit(f"ABORT: {BIN_U} sha256={got} != {EXPECTED_SHA256}")


def check_bg_procs() -> str:
    p = subprocess.run(["pgrep", "-fl", "ds4-bench"], capture_output=True, text=True)
    return p.stdout.strip() or "none"


def run_guarded_leaf(
    label: str,
    guard_class: str,
    need_gib: int,
    cap_gib: int,
    max_secs: int,
    cmd: List[str],
    extra_env: Dict[str, str],
) -> Dict[str, object]:
    check_preconditions()
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    EXT_DIR.mkdir(parents=True, exist_ok=True)

    pre_bg = check_bg_procs()
    st_pre = subprocess.run(
        [sys.executable, "-B", str(GUARD), "status"],
        capture_output=True,
        text=True,
    ).stdout

    log_path = RAW_DIR / f"{label}.log"
    guard_path = RAW_DIR / f"{label}.guard.txt"
    status_path = RAW_DIR / f"{label}.status.txt"

    env = os.environ.copy()
    env.pop("ZK60_GUARD_POLL_SECS", None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(extra_env)

    full_cmd = [
        sys.executable,
        "-B",
        str(GUARD),
        "run",
        "--label",
        f"agy-{label}",
        "--class",
        guard_class,
        "--need-gib",
        str(need_gib),
        "--cap-gib",
        str(cap_gib),
        "--wait-secs",
        "21600",
        "--max-secs",
        str(max_secs),
        "--",
        *cmd,
    ]

    t0 = time.monotonic()
    with log_path.open("w") as flog, guard_path.open("w") as fguard:
        proc = subprocess.run(full_cmd, cwd=str(REPO), env=env, stdout=flog, stderr=fguard)
    wall_s = time.monotonic() - t0
    post_bg = check_bg_procs()

    status_path.write_text(
        f"=== pre ds4-bench: {pre_bg}\n=== post ds4-bench: {post_bg}\n=== pre guard status:\n{st_pre}\n"
    )

    guard_txt = guard_path.read_text()
    if proc.returncode != 0:
        raise RuntimeError(f"Leaf {label} failed (rc={proc.returncode}):\n{guard_txt}")

    # Compress and externalize any TSV traces generated for this leaf
    trace_gz_files = []
    for tsv in sorted(EXT_DIR.glob(f"{label}.*.tsv")):
        gz_path = tsv.with_suffix(".tsv.gz")
        with tsv.open("rb") as fin, gzip.open(gz_path, "wb", compresslevel=6) as fout:
            shutil.copyfileobj(fin, fout)
        tsv.unlink()
        trace_gz_files.append(str(gz_path))

    return {
        "label": label,
        "rc": proc.returncode,
        "wall_s": round(wall_s, 3),
        "pre_ds4_bench": pre_bg,
        "post_ds4_bench": post_bg,
        "guard_stderr": guard_txt.strip(),
        "trace_gz_files": trace_gz_files,
    }


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    EXT_DIR.mkdir(parents=True, exist_ok=True)

    manifest: List[Dict[str, object]] = []

    # 1. Static IR / MSL operation census for R13_8B_T128_H24 and R13_SHIELD_T128_H24
    for prof_tag, prof_name in [("r13_8b", "R13_8B_T128_H24"), ("r13_shield", "R13_SHIELD_T128_H24")]:
        label = f"census_{prof_tag}"
        res = run_guarded_leaf(
            label=label,
            guard_class="cpu",
            need_gib=4,
            cap_gib=12,
            max_secs=120,
            cmd=[
                str(BIN_U),
                "--exact",
                "private_block::slot_ir::accuracy::tests::a27_slot_census_at_a_trained_shape",
                "--ignored",
                "--nocapture",
            ],
            extra_env={"HL_A27_PROFILE": prof_name},
        )
        print(f"[DONE] {label}: {res['guard_stderr']}", flush=True)
        manifest.append(res)
        time.sleep(INTER_LEAF_SLEEP_S)

    # 2. Hardware GPU trace breakdown across 3 diagnostic arms x 2 profiles
    arms = [
        (
            "armA_prod_batched",
            {
                "HL_METAL_BATCH": "1",
                "HL_METAL_DEVICE_TABLES": "1",
                "HL_A27_LIN": "1",
            },
        ),
        (
            "armB_unbatched_sync_lin1",
            {
                "HL_METAL_BATCH": "0",
                "HL_METAL_DEVICE_TABLES": "sync",
                "HL_A27_LIN": "1",
            },
        ),
        (
            "armC_unbatched_sync_lin0",
            {
                "HL_METAL_BATCH": "0",
                "HL_METAL_DEVICE_TABLES": "sync",
                "HL_A27_LIN": "0",
            },
        ),
    ]

    profiles = [
        ("w16r2_8b", "W16R2_8B_T128_H24"),
        ("r13_shield", "R13_SHIELD_T128_H24"),
    ]

    for prof_tag, prof_name in profiles:
        for arm_name, arm_env in arms:
            label = f"{prof_tag}_{arm_name}"
            trace_prefix = str(EXT_DIR / label)
            env = {
                "HL_GPU_REQUIRED": "1",
                "HL_M4_PROFILES": prof_name,
                "HL_M4_WARM_PASSES": str(WARM_PASSES),
                "HL_A27_GPU_TRACE": trace_prefix,
                "HL_METAL_TIMING": "1",
                "HL_PB_TIMING": "1",
                **arm_env,
            }
            res = run_guarded_leaf(
                label=label,
                guard_class="gpu",
                need_gib=12,
                cap_gib=24,
                max_secs=600,
                cmd=[
                    str(BIN_U),
                    "--exact",
                    "private_block::slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times",
                    "--ignored",
                    "--nocapture",
                ],
                extra_env=env,
            )
            print(f"[DONE] {label}: {res['guard_stderr']}", flush=True)
            manifest.append(res)
            time.sleep(INTER_LEAF_SLEEP_S)

    (OUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("ALL LEAVES COMPLETE!", flush=True)


if __name__ == "__main__":
    main()
