#!/usr/bin/env python3
"""The installed Shieldstral block (W16R2_SHIELD_T128_H24) on its own: slot census and block GPU.

By the Claude co-coordinator, 2026-11-20. No source change: the reference binary and the two tests of
`results/zk60_slot18_14_breakdown_20261117/run_slot_breakdown.py` (arm A, the production settings), run at
one more profile, with the breakdown's two measured profiles as controls. Each leaf runs under the guard.

Usage:  python3 -B run_block.py            (launches itself detached; log `raw/run.log`, marker `raw/run.done`)
        python3 -B run_block.py --inner    (the run itself)
"""
import gzip
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import sys
import time

REPO = pathlib.Path("/Users/victorrielly/IntelligenceRegulation")
GUARD = REPO / "scripts/zk60_resource_guard.py"
BIN = REPO / "ops/zkp-mvp/gpu-metal/hashline/target/release/deps/hashline-a90b6cf7715dc2a7"
BIN_SHA256 = "aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11"
OUT = REPO / "results/zk60_w16r2_shield_block_20261120"
RAW = OUT / "raw"
EXT = pathlib.Path("/Users/victorrielly/zk60-artifacts/w16r2_shield_block_20261120")
GAP_S = 13.0
WARM = 5

# The census test (`a27_slot_census_at_a_trained_shape`) takes its profile from `registered_shapes()`, which lists
# `ACCURACY_PROFILES` only, so it does not accept a W16R2 name. The table counts of each slot are read from the
# GPU trace's slot labels instead ("slot 14 (...): 36 tables (23 base), ..."), which the block test writes.
CENSUS = []
ARMS = [
    ("w16r2_shield_a1", "W16R2_SHIELD_T128_H24"),
    ("w16r2_8b_ctl", "W16R2_8B_T128_H24"),
    ("r13_shield_ctl", "R13_SHIELD_T128_H24"),
    ("w16r2_shield_a2", "W16R2_SHIELD_T128_H24"),
]
ARM_A = {"HL_METAL_BATCH": "1", "HL_METAL_DEVICE_TABLES": "1", "HL_A27_LIN": "1"}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def out_of(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()


def leaf(label, klass, need, cap, max_secs, test, env_extra):
    if pathlib.Path("/tmp/HOLD").exists():
        raise SystemExit("ABORT: /tmp/HOLD is present")
    assert sha256(BIN) == BIN_SHA256, "the reference binary changed"
    pre = {
        "ds4_bench": out_of(["pgrep", "-fl", "ds4-bench"]) or "none",
        "loadavg": os.getloadavg()[0],
        "guard_status": out_of([sys.executable, "-B", str(GUARD), "status"]),
    }
    env = os.environ.copy()
    env.pop("ZK60_GUARD_POLL_SECS", None)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(env_extra)
    cmd = [sys.executable, "-B", str(GUARD), "run", "--label", "claude-" + label, "--class", klass,
           "--need-gib", str(need), "--cap-gib", str(cap), "--wait-secs", "3600", "--max-secs", str(max_secs),
           "--", str(BIN), "--exact", test, "--ignored", "--nocapture"]
    t0 = time.monotonic()
    with open(RAW / (label + ".log"), "w") as fo, open(RAW / (label + ".guard.txt"), "w") as fe:
        rc = subprocess.run(cmd, cwd=str(REPO), env=env, stdout=fo, stderr=fe).returncode
    wall = time.monotonic() - t0
    traces = []
    for tsv in sorted(EXT.glob(label + ".*.tsv")):
        gz = tsv.with_suffix(".tsv.gz")
        with tsv.open("rb") as fi, gzip.open(gz, "wb", compresslevel=6) as fz:
            shutil.copyfileobj(fi, fz)
        tsv.unlink()
        traces.append(str(gz))
    rec = {"label": label, "rc": rc, "wall_s": round(wall, 3), "pre": pre,
           "post_ds4_bench": out_of(["pgrep", "-fl", "ds4-bench"]) or "none", "trace_gz_files": traces}
    print("[%s] rc %d, %.1f s, load before %.1f, traces %d" % (label, rc, wall, pre["loadavg"], len(traces)), flush=True)
    return rec


def inner():
    RAW.mkdir(parents=True, exist_ok=True)
    EXT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for label, prof in CENSUS:
        manifest.append(leaf(label, "cpu", 4, 12, 180,
                             "private_block::slot_ir::accuracy::tests::a27_slot_census_at_a_trained_shape",
                             {"HL_A27_PROFILE": prof}))
        time.sleep(GAP_S)
    for label, prof in ARMS:
        env = {"HL_GPU_REQUIRED": "1", "HL_M4_PROFILES": prof, "HL_M4_WARM_PASSES": str(WARM),
               "HL_A27_GPU_TRACE": str(EXT / label), "HL_METAL_TIMING": "1", "HL_PB_TIMING": "1"}
        env.update(ARM_A)
        manifest.append(leaf(label, "gpu", 12, 24, 600,
                             "private_block::slot_ir::accuracy::tests::m4_trained_accuracy_block_cpu_and_metal_digests_and_times",
                             env))
        time.sleep(GAP_S)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    bad = [m["label"] for m in manifest if m["rc"] != 0]
    print("ALL LEAVES DONE; failed: %s" % (bad or "none"), flush=True)
    return 1 if bad else 0


def main():
    if "--inner" in sys.argv:
        rc = 1
        try:
            rc = inner()
        finally:
            (RAW / "run.done").write_text("%d\n" % rc)
        sys.exit(rc)
    RAW.mkdir(parents=True, exist_ok=True)
    done = RAW / "run.done"
    if done.exists():
        raise SystemExit("raw/run.done exists; this run was already made")
    with open(RAW / "run.log", "w") as log:
        p = subprocess.Popen([sys.executable, "-B", str(pathlib.Path(__file__).resolve()), "--inner"],
                             stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                             cwd=str(REPO), start_new_session=True)
    print("launched detached, pid", p.pid)


if __name__ == "__main__":
    main()
