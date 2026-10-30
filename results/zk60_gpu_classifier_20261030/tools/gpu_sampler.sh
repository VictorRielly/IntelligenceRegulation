#!/bin/bash
# GPU CLASSIFIER lane: GPU telemetry beside ONE guarded GPU run (nvidia-smi QUERIES only, no device allocation).
# Samples about 4 times a second from now until DONE exists; ends by itself (no kill). Also one full
# `nvidia-smi -q -d CLOCK,PERFORMANCE,POWER` record at the start and at the end.
# usage: gpu_sampler.sh <done path> <out csv>
set -u
DONE=$1; CSV=$2
S=/usr/lib/wsl/lib/nvidia-smi
Q=timestamp,pstate,clocks.sm,clocks.mem,clocks_throttle_reasons.active,power.draw,temperature.gpu,memory.used,utilization.gpu
$S -q -d CLOCK,PERFORMANCE,POWER > "$CSV.q-start.txt" 2>&1
echo "timestamp, pstate, clocks.sm [MHz], clocks.mem [MHz], clocks_throttle_reasons.active (0x1 idle, 0x4 SW power cap, 0x20 SW thermal slowdown, 0x40 HW thermal, 0x8 HW slowdown), power [W], temperature [C], memory.used [MiB], util.gpu [%]" > "$CSV"
while [ ! -f "$DONE" ]; do
  $S --query-gpu=$Q --format=csv,noheader >> "$CSV" 2>/dev/null
  sleep 0.25
done
$S -q -d CLOCK,PERFORMANCE,POWER > "$CSV.q-end.txt" 2>&1
echo "sampler done" >> "$CSV"
