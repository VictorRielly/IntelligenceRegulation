#!/bin/bash
# NATIVE LANE round 3, R3-3 (2026-10-17): ONE GPU-assisted 22-block stack at
# one rung of the ladder (guard class gpu; HL_GPU=1 HL_GPU_REQUIRED=1, a
# decline aborts; RAYON_NUM_THREADS=16 as on the CPU). ONE GPU pass per
# invocation; the fresh-process verify that follows is the CPU binary.
# usage: r3_stack_gpu.sh <export variant> <seq id>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
XG=$D/r3/zk60_trained_block.gpu.release.bin
X=$D/r3/zk60_trained_block.release.bin
E=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/$1
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
S=$2
R=$D/r3/stack-$1-$S-gpu
mkdir -p "$R"
python3 $G run --class gpu --need-gib ${NEED:-5} --cap-gib ${CAP:-6.5} --label r3-stack-gpu-$1 --wait-secs 14400 --max-secs 3600 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- /usr/bin/env HL_GPU=1 HL_GPU_REQUIRED=1 RAYON_NUM_THREADS=16 LD_LIBRARY_PATH=$LD $XG stack-prove --export "$E" --seq "$S" --out "$R/run"
rc=$?
[ $rc -eq 0 ] || { echo "gpu stack-prove exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
python3 $G run --class cpu --need-gib 4 --cap-gib 7 --label r3-stack-gpu-verify-$1 --wait-secs 14400 --max-secs 3600 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$ID"
echo "cpu verify of the gpu run exit $?"
