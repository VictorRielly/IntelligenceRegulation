#!/bin/bash
# stream.sh NAME WAITFILES -- "tag|model|export|corpora|need|extra args" ...
# Serial lane queue honouring the coordinator's budget request (lane total <= ~5 GiB):
# waits until every file in WAITFILES (colon-separated) exists, then runs each entry as ONE guarded
# light job (FP_ALLOW=1 passes the lane hold); skips entries whose summary.json exists.
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
NAME=$1; WAIT=$2; shift 3
IFS=':' read -ra WF <<< "$WAIT"
for f in "${WF[@]}"; do until [ -f "$f" ]; do sleep 20; done; done
echo "[$(date -u +%H:%M:%SZ)] stream $NAME released"
for ENTRY in "$@"; do
  IFS='|' read -r TAG MODEL EXPORT CORP NEED EXTRA <<< "$ENTRY"
  if [ -f $D/runs/$MODEL/$TAG/summary.json ]; then echo "skip $TAG"; continue; fi
  L=${NAME}_$TAG
  echo "[$(date -u +%H:%M:%SZ)] start $TAG ($MODEL $CORP need $NEED $EXTRA)"
  python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib $NEED \
    --cap-gib $(python3 -c "print($NEED+1)") --label fp-$L --wait-secs 21600 --max-secs 14400 --log $D/logs/$L.log \
    --done $D/logs/$L.guarddone --result-json $D/logs/$L.guard.json -- \
    /usr/bin/env OPENBLAS_NUM_THREADS=4 ZK60_MODEL=$MODEL FP_ALLOW=1 python3 $D/fp_eval.py --export $EXPORT --corpora $CORP --tag $TAG $EXTRA
  echo $? > $D/logs/$L.done
  echo "[$(date -u +%H:%M:%SZ)] end $TAG exit $(cat $D/logs/$L.done)"
done
echo "[$(date -u +%H:%M:%SZ)] stream $NAME finished"
