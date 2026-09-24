#!/bin/bash
# ROUND 9m: ONE pass of the staged 125M driver on a TWELVE-block bundle.
#   bash l12.sh <a|m|f> <dense|zero>
# a  the records of record (R9m.2 pass A): load, replay, hash, terminals,
#    commitments, boundary, preimage, channels -- no arm, no --controls
#    (stage 3's per-clause exclusivity controls run regardless, as at 9l)
# m  the mask / CFS arm per stage with M1..M6 (pass M): load, replay, mask
# f  every arm plus every control whose cost is per stage or per boundary
#    (pass F): P-1..P-6, M1..M6, X01..X16, C1..C6 (C5 against the other
#    twelve-block bundle), CH-1..CH-7 (CH-7 against rung-K4), M9-1, M9-2.
#    No terminal stage, so no CT / GQ / M9-3 (pass T, NOT RUN: R9m.2).
# Each pass writes its record into this directory; `/usr/bin/time -v` goes
# to time-<name>.log.  Tool bytes are frozen before the queue starts.
set -x
A=/home/victor/zk60-artifacts
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
W=/home/victor/wt-zk60-jointview
D=$W/scripts/zk60_native_rg_m125.py
E=$W/results/zk60_native_run_gate_9m
pass=$1
wit=$2
other=$([ "$wit" = dense ] && echo zero || echo dense)
case $pass in
  a) S=load,replay,hash,terminals,commitments,boundary,preimage,channels; X="";;
  m) S=load,replay,mask; X="--controls";;
  f) S=load,replay,hash,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,channels
     X="--controls --other $A/m125-capture-$other-l12 --cross-profile $B/run-i-dense-k4";;
  *) echo "unknown pass $pass"; exit 2;;
esac
name=l12-$wit-$pass
/usr/bin/time -v python3 -u $D --bundle $A/m125-capture-$wit-l12 --evidence $E --name $name --stages $S $X 2> $E/time-$name.log
