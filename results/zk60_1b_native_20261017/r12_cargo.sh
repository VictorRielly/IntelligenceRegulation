#!/bin/bash
# NATIVE LANE R12: one guarded cargo step.
# usage: r12_cargo.sh <label> <class> <need> <cap> <Cargo.toml> <cargo subcommand> [cargo args...]
# The admission pre-check runs OUTSIDE the heavy lock (the guard takes the lock
# before waiting for admission); logs, done markers and guard JSON land in r12/.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
L=$1; K=$2; N=$3; P=$4; M=$5; shift 5
until out=$(python3 $G check --class $K --need-gib $N 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 20; done
python3 $G run --class $K --need-gib $N --cap-gib $P --label $L --wait-secs 14400 --max-secs 5400 \
  --log $D/r12/$L.log --done $D/r12/$L.done --result-json $D/r12/$L.guard.json \
  -- /usr/bin/env RAYON_NUM_THREADS=16 /home/victor/.cargo/bin/cargo "$1" --offline --locked -j2 --manifest-path "$M" "${@:2}"
