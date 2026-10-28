#!/usr/bin/env bash
# Benchmark queue v2: each argument is SET:TEMPLATE:LIMIT:MAXCT:STRAT (0 = off for LIMIT/MAXCT/STRAT).
# Output bench/<set>_<template>[_le<MAXCT>][_strat<STRAT>].jsonl. Chunks of <=26 min are relaunched until done
# (bench_run exit 3 = time box). Honours $LANE/HOLD before every launch. Markers: logs/<stem>.done per job,
# logs/<QUEUE_NAME>.done at the end.
# Usage: bench_queue2.sh QUEUE_NAME NEED_GIB THREADS JOB ...
LANE=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021
GUARD=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
QNAME=$1; NEED=$2; THREADS=$3; shift 3
rc=0
for job in "$@"; do
  IFS=: read -r SET TPL LIM MAXCT STRAT <<< "$job"
  SUF=""; EXTRA=""
  if [ "$MAXCT" != "0" ]; then SUF="${SUF}_le${MAXCT}"; EXTRA="$EXTRA --max-content-tokens $MAXCT"; fi
  if [ "$STRAT" != "0" ]; then SUF="${SUF}_strat${STRAT}"; EXTRA="$EXTRA --strat-safe $STRAT"; fi
  STEM=bench_${SET}_${TPL}${SUF}_${LIM}
  OUT=$LANE/bench/${SET}_${TPL}${SUF}.jsonl
  for chunk in $(seq 1 60); do
    while [ -e "$LANE/HOLD" ]; do sleep 30; done
    python3 $GUARD run --class light --need-gib "$NEED" --cap-gib 1.8 --label "shieldstral-$STEM-c$chunk" \
      --wait-secs 14400 --max-secs 2100 --log "$LANE/logs/$STEM.log" \
      --done "$LANE/logs/$STEM.c$chunk.guard.done" --result-json "$LANE/logs/$STEM.c$chunk.guard.json" \
      -- /usr/bin/env OPENBLAS_NUM_THREADS=$THREADS OMP_NUM_THREADS=$THREADS \
      python3 -I $LANE/tools/bench_run.py --set "$SET" --template "$TPL" --limit "$LIM" --out "$OUT" \
      --max-minutes 26 --token-budget 4096 $EXTRA
    rc=$?
    if [ $rc -ne 3 ]; then break; fi
  done
  echo $rc > "$LANE/logs/$STEM.done"
  if [ $rc -ne 0 ]; then break; fi
done
echo $rc > "$LANE/logs/$QNAME.done"
