#!/bin/bash
# ROUND 9j: the COMMITTED bytes of every development record of record, taken
# with `git show HEAD:` BEFORE any is re-run.  The list (`records.txt`) is
# round 9i's twenty-seven plus the two rung-K8 records round 9i made --
# twenty-nine, checked against what is on disk (every results/*/run-*.json
# that names the run gate's tools, minus the 125M directory, whose records
# pin older bytes by round 9c's decision).
set -e
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_block/before
mkdir -p $D
while read -r p; do
  [ -z "$p" ] && continue
  out="$D/$(echo "$p" | tr '/' '__').json"
  git --no-pager -C $W show "HEAD:results/$p.json" > "$out"
  echo "$p -> $out"
done < $W/results/zk60_native_run_gate_block/records.txt
