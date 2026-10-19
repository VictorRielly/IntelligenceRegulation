#!/bin/bash
# serial queue: queue.sh NAME MODEL EXPORT CORPORA NEED CAP MAXSECS -- "tag|extra args" ...
# runs each entry through run.sh (one guarded light job at a time), skipping entries whose summary exists
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
NAME=$1; MODEL=$2; EXPORT=$3; CORP=$4; NEED=$5; CAP=$6; MAXS=$7; shift 8
for ENTRY in "$@"; do
  TAG=${ENTRY%%|*}; EXTRA=${ENTRY#*|}
  [ "$EXTRA" = "$ENTRY" ] && EXTRA=""
  if [ -f $D/runs/$MODEL/$TAG/summary.json ]; then echo "skip $TAG"; continue; fi
  echo "[$(date -u +%H:%M:%SZ)] start $TAG ($EXTRA)"
  $D/logs/run.sh ${NAME}_$TAG $NEED $CAP $MAXS $MODEL $D/fp_eval.py --export $EXPORT --corpora $CORP --tag $TAG $EXTRA
  echo "[$(date -u +%H:%M:%SZ)] end $TAG exit $(cat $D/logs/${NAME}_$TAG.done)"
done
