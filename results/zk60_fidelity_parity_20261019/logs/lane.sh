#!/bin/bash
# lane.sh NAME JOBFILE WAITSPEC
# Two-lane scheduler honouring the coordinator's cap (two TinyLlama-size jobs, or one 8B job):
#   lane X (priority: 8B + small checks), lane Y (TinyLlama). A WEIGHT-2 job in lane X takes
#   logs/laneY.lock, so lane Y (which takes the same lock around each of its jobs) pauses while it runs.
# JOBFILE lines: LABEL|NEED_GIB|WEIGHT|MODEL|script args...   (script relative to the lane dir)
#   read one line at a time (the file may grow); a line END stops the lane.
# WAITSPEC: colon-separated files (or grep:FILE:PATTERN) that must exist before the lane starts.
D=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019
NAME=$1; JOBS=$2; WAIT=$3
IFS=':' read -ra WF <<< "$WAIT"
i=0
while [ $i -lt ${#WF[@]} ]; do
  f=${WF[$i]}
  if [ "$f" = "grep" ]; then FILE=${WF[$((i+1))]}; PAT=${WF[$((i+2))]}; i=$((i+3))
    until grep -q "$PAT" "$FILE" 2>/dev/null; do sleep 20; done
  else i=$((i+1)); until [ -f "$f" ]; do sleep 20; done; fi
done
echo "[$(date -u +%H:%M:%SZ)] lane $NAME released"
n=1
while true; do
  LINE=$(sed -n "${n}p" "$JOBS")
  if [ -z "$LINE" ]; then sleep 30; continue; fi
  [ "$LINE" = "END" ] && break
  n=$((n+1))
  IFS='|' read -r LABEL NEED W MODEL CMD <<< "$LINE"
  if [ -f $D/logs/L_$LABEL.done ] && [ "$(cat $D/logs/L_$LABEL.done)" = "0" ]; then echo "skip $LABEL"; continue; fi
  rm -f $D/logs/HOLD2_$LABEL
  run_job() {
    echo "[$(date -u +%H:%M:%SZ)] start $LABEL (need $NEED weight $W $MODEL $CMD)"
    python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class light --need-gib $NEED \
      --cap-gib $(python3 -c "print($NEED+1)") --label fp-L_$LABEL --wait-secs 21600 --max-secs 14400 --log $D/logs/L_$LABEL.log \
      --done $D/logs/L_$LABEL.guarddone --result-json $D/logs/L_$LABEL.guard.json -- \
      /usr/bin/env OPENBLAS_NUM_THREADS=4 ZK60_MODEL=$MODEL FP_ALLOW=1 python3 $D/$CMD
    echo $? > $D/logs/L_$LABEL.done
    echo "[$(date -u +%H:%M:%SZ)] end $LABEL exit $(cat $D/logs/L_$LABEL.done)"
  }
  if [ "$NAME" = "Y" ]; then
    while [ -f $D/logs/X_wants ]; do sleep 5; done
    ( flock 9; run_job ) 9>$D/logs/laneY.lock
  elif [ "$W" = "2" ]; then
    touch $D/logs/X_wants
    ( flock 9; rm -f $D/logs/X_wants; run_job ) 9>$D/logs/laneY.lock
  else
    run_job
  fi
done
echo "[$(date -u +%H:%M:%SZ)] lane $NAME finished"
