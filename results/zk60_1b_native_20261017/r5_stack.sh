#!/bin/bash
# NATIVE LANE round 5, R5-4 (2026-10-17): one stack run (CPU or GPU; ONE GPU
# pass per invocation; HL_GPU_REQUIRED=1) with the phase clock on
# (HL_PB_TIMING=1: per-phase counted work and bytes), RAYON_NUM_THREADS=16,
# no in-process verify (round 5 default), then a FRESH-process CPU verify of
# the run directory (with every run-level control after the CPU run).
# usage: r5_stack.sh <export dir> cpu|gpu <seq id> <need> <cap>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/r5/zk60_trained_block.release.bin
XG=$D/r5/zk60_trained_block.gpu.release.bin
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
E=$1; M=$2; S=$3; NEED=$4; CAP=$5
# the review r3_6 fix landed after the first CLI build: rebuild the CLIs
# once, from the fixed tree, before the first acceptance run
if [ ! -f $D/r5_cli2.done ]; then
  $D/r5_build_cli2.sh > $D/r5_build_cli2.out 2>&1; echo $? > $D/r5_cli2.done
fi
[ "$(cat $D/r5_cli2.done)" = 0 ] || { echo "CLI rebuild failed: $(cat $D/r5_cli2.done)"; exit 1; }
V=$(basename "$E"); R=$D/r5/stack-$V-$S-$M${TAG:-}
mkdir -p "$R"
if [ "$M" = gpu ]; then
  python3 $G run --class gpu --need-gib $NEED --cap-gib $CAP --label r5-stack-$V-gpu --wait-secs 14400 --max-secs 5400 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env HL_PB_TIMING=1 HL_GPU=1 HL_GPU_REQUIRED=1 RAYON_NUM_THREADS=16 LD_LIBRARY_PATH=$LD $XG stack-prove --export "$E" --seq "$S" --out "$R/run"
  CTL=""
else
  python3 $G run --class cpu --need-gib $NEED --cap-gib $CAP --label r5-stack-$V-cpu --wait-secs 14400 --max-secs 5400 \
    --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
    -- /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=16 $X stack-prove --export "$E" --seq "$S" --out "$R/run"
  CTL="--controls"
fi
rc=$?
[ $rc -eq 0 ] || { echo "stack-prove $V $M exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
python3 $G run --class cpu --need-gib ${VNEED:-2.5} --cap-gib ${VCAP:-5} --label r5-stack-verify-$V-$M --wait-secs 14400 --max-secs 5400 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$ID" $CTL
echo "stack-verify $V $M exit $?"
