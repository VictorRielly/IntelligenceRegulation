#!/bin/bash
# ROUND 9l: the twenty-eight RUN development records of record re-run IN PLACE
# under this round's FROZEN tool bytes, with round 9j's / 9k's command lines
# unchanged (results/zk60_native_run_gate_9k/refresh.sh).  Moved in the
# gate's hashed TOOLS list: zk60_native_run_gate.py, zk60_native_rg_pcs.py,
# zk60_native_rg_joint.py (changed) and zk60_native_rg_exclusivity.py (new)
# -- the exact u-term, the sixteen-clause H-pair and its per-clause controls
# (ruling GC-2).  The toy-equivalence record hashes no tool and is not
# re-taken; the 125M records are not re-taken (no test guards their tool
# bytes).
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
python3 $G --full-preimage --mask-cfs --bundle $B/run-k-dense-p2 --other $B/run-l-zero-p2 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $Q
python3 $G --full-preimage --mask-cfs --bundle $B/run-l-zero-p2 --other $B/run-k-dense-p2 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $Q
python3 $G --full-preimage --mask-cfs --bundle $B/run-m-dense-c6 --other $B/run-n-zero-c6 --old $B/run-a-tame --cross-profile $B/run-k-dense-p2 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $B/run-n-zero-c6 --other $B/run-m-dense-c6 --old $B/run-b-zero --cross-profile $B/run-l-zero-p2 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $B/run-q-dense-e32 --other $B/run-r-zero-e32 --old $B/run-a-tame --cross-profile $B/run-m-dense-c6 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $B/run-r-zero-e32 --other $B/run-q-dense-e32 --old $B/run-b-zero --cross-profile $B/run-n-zero-c6 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $A/run-o-dense-w14 --other $A/run-p-zero-w14 --old $B/run-a-tame --cross-profile $B/run-q-dense-e32 --evidence $N
python3 $G --full-preimage --mask-cfs --bundle $A/run-p-zero-w14 --other $A/run-o-dense-w14 --old $B/run-b-zero --cross-profile $B/run-r-zero-e32 --evidence $N
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260922_k8
python3 $G --full-preimage --mask-cfs --bundle $K/run-s-dense-k8 --other $K/run-t-zero-k8 --old $B/run-a-tame --cross-profile $B/run-i-dense-k4 --evidence $W/results/zk60_native_run_gate_k8
python3 $G --full-preimage --mask-cfs --bundle $K/run-t-zero-k8 --other $K/run-s-dense-k8 --old $B/run-b-zero --cross-profile $B/run-j-zero-k4 --evidence $W/results/zk60_native_run_gate_k8
echo "refresh finished"
