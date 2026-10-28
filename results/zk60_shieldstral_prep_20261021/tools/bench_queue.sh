#!/usr/bin/env bash
# Benchmark queue: each argument is SET:TEMPLATE:LIMIT (LIMIT 0 = full set).
# For each job, launch guarded time-boxed chunks of bench_run.py until it exits 0 (3 = time box, relaunch).
# Honours $LANE/HOLD before every launch. Writes logs/bench_<set>_<template>_<limit>.done per job and
# logs/<QUEUE_NAME>.done at the end (exit code of the last chunk that ended the queue).
# Usage: bench_queue.sh QUEUE_NAME NEED_GIB THREADS SET:TEMPLATE:LIMIT ...
LANE=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
QNAME=$1; NEED=$2; THREADS=$3; shift 3
rc=0
for job in "$@"; do
  IFS=: read -r SET TPL LIM <<< "$job"
  STEM=bench_${SET}_${TPL}_${LIM}
  OUT=$LANE/bench/${SET}_${TPL}.jsonl
  for chunk in $(seq 1 60); do
    while [ -e "$LANE/HOLD" ]; do sleep 30; done
    python3 $GUARD run --class light --need-gib "$NEED" --cap-gib 1.8 --label "shieldstral-$STEM-c$chunk" \
      --wait-secs 14400 --max-secs 2100 --log "$LANE/logs/$STEM.log" \
      --done "$LANE/logs/$STEM.c$chunk.guard.done" --result-json "$LANE/logs/$STEM.c$chunk.guard.json" \
      -- /usr/bin/env OPENBLAS_NUM_THREADS=$THREADS OMP_NUM_THREADS=$THREADS \
      python3 -I $LANE/tools/bench_run.py --set "$SET" --template "$TPL" --limit "$LIM" --out "$OUT" \
      --max-minutes 26 --token-budget 4096
    rc=$?
    if [ $rc -ne 3 ]; then break; fi
  done
  echo $rc > "$LANE/logs/$STEM.done"
  if [ $rc -ne 0 ]; then break; fi
done
echo $rc > "$LANE/logs/$QNAME.done"
