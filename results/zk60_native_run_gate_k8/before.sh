#!/bin/bash
# ROUND 9i: the COMMITTED bytes of every development record of record,
# taken with `git show HEAD:` BEFORE any is re-run (the only baseline a leaf
# diff means anything against -- round 9b's lesson).  The list is BUILT
# FROM WHAT IS ON DISK (round 9c's advice): every `results/*/run-*.json`
# whose `tool_sha256` names the run gate's tools, minus the 125M records,
# which deliberately pin older bytes and are not re-taken (round 9c).
# Twenty-six records, plus the mask port's toy-equivalence record, which
# pins no tool hash but carries three of `rg_mask`'s constant tables.
set -e
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_k8/before
mkdir -p $D
while read -r p; do
  [ -z "$p" ] && continue
  out="$D/$(echo "$p" | tr '/' '__').json"
  git --no-pager -C $W show "HEAD:results/$p.json" > "$out"
  echo "$p -> $out"
done < $W/results/zk60_native_run_gate_k8/records.txt
