#!/bin/bash
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/p2
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
cd /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama || exit 3
sha256sum -c --quiet $E/gate-tinyllama.tools.frozen.v3.sha256 || { echo "TOOLS MOVED" > $P/light_queue.finished; exit 4; }
cd /tmp
g() { local l=$1 n=$2 k=$3 m=$4; shift 5
  python3 $G run --class light --need-gib $n --cap-gib $k --label tl-$l --wait-secs 7200 --max-secs $m --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  echo "$l exit $?" >> $P/light_queue.progress; }
g equivalence-k4-v3 1.5 3 3600 -- python3 $E/equivalence.py $K/run-i-dense-k4 $K/run-j-zero-k4 $P equivalence-k4-v3
g tl-l1-dense-runcontrols 1 2 1800 -- python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-dense-l1 --other $A/tinyllama-trained-capture-zero-l1 --stages load,replay,terminals,commitments,boundary,runcontrols,channels --cross-profile $K/run-i-dense-k4 --evidence $P --name tl-l1-dense-runcontrols
date -u > $P/light_queue.finished
