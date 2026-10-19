#!/bin/bash
# PRIVACY GATE lane, round 6: tools v7 (G-4 tightened per review Q-8: M9-3 in
# two arms; PC-9b; G-10 legacy loader restores sys.path) on the R5b bundles.
# Guarded LIGHT jobs, one at a time (single-threaded Python; no heavy lock).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/v7
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
V3=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
X=$K/run-i-dense-k4
OLD=$K/run-a-tame
B=tinyllama-trained-r5b-capture
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v7.sha256 /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama > $P/v7_queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/v7_queue.finished; exit 4; }
python3 -m unittest discover -s /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/tests > $P/v7-unittests.log 2>&1
echo "$(date -u +%H:%M:%S) unittests exit $?" >> $P/v7_queue.progress
cd /tmp
g() {  # g <label> <need> <cap> <max> -- cmd...
  local l=$1 n=$2 c=$3 m=$4; shift 5
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  echo "$(date -u +%H:%M:%S) $l exit $?" >> $P/v7_queue.progress
}
T="load,replay,terminals,commitments,boundary,runcontrols"
CT="--controls --old $OLD --legacy $OLD --cross-profile $X"
g v7-l1-dense-t 1 2 1800 -- python3 $S/zk60_native_rg_m125.py --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --stages $T $CT --evidence $P --name v7-l1-dense-t
g v7-l2-dense-t 1.5 2.5 2700 -- python3 $S/zk60_native_rg_m125.py --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --stages $T $CT --evidence $P --name v7-l2-dense-t
g v7-l2-zero-t 1.5 2.5 2700 -- python3 $S/zk60_native_rg_m125.py --bundle $A/$B-zero-l2 --other $A/$B-dense-l2 --stages $T $CT --evidence $P --name v7-l2-zero-t
for x in "l1-dense:$E/r5b/l1/r5b-l1-dense-everything.json" "l2-dense:$E/r5b/l2/r5b-l2-dense-everything.json" "l2-zero:$E/r5b/l2/r5b-l2-zero-everything.json"; do
  n=${x%%:*}; old=${x#*:}
  python3 $P/leafdiff_v7.py $old $P/v7-$n-t.json $P/leafdiff-v7-$n.json >> $P/v7-leafdiff.log 2>&1
  echo "$(date -u +%H:%M:%S) leafdiff $n exit $?" >> $P/v7_queue.progress
done
mkdir -p $P/pincontrols
g v7-pincontrols-r5b-l1 1 2 1800 -- python3 $S/zk60_native_rg_pincontrols.py --bundle $A/$B-dense-l1 --evidence $P/pincontrols --name v7-pincontrols-r5b-l1
g v7-pincontrols-treea-l1 1 2 1800 -- python3 $S/zk60_native_rg_pincontrols.py --bundle $A/tinyllama-trained-capture-dense-l1 --evidence $P/pincontrols --name v7-pincontrols-treea-l1
g v7-g10-l1 1 2 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --legacy $V3 --evidence $P --name v7-g10-l1
date -u > $P/v7_queue.finished
