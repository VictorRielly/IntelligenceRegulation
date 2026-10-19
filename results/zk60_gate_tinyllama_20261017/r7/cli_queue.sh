#!/bin/bash
# PRIVACY GATE lane, round 6 part (B), review item P-18: the gate (tools v8)
# on the bundle captured from a run directory the R7 CLI itself proved
# (`stack-prove`) and a fresh process verified (`stack-verify`:
# statement-published), layers 7-8 on ho00 (the P-18 helper, EV/r7cli/).
# Its partner bundle (`--other`) is this lane's R7 harness capture of the same
# layers on the all-zero input.  Guarded LIGHT jobs, one at a time.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/r7
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/scripts
V3=$GT/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
X=$K/run-i-dense-k4
OLD=$K/run-a-tame
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
ST=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r2/stack-pg_rot1-ho00-gpu/run/statement/statement.json
EXP="--export $XP --statement $ST"
CLI=tinyllama-cli-r7-capture-dense-l2
Z=tinyllama-trained-r7-capture-zero-l2
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v8.sha256 $GT > $P/cli_queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/cli_queue.finished; exit 4; }
mkdir -p $P/cli
sha256sum $A/$CLI/manifest.json > $P/cli/cli-bundle-manifest.sha256
cd /tmp
g() {  # g <label> <need> <cap> <max> -- cmd...
  local l=$1 n=$2 c=$3 m=$4; shift 5
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/cli/$l.log --done $P/cli/$l.done --result-json $P/cli/$l.guard.json -- "$@"
  echo "$(date -u +%H:%M:%S) $l exit $?" >> $P/cli_queue.progress
}
until [ -f $A/$Z/manifest.json ]; do
  if [ -f $P/heavy_queue.finished ] && [ ! -f $A/$Z/manifest.json ]; then echo "no $Z" > $P/cli_queue.finished; exit 6; fi
  sleep 30
done
PA="load,replay,hash,terminals,commitments,boundary,preimage,export,channels"
ALL="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,export,channels"
M=$S/zk60_native_rg_m125.py
g predict-cli 1 1.5 600 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$CLI --evidence $P/cli --name prediction_r7_cli_l2_dense
g r7-cli-l2-dense-a 1 2 1800 -- python3 $M --bundle $A/$CLI --other $A/$Z --stages $PA $EXP --evidence $P/cli --name r7-cli-l2-dense-a
g r7-cli-l2-dense-everything 1.5 3 5400 -- python3 $M --bundle $A/$CLI --other $A/$Z --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/cli --name r7-cli-l2-dense-everything
g r7-cli-schema 1 2 900 -- python3 $S/zk60_native_rg_schema.py --bundle $A/$CLI --controls --evidence $P/cli --name r7-cli-schema
g r7-cli-g10 1 2 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$CLI --other $A/$Z --legacy $V3 --evidence $P/cli --name r7-cli-g10
g r7-cli-tl-controls 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$CLI --evidence $P/cli --name r7-cli-tl-controls
date -u > $P/cli_queue.finished
