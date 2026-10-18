#!/bin/bash
# GPU ZERO-CHECK lane: light-class GPU telemetry beside ONE guarded stack run
# (nvidia-smi QUERIES only; no device allocation). Waits until the run's
# wrapper output shows the guard's START line, then samples P-state, SM and
# memory clocks, power, memory used and utilisation about three times a
# second until the run's .done marker exists. Ends by itself (no kill).
# usage: gpu_sampler.sh <wrapper .out file> <done path> <out csv> [start pattern, default 'START gzc-stack']
set -u
OUT=$1; DONE=$2; CSV=$3; PAT=${4:-START gzc-stack}
S=/usr/lib/wsl/lib/nvidia-smi
Q=timestamp,pstate,clocks.sm,clocks.mem,clocks_throttle_reasons.active,power.draw,temperature.gpu,memory.used,utilization.gpu
until grep -q "$PAT" "$OUT" 2>/dev/null; do sleep 1; done
echo "timestamp, pstate, clocks.sm [MHz], clocks.mem [MHz], clocks_throttle_reasons.active (bitmask: 0x1 idle, 0x4 SW power cap, 0x20 SW thermal slowdown, 0x40 HW thermal, 0x8 HW slowdown), power [W], temperature [C], memory.used [MiB], util.gpu [%]" > "$CSV"
while [ ! -f "$DONE" ]; do
  $S --query-gpu=$Q --format=csv,noheader >> "$CSV" 2>/dev/null
  sleep 0.25
done
echo "sampler done" >> "$CSV"
