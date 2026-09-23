#!/bin/bash
# ROUND 9l: the COMMITTED bytes of every record this round re-takes, with
# `git show HEAD:` BEFORE any is re-run.  The list (`records.txt`) is round
# 9k's thirty unchanged: every record the gate's tests guard by tool bytes
# (the 28 run development records and the two rung-G block records).  The
# other seventeen results/*/*.json that pin `zk60_native_rg_pcs.py` (the
# 125M run and block records, the two loader-equivalence records) are not
# guarded by any test and are not re-taken, as in rounds 9c, 9j and 9k.
set -e
W=/home/victor/wt-zk60-jointview
D=$W/results/zk60_native_run_gate_9l/before
mkdir -p $D
while read -r p; do
  [ -z "$p" ] && continue
  out="$D/$(echo "$p" | tr '/' '_').json"
  git --no-pager -C $W show "HEAD:results/$p.json" > "$out"
  cmp -s "$out" "$W/results/$p.json" && echo "$p -> $out (equal to the file on disk)" \
    || echo "$p -> $out (DIFFERS from the file on disk)"
done < $W/results/zk60_native_run_gate_9l/records.txt
