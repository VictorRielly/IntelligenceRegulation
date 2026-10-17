#!/bin/bash
# NATIVE LANE round 4, R4-3 (2026-10-17): the 32-block Llama-3-8B stack at
# T32 as ONE bound run (blocks streamed one at a time), CPU or GPU (ONE GPU
# pass per invocation; HL_GPU_REQUIRED=1), then a FRESH-process CPU verify
# of the run directory (with every run-level control after the CPU run).
# usage: r4_stack.sh cpu|gpu <seq id>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/r4/zk60_trained_block.release.bin
XG=$D/r4/zk60_trained_block.gpu.release.bin
E=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_T32
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
M=$1; S=$2
R=$D/r4/stack-llama3_8b_pg_rot1_T32-$S-$M
mkdir -p "$R"
if [ "$M" = gpu ]; then
  python3 $G run --class gpu --need-gib ${NEED:-3.5} --cap-gib ${CAP:-6} --label r4-stack-8b-gpu --wait-secs 14400 --max-secs 5400 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env HL_GPU=1 HL_GPU_REQUIRED=1 RAYON_NUM_THREADS=16 LD_LIBRARY_PATH=$LD $XG stack-prove --export "$E" --seq "$S" --out "$R/run"
  CTL=""
else
  python3 $G run --class cpu --need-gib ${NEED:-3.5} --cap-gib ${CAP:-6} --label r4-stack-8b-cpu --wait-secs 14400 --max-secs 5400 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-prove --export "$E" --seq "$S" --out "$R/run"
  CTL="--controls"
fi
rc=$?
[ $rc -eq 0 ] || { echo "stack-prove $M exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
python3 $G run --class cpu --need-gib ${VNEED:-2.5} --cap-gib ${VCAP:-5} --label r4-stack-8b-verify-$M --wait-secs 14400 --max-secs 5400 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$ID" $CTL
echo "stack-verify $M exit $?"
