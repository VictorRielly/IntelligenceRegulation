#!/bin/bash
# ROUND 9m: the COMMITTED bytes of every record this round re-takes, with
# `git show HEAD:` BEFORE any is re-run.  The list (`records.txt`) is round
# 9l's thirty -- every record the gate's tests guard by tool bytes (the 28
# run development records and the two rung-G block records) -- checked
# against what is on disk (R9c's lesson): 49 results/*/*.json pin
# `zk60_native_rg_bundle.py`, and the nineteen not listed are the 125M run
# and block records and the two loader-equivalence records, which no test
# guards and which are not re-taken, as in rounds 9c, 9j, 9k and 9l.
set -e
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_9m/before
mkdir -p $D
while read -r p; do
  [ -z "$p" ] && continue
  out="$D/$(echo "$p" | tr '/' '_').json"
  git --no-pager -C $W show "HEAD:results/$p.json" > "$out"
  cmp -s "$out" "$W/results/$p.json" && echo "$p -> $out (equal to the file on disk)" \
    || echo "$p -> $out (DIFFERS from the file on disk)"
done < $W/results/zk60_native_run_gate_9m/records.txt
