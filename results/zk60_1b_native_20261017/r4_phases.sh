#!/bin/bash
# NATIVE LANE round 4, R4-4 (2026-10-17): the phase breakdown of the T128
# TinyLlama 22-block stack (pg_rot1_b4_T128, ho00) with the existing phase
# clock (HL_PB_TIMING=1, private_block/timing.rs: per-block phase table and
# per-slot steps), round-3 CLI, RAYON_NUM_THREADS=16. ONE run per invocation.
# usage: r4_phases.sh cpu|gpu
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T128
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
M=$1
R=$D/r4/phases-T128-$M
mkdir -p "$R"
if [ "$M" = gpu ]; then
  python3 $G run --class gpu --need-gib 5.5 --cap-gib 8 --label r4-phases-T128-gpu --wait-secs 14400 --max-secs 3600 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env HL_PB_TIMING=1 HL_GPU=1 HL_GPU_REQUIRED=1 RAYON_NUM_THREADS=16 LD_LIBRARY_PATH=$LD $D/r3/zk60_trained_block.gpu.release.bin stack-prove --export "$E" --seq ho00 --out "$R/run"
else
  python3 $G run --class cpu --need-gib 6 --cap-gib 10 --label r4-phases-T128-cpu --wait-secs 14400 --max-secs 3600 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=16 $D/r3/zk60_trained_block.release.bin stack-prove --export "$E" --seq ho00 --out "$R/run"
fi
echo "phases $M exit $?"
