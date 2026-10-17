#!/bin/bash
# PRIVACY GATE lane, round 3: the records tools v4 require, one guarded LIGHT
# job at a time (single-threaded Python; no heavy lock).  Tool bytes checked
# against gate-tinyllama.tools.frozen.v4.sha256 first.  The L = 22 dense
# pass F runs only if every v4 check before it is ok (equivalence, G-10
# controls at L = 1 / 2 / 22 / rung-K4, inertness on every bundle on disk).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/v4
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
V3=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
python3 $P/freeze.py check $E/gate-tinyllama.tools.frozen.v4.sha256 /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama > $P/queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/queue.finished; exit 4; }
cd /tmp
g() {  # g <label> <need> <cap> <wait> <max> -- cmd...
  local l=$1 n=$2 c=$3 w=$4 m=$5; shift 6
  python3 $G run --class light --need-gib $n --cap-gib $c --label tl-$l --wait-secs $w --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  local rc=$?
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/queue.progress
}
okj() { python3 -c "import json,sys; sys.exit(0 if json.load(open('$1')).get('ok') is True else 1)"; }
g v4-equivalence-k4 1.5 3 7200 3600 -- python3 $E/equivalence.py $K/run-i-dense-k4 $K/run-j-zero-k4 $P equivalence-k4-v4
g v4-g10-l1 1 2 7200 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/tinyllama-trained-capture-dense-l1 --other $A/tinyllama-trained-capture-zero-l1 --legacy $V3 --evidence $P --name g10-l1
g v4-g10-l2 1 2 7200 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/tinyllama-trained-capture-dense-l2 --other $A/tinyllama-trained-capture-zero-l2 --legacy $V3 --evidence $P --name g10-l2
g v4-g10-k4 1 2 7200 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $K/run-i-dense-k4 --other $K/run-j-zero-k4 --legacy $V3 --evidence $P --name g10-k4
g v4-g10-l22 3 4 7200 1800 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/tinyllama-trained-capture-dense-l22 --other $A/tinyllama-trained-capture-zero-l22r2 --legacy $V3 --evidence $P --name g10-l22
g v4-integrity-inert 3 4 7200 3600 -- python3 $P/integrity_inert.py $P/integrity-inert.json
g v4-l1-dense-runcontrols 1 2 7200 1800 -- python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-dense-l1 --other $A/tinyllama-trained-capture-zero-l1 --stages load,replay,terminals,commitments,boundary,runcontrols,channels --cross-profile $K/run-i-dense-k4 --evidence $P --name tl-l1-dense-runcontrols-v4
g v4-l22-zero-m 1.5 3 7200 3600 -- python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-zero-l22r2 --stages load,replay,mask --controls --evidence $P --name tl-l22r2-zero-m
for r in equivalence-k4-v4 g10-l1 g10-l2 g10-k4 g10-l22 integrity-inert; do
  okj $P/$r.json || { echo "$(date -u +%H:%M:%S) GATE: $r not ok, pass F NOT started" >> $P/queue.progress; date -u > $P/queue.finished; exit 7; }
done
echo "$(date -u +%H:%M:%S) GATE: every v4 check ok, pass F queued" >> $P/queue.progress
g v4-l22-dense-f 6 7 14400 10800 -- /usr/bin/time -v python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-dense-l22 --other $A/tinyllama-trained-capture-zero-l22r2 --cross-profile $K/run-i-dense-k4 --stages load,replay,hash,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,channels --controls --evidence $P --name tl-l22-dense-f
date -u > $P/queue.finished
