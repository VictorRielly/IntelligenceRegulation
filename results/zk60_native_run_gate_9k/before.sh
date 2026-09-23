#!/bin/bash
# ROUND 9k: the COMMITTED bytes of every record this round re-takes, with
# `git show HEAD:` BEFORE any is re-run.  The list (`records.txt`) is round
# 9j's twenty-nine minus the toy-equivalence record (it hashes no tool, so the
# one tool this round moved cannot reach it) plus the two rung-G block
# records -- thirty, checked against every results/*/*.json that hashes
# `zk60_native_rg_block.py` (the four 125M block records and round 9j's
# failing-first probe are the only others; neither is re-taken).
set -e
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_9k/before
mkdir -p $D
while read -r p; do
  [ -z "$p" ] && continue
  out="$D/$(echo "$p" | tr '/' '_').json"
  git --no-pager -C $W show "HEAD:results/$p.json" > "$out"
  echo "$p -> $out"
done < $W/results/zk60_native_run_gate_9k/records.txt
