#!/bin/bash
# PRIVACY GATE lane, gate round 14 (DD), official queue B: frozen tools v17,
# everything + controls (full preimage, mask / CFS, the joint, the run
# controls; T128 also the export check). Declarations from the dev runs:
# rung L1 0.53 GiB / 260 s; T128 L1 1.3 GiB (dev11, first measurement).
. /home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round14/r14_common.sh
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v17.sha256 $GT/frozen_v17 > $P/r14_gate_b.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r14_gate_b.finished; exit 4; }
Q=r14_gate_b
EV="--controls --old $K/run-a-tame --legacy $K/run-a-tame --cross-profile $K/run-i-dense-k4"
g $Q v17 dd-rung-l1-dense-everything 1 2 3600 -- python3 $M --bundle $A/dd-rung-l1-dense --other $A/dd-rung-l1-zero --stages $ALL_RUNG $EV --evidence $P/v17 --name dd-rung-l1-dense-everything
g $Q v17 dd-rung-l1-zero-everything 1 2 3600 -- python3 $M --bundle $A/dd-rung-l1-zero --other $A/dd-rung-l1-dense --stages $ALL_RUNG $EV --evidence $P/v17 --name dd-rung-l1-zero-everything
g $Q v17 dd-rung-l2-dense-everything 1.2 2.5 5400 -- python3 $M --bundle $A/dd-rung-l2-dense --other $A/dd-rung-l2-zero --stages $ALL_RUNG $EV --evidence $P/v17 --name dd-rung-l2-dense-everything
g $Q v17 tl128dd-l2-dense-everything 2.5 5 10800 -- python3 $M --bundle $A/tl128dd-l2-dense --other $A/tl128dd-l2-zero --stages $ALL_T128 $EV --export $X --evidence $P/v17 --name tl128dd-l2-dense-everything
g $Q v17 tl128dd-l1-dense-everything 2 4 7200 -- python3 $M --bundle $A/tl128dd-l1-dense --other $A/tl128dd-l1-zero --stages $ALL_T128 $EV --export $X --evidence $P/v17 --name tl128dd-l1-dense-everything
date -u > $P/r14_gate_b.finished
