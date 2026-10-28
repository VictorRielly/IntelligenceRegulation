#!/bin/bash
# NATIVE LANE R9: one guarded cargo step on the live tree.
# usage: r9_cargo.sh <label> <class> <need> <cap> <cargo args...>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
L=$1; K=$2; N=$3; P=$4; shift 4
until out=$(python3 $G check --class $K --need-gib $N 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 20; done
python3 $G run --class $K --need-gib $N --cap-gib $P --label $L --wait-secs 14400 --max-secs 5400 \
  --log $D/r9/$L.log --done $D/r9/$L.done --result-json $D/r9/$L.guard.json \
  -- /usr/bin/env RAYON_NUM_THREADS=16 /home/victor/.cargo/bin/cargo "$1" --manifest-path /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml "${@:2}"
