#!/bin/bash
# D63 lane L23 (2026-11-07): a bounded run of back-to-back iterations as ONE guarded job (run_guarded.py, class cpu),
# so that the edit-and-elaborate cycles of this lane share one admission. Iteration N starts when OUT/go.N appears; each
# runs iter.sh on OUT/plan.txt (as read at that moment) into OUT/loopN.log with its exit code in OUT/loopN.done. The job
# ends after 6 idle minutes without a go file, after 45 minutes in all, or when OUT/stop appears.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad9d55551b2c8d9df
OUT=$WT/results/zk60_lean_l23_20261107
start=$(date +%s)
n=1
while true; do
  waited=0
  while [ ! -e "$OUT/go.$n" ]; do
    [ -e "$OUT/stop" ] && { echo "stop file, $(( $(date +%s) - start )) s"; exit 0; }
    [ $waited -ge 360 ] && { echo "idle 360 s, ending after $((n - 1)) iterations, $(( $(date +%s) - start )) s"; exit 0; }
    [ $(( $(date +%s) - start )) -ge 2700 ] && { echo "45 minutes, ending after $((n - 1)) iterations"; exit 0; }
    sleep 2
    waited=$((waited + 2))
  done
  echo "== iteration $n at $(( $(date +%s) - start )) s =="
  /bin/bash "$OUT/iter.sh" "$OUT/plan.txt" > "$OUT/loop$n.log" 2>&1
  echo $? > "$OUT/loop$n.done"
  echo "iteration $n rc $(cat "$OUT/loop$n.done")"
  n=$((n + 1))
done
