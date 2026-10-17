#!/bin/bash
# NATIVE LANE round 2, R2-5 (2026-10-17): ONE GPU-assisted run of the same
# 22-block pg_rot1 stack at T32 (guard class gpu: VRAM idle check, cap and
# drain), GPU claimed AND required (HL_GPU=1 HL_GPU_REQUIRED=1: a device
# decline aborts the run instead of falling back to the CPU). ONE GPU pass in
# this script; the fresh-process verify that follows is the CPU binary.
# usage: r2_stack_gpu.sh <seq id>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
XG=$D/r2/zk60_trained_block.gpu.release.bin
X=$D/r2/zk60_trained_block.release.bin
E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
S=$1
R=$D/r2/stack-pg_rot1-$S-gpu
mkdir -p "$R"
python3 $G run --class gpu --label r2-stack-gpu-$S --wait-secs 14400 --max-secs 3600 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- /usr/bin/env HL_GPU=1 HL_GPU_REQUIRED=1 LD_LIBRARY_PATH=$LD $XG stack-prove --export "$E" --seq "$S" --out "$R/run"
rc=$?
[ $rc -eq 0 ] || { echo "gpu stack-prove exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
python3 $G run --class cpu --need-gib 4 --cap-gib 7 --label r2-stack-gpu-verify-$S --wait-secs 14400 --max-secs 3600 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$ID"
echo "cpu verify of the gpu run exit $?"
