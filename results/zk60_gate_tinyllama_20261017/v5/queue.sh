#!/bin/bash
# PRIVACY GATE lane, round 4 (after the independent review): the records tools
# v5 require, on the bundles already on disk (tree A; no R5 / R5b bundle yet).
# One guarded LIGHT job at a time; tool bytes checked against the v5 manifest.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/v5
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
V3=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
X=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
ST=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r2/stack-pg_rot1-ho00-gpu/run/statement/statement.json
B=tinyllama-trained-capture
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v5.sha256 /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama > $P/queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/queue.finished; exit 4; }
cd /tmp
g() {  # g <label> <need> <cap> <max> -- cmd...
  local l=$1 n=$2 c=$3 m=$4; shift 5
  python3 $G run --class light --need-gib $n --cap-gib $c --label tl-$l --wait-secs 14400 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  local rc=$?
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/queue.progress
}
g v5-unit-tests 1.5 3 900 -- python3 -m unittest discover -s /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/tests
g v5-verdicts 1 2 600 -- python3 $P/verdicts_unchanged.py $P/verdicts-unchanged.json
g v5-equivalence-k4 1.5 3 3600 -- python3 $E/equivalence.py $K/run-i-dense-k4 $K/run-j-zero-k4 $P equivalence-k4-v5
g v5-pincontrols-l1 1 2 1800 -- python3 $S/zk60_native_rg_pincontrols.py --bundle $A/$B-dense-l1 --evidence $P/pincontrols --name pincontrols-l1
g v5-g10-l1 1 2 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --legacy $V3 --evidence $P --name g10-l1
g v5-g10-l2 1 2 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --legacy $V3 --evidence $P --name g10-l2
g v5-g10-l22 3 4 1800 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l22 --other $A/$B-zero-l22r2 --legacy $V3 --evidence $P --name g10-l22
g v5-export-l1 1 2 900 -- python3 $S/zk60_native_rg_exportcheck.py --bundle $A/$B-dense-l1 --export $X --statement $ST --record $E/l1/tl-l1-dense-a.json --controls --evidence $P --name export-l1-dense
g v5-export-l2-dense 1 2 900 -- python3 $S/zk60_native_rg_exportcheck.py --bundle $A/$B-dense-l2 --export $X --statement $ST --record $E/l2/tl-dense-a.json --controls --evidence $P --name export-l2-dense
g v5-export-l2-zero 1 2 900 -- python3 $S/zk60_native_rg_exportcheck.py --bundle $A/$B-zero-l2 --export $X --statement $ST --record $E/l2/tl-zero-a.json --controls --evidence $P --name export-l2-zero
g v5-export-l22-dense 2 3 1800 -- python3 $S/zk60_native_rg_exportcheck.py --bundle $A/$B-dense-l22 --export $X --statement $ST --record $E/l22/tl-l22-dense-a.json --controls --evidence $P --name export-l22-dense
g v5-export-l22-zero 2 3 1800 -- python3 $S/zk60_native_rg_exportcheck.py --bundle $A/$B-zero-l22r2 --export $X --statement $ST --record $E/l22/tl-l22r2-zero-arms.json --controls --evidence $P --name export-l22-zero
g v5-schema 1.5 2.5 1800 -- python3 $S/zk60_native_rg_schema.py --bundle $A/$B-dense-l1 --bundle $A/$B-zero-l1 --bundle $A/$B-dense-l2 --bundle $A/$B-zero-l2 --bundle $A/$B-dense-l22 --bundle $A/$B-zero-l22r2 --controls --evidence $P --name schema-six-bundles
g v5-tl4-l22 2.5 3.5 3600 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-dense-l22 --only TL-4 --evidence $P --name tl4-l22-dense
g v5-tl-l2 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-dense-l2 --evidence $P --name tl-controls-l2-dense
g v5-ct4-ch6-l2 1.5 3 3600 -- python3 $S/zk60_native_rg_m125.py --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --stages load,replay,terminals,commitments,boundary,preimage,runcontrols,export,channels --controls --old $K/run-a-tame --legacy $K/run-a-tame --cross-profile $K/run-i-dense-k4 --export $X --statement $ST --evidence $P --name tl-l2-dense-t-v5
date -u > $P/queue.finished
