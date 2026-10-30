#!/bin/bash
# GPU CLASSIFIER lane: ONE guarded run of the paused zero-check lane's round-4 test binary (built 2026-10-18 02:38 UTC
# from ops/zkp-mvp/gpu-zerocheck, the slot-18 split kernel; run read-only, no cargo, nothing written into that tree)
# under the laptop's new power mode, with the clock sampler beside it. ONE GPU pass per invocation.
# usage: gzc_measure.sh <label> <test filter> [VAR=value ...]     (always --ignored --test-threads=1 --nocapture)
set -u
L=$1; F=$2; shift 2
D=/home/victor/IntelligenceRegulation/results/zk60_gpu_classifier_20261030
T=$D/tools
LB=$D/logs/gzc
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gpu-zerocheck/hashline
TB=$W/target-gpu/release/deps/hashline-5af71eb9341564fc
LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib
mkdir -p $LB
python3 $T/wait_turn.py $LB/queue.log --need 2.5
echo "$(date -u +%FT%TZ) $L start" >> $LB/queue.log
setsid nohup bash $T/gpu_sampler.sh $LB/$L.guard.done $LB/$L.gpu.csv >/dev/null 2>&1 &
python3 $G run --class gpu --need-gib 2.5 --cap-gib 6 --label "gcl-$L" --wait-secs 14400 --max-secs 1500 \
  --log $LB/$L.log --done $LB/$L.guard.done --result-json $LB/$L.guard.json \
  -- /usr/bin/env -C $W CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$LD HL_GPU=1 RAYON_NUM_THREADS=16 HL_GZC_CACHE_DIR=$D/gzc_module_cache "$@" $TB "$F" --ignored --test-threads=1 --nocapture
echo $? > $LB/$L.exit
[ -f $LB/$L.guard.done ] || echo "no guard marker" > $LB/$L.guard.done
echo "$(date -u +%FT%TZ) $L end $(cat $LB/$L.exit)" >> $LB/queue.log
