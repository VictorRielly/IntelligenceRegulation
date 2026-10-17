#!/bin/bash
# TINYLLAMA PORT: the gate on the two trained two-block bundles, through the
# staged driver (each stage's wall clock and peak RSS), one bundle at a time.
#   a <w>  pass A, the records of record (round 9's stage list, no controls)
#   b      the dense bundle through EVERY stage and EVERY control
#   c      the zero bundle's arms without controls
set -x
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
A=/home/victor/zk60-artifacts
P=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/l2
X=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-i-dense-k4
D=$A/tinyllama-trained-capture-dense-l2
Z=$A/tinyllama-trained-capture-zero-l2
PA="load,replay,hash,terminals,commitments,boundary,preimage,channels"
ALL="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,channels"
case "$1" in
  a) if [ "$2" = zero ]; then B=$Z; O=$D; else B=$D; O=$Z; fi
     /usr/bin/time -v python3 $S/zk60_native_rg_m125.py --bundle $B --other $O --stages $PA --evidence $P --name tl-$2-a 2> $P/time-tl-$2-a.log ;;
  b) /usr/bin/time -v python3 $S/zk60_native_rg_m125.py --bundle $D --other $Z --stages $ALL --controls --cross-profile $X --evidence $P --name tl-dense-everything 2> $P/time-tl-dense-everything.log ;;
  c) /usr/bin/time -v python3 $S/zk60_native_rg_m125.py --bundle $Z --other $D --stages load,replay,commitments,boundary,preimage,fullpreimage,mask,joint,channels --evidence $P --name tl-zero-arms 2> $P/time-tl-zero-arms.log ;;
esac
