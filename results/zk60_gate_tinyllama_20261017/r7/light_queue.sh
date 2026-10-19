#!/bin/bash
# PRIVACY GATE lane, round 6 part (B): the gate (tools v8 = v7 + the R7
# readings + finding G-11's TOOLS list) on the bundles captured from the
# native lane's frozen R7 tree.  One guarded LIGHT job at a time
# (single-threaded Python; no heavy lock).  Each block waits for its bundles'
# manifest.json.  L = 1 and 2 in full; L = 22 pass A on both inputs.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/r7
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/scripts
V3=$GT/frozen_v3/scripts
V7=$GT/frozen_v7/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
X=$K/run-i-dense-k4
OLD=$K/run-a-tame
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
ST=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r2/stack-pg_rot1-ho00-gpu/run/statement/statement.json
EXP="--export $XP --statement $ST"
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v8.sha256 $GT > $P/light_queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/light_queue.finished; exit 4; }
mkdir -p $P/l1 $P/l2 $P/l22 $P/probe_before_repin
cd /tmp
g() {  # g <dir> <label> <need> <cap> <max> -- cmd...
  local d=$1 l=$2 n=$3 c=$4 m=$5; shift 6
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  local rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/light_queue.progress
}
wb() {  # wait for a bundle's manifest; give up if the heavy queue finished without it
  until [ -f $A/$1/manifest.json ]; do
    if [ -f $P/heavy_queue.finished ] && [ ! -f $A/$1/manifest.json ]; then
      echo "$(date -u +%H:%M:%S) no bundle $1; stopping" >> $P/light_queue.progress; date -u > $P/light_queue.finished; exit 6
    fi
    sleep 30
  done
}
B=tinyllama-trained-r7-capture
PA="load,replay,hash,terminals,commitments,boundary,preimage,export,channels"
ALL="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,export,channels"
M=$S/zk60_native_rg_m125.py
# ---- L = 2, layers 7-8
wb $B-dense-l2; wb $B-zero-l2
# FAILING-FIRST: the frozen v7 driver (no R7 readings) must refuse the moved pins
g probe_before_repin probe-v7-r7-l2-dense 1 2 900 -- python3 $V7/zk60_native_rg_m125.py --bundle $A/$B-dense-l2 --stages load,replay,hash,terminals,commitments,boundary,preimage --evidence $P/probe_before_repin --name probe-v7-r7-l2-dense
for w in dense zero; do g l2 predict-$w 1 1.5 600 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l2 --evidence $P/l2 --name prediction_r7_l2_$w; done
g l2 r7-l2-dense-a 1 2 1800 -- python3 $M --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --stages $PA $EXP --evidence $P/l2 --name r7-l2-dense-a
g l2 r7-l2-zero-a 1 2 1800 -- python3 $M --bundle $A/$B-zero-l2 --other $A/$B-dense-l2 --stages $PA $EXP --evidence $P/l2 --name r7-l2-zero-a
for w in dense zero; do g l2 r7-tl-controls-l2-$w 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-$w-l2 --evidence $P/l2 --name r7-tl-controls-l2-$w; done
g l2 r7-witcmp-l2 1 1.5 600 -- python3 $S/zk60_native_rg_witcmp.py --record $P/l2/r7-l2-dense-a.json --label "R7 layers 7..9 ho00 (dense)" --witness dense --record $P/l2/r7-l2-zero-a.json --label "R7 layers 7..9 all-zero" --witness zero --out $P/l2/r7-witness_comparison_l2.json
g l2 r7-g10-l2 1 2 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --legacy $V3 --evidence $P/l2 --name r7-g10-l2
# ---- L = 1, layer 0
wb $B-dense-l1; wb $B-zero-l1
for w in dense zero; do g l1 predict-$w 1 1.5 600 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l1 --evidence $P/l1 --name prediction_r7_l1_$w; done
g l1 r7-l1-dense-a 1 2 1800 -- python3 $M --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --stages $PA $EXP --evidence $P/l1 --name r7-l1-dense-a
g l1 r7-l1-zero-a 1 2 1800 -- python3 $M --bundle $A/$B-zero-l1 --other $A/$B-dense-l1 --stages $PA $EXP --evidence $P/l1 --name r7-l1-zero-a
g l1 r7-tl-controls-l1-dense 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-dense-l1 --evidence $P/l1 --name r7-tl-controls-l1-dense
g l1 r7-g10-l1 1 2 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --legacy $V3 --evidence $P/l1 --name r7-g10-l1
g l1 r7-pincontrols-l1 1 2 1800 -- python3 $S/zk60_native_rg_pincontrols.py --bundle $A/$B-dense-l1 --evidence $P/l1/pincontrols --name r7-pincontrols-l1
# ---- L = 1 and L = 2 everything, both inputs
g l1 r7-l1-dense-everything 1.5 3 5400 -- python3 $M --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l1 --name r7-l1-dense-everything
g l1 r7-l1-zero-everything 1.5 3 5400 -- python3 $M --bundle $A/$B-zero-l1 --other $A/$B-dense-l1 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l1 --name r7-l1-zero-everything
g l2 r7-l2-dense-everything 1.5 3 5400 -- python3 $M --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l2 --name r7-l2-dense-everything
g l2 r7-l2-zero-everything 1.5 3 5400 -- python3 $M --bundle $A/$B-zero-l2 --other $A/$B-dense-l2 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l2 --name r7-l2-zero-everything
# ---- L = 22, the whole stack: schema, G-10, pass A on both inputs
wb $B-dense-l22; wb $B-zero-l22
for w in dense zero; do g l22 predict-$w 1 1.5 900 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l22 --evidence $P/l22 --name prediction_r7_l22_$w; done
g l22 r7-schema 1.5 2.5 1800 -- python3 $S/zk60_native_rg_schema.py --bundle $A/$B-dense-l1 --bundle $A/$B-zero-l1 --bundle $A/$B-dense-l2 --bundle $A/$B-zero-l2 --bundle $A/$B-dense-l22 --bundle $A/$B-zero-l22 --controls --evidence $P --name r7-schema-six-bundles
g l22 r7-g10-l22 3 4 1800 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l22 --other $A/$B-zero-l22 --legacy $V3 --evidence $P/l22 --name r7-g10-l22
g l22 r7-l22-zero-a 6 7 5400 -- /usr/bin/time -v python3 $M --bundle $A/$B-zero-l22 --other $A/$B-dense-l22 --stages $PA $EXP --evidence $P/l22 --name r7-l22-zero-a
g l22 r7-l22-dense-a 6 7 5400 -- /usr/bin/time -v python3 $M --bundle $A/$B-dense-l22 --other $A/$B-zero-l22 --stages $PA $EXP --evidence $P/l22 --name r7-l22-dense-a
date -u > $P/light_queue.finished
