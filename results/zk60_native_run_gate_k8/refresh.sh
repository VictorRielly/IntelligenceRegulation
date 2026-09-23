#!/bin/bash
# ROUND 9i: all TWENTY-SIX development records of record re-run IN PLACE
# under this round's FINAL tool bytes, with the command lines round 9c's
# `refresh2.sh` used for them (each the command in its own round's run
# script), plus the mask port's toy-equivalence record.  Five tool files
# moved (`rg_gqa`, `rg_terminals`, `rg_mask`, `rg_runpins`,
# `rg_gcontrols`), all five in the gate's hashed TOOLS list, so every
# record's `tool_sha256` is stale until re-taken.  The 125M records are NOT
# re-taken: they have pinned pre-9c bytes since round 9c, deliberately.
# The baseline is `before/`, taken with `git show HEAD:` before this ran.
set -x
B=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
A=/home/victor/zk60-artifacts
W=/home/victor/wt-zk60-jointview
G=$W/scripts/zk60_native_run_gate.py
P=$W/results/zk60_native_run_gate_preimage
M=$W/results/zk60_native_run_gate_mask
Q=$W/results/zk60_native_run_gate_p2
N=$W/results/zk60_native_run_gate_9c
python3 $G --bundle $B/run-a-tame --other $B/run-b-zero --old $B/run-b-zero --evidence $W/results/zk60_native_run_gate
python3 $G --bundle $B/run-b-zero --other $B/run-a-tame --old $B/run-a-tame --evidence $W/results/zk60_native_run_gate
python3 $G --bundle $B/run-c-tame --other $B/run-d-zero --old $B/run-a-tame --evidence $W/results/zk60_native_run_gate_planeindex
python3 $G --bundle $B/run-d-zero --other $B/run-c-tame --old $B/run-b-zero --evidence $W/results/zk60_native_run_gate_planeindex
python3 $G --bundle $B/run-e-tame-tagged --other $B/run-f-zero-tagged --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $W/results/zk60_native_run_gate_tagged
python3 $G --bundle $B/run-f-zero-tagged --other $B/run-e-tame-tagged --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $W/results/zk60_native_run_gate_tagged
python3 $G --bundle $B/run-g-dense-s20 --other $B/run-h-zero-s20 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $W/results/zk60_native_run_gate_s20
python3 $G --bundle $B/run-h-zero-s20 --other $B/run-g-dense-s20 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $W/results/zk60_native_run_gate_s20
python3 $G --bundle $B/run-i-dense-k4 --other $B/run-j-zero-k4 --old $B/run-a-tame --cross-profile $B/run-g-dense-s20 --evidence $W/results/zk60_native_run_gate_k4
python3 $G --bundle $B/run-j-zero-k4 --other $B/run-i-dense-k4 --old $B/run-b-zero --cross-profile $B/run-h-zero-s20 --evidence $W/results/zk60_native_run_gate_k4
python3 $G --full-preimage --bundle $B/run-g-dense-s20 --other $B/run-h-zero-s20 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $P
python3 $G --full-preimage --bundle $B/run-h-zero-s20 --other $B/run-g-dense-s20 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $P
python3 $G --full-preimage --bundle $B/run-i-dense-k4 --other $B/run-j-zero-k4 --old $B/run-a-tame --cross-profile $B/run-g-dense-s20 --evidence $P
python3 $G --full-preimage --bundle $B/run-j-zero-k4 --other $B/run-i-dense-k4 --old $B/run-b-zero --cross-profile $B/run-h-zero-s20 --evidence $P
python3 $G --full-preimage --mask-cfs --bundle $B/run-g-dense-s20 --other $B/run-h-zero-s20 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $M
python3 $G --full-preimage --mask-cfs --bundle $B/run-h-zero-s20 --other $B/run-g-dense-s20 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $M
python3 $G --full-preimage --mask-cfs --bundle $B/run-i-dense-k4 --other $B/run-j-zero-k4 --old $B/run-a-tame --cross-profile $B/run-g-dense-s20 --evidence $M
python3 $G --full-preimage --mask-cfs --bundle $B/run-j-zero-k4 --other $B/run-i-dense-k4 --old $B/run-b-zero --cross-profile $B/run-h-zero-s20 --evidence $M
python3 $W/scripts/zk60_native_rg_mask.py --toy $W/results/zk60_native_captures_20260919/captures --evidence $M
python3 $G --full-preimage --mask-cfs --bundle $B/run-k-dense-p2 --other $B/run-l-zero-p2 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $Q
python3 $G --full-preimage --mask-cfs --bundle $B/run-l-zero-p2 --other $B/run-k-dense-p2 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $Q
python3 $G --full-preimage --mask-cfs --bundle $B/run-m-dense-c6 --other $B/run-n-zero-c6 --old $B/run-a-tame --cross-profile $B/run-k-dense-p2 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $B/run-n-zero-c6 --other $B/run-m-dense-c6 --old $B/run-b-zero --cross-profile $B/run-l-zero-p2 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $B/run-q-dense-e32 --other $B/run-r-zero-e32 --old $B/run-a-tame --cross-profile $B/run-m-dense-c6 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $B/run-r-zero-e32 --other $B/run-q-dense-e32 --old $B/run-b-zero --cross-profile $B/run-n-zero-c6 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $A/run-o-dense-w14 --other $A/run-p-zero-w14 --old $B/run-a-tame --cross-profile $B/run-q-dense-e32 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $A/run-p-zero-w14 --other $A/run-o-dense-w14 --old $B/run-b-zero --cross-profile $B/run-r-zero-e32 --evidence $N
echo "refresh finished"
