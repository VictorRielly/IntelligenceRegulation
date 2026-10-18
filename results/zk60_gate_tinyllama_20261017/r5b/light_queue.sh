#!/bin/bash
# PRIVACY GATE lane, round 5: the gate (tools v6 = v5 + the R5b readings) on
# the bundles captured from the native lane's frozen R5b tree.  One guarded
# LIGHT job at a time (single-threaded Python; no heavy lock).  Each block
# waits for its bundles' manifest.json; the L22 passes declare 6 / 7 GiB.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/r5b
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
V3=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
X=$K/run-i-dense-k4
OLD=$K/run-a-tame
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
ST=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r2/stack-pg_rot1-ho00-gpu/run/statement/statement.json
EXP="--export $XP --statement $ST"
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v6.sha256 /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama > $P/light_queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/light_queue.finished; exit 4; }
mkdir -p $P/l1 $P/l2 $P/l22
cd /tmp
g() {  # g <dir> <label> <need> <cap> <max> -- cmd...
  local d=$1 l=$2 n=$3 c=$4 m=$5; shift 6
  python3 $G run --class light --need-gib $n --cap-gib $c --label tl-$l --wait-secs 21600 --max-secs $m \
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
B=tinyllama-trained-r5b-capture
PA="load,replay,hash,terminals,commitments,boundary,preimage,export,channels"
ALL="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,export,channels"
F="load,replay,hash,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,export,channels"
T="load,replay,terminals,commitments,boundary,preimage,runcontrols,export,channels"
M=$S/zk60_native_rg_m125.py
g l2 v6-equivalence-k4 1.5 3 3600 -- python3 $E/v5/equivalence_v5.py $X $K/run-j-zero-k4 $P/l2 equivalence-k4-v6
# ---- L = 2, layers 7-8
wb $B-dense-l2; wb $B-zero-l2
for w in dense zero; do g l2 predict-$w 1 1.5 600 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l2 --evidence $P/l2 --name prediction_r5b_l2_$w; done
g l2 r5b-l2-dense-a 1 2 1800 -- python3 $M --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --stages $PA $EXP --evidence $P/l2 --name r5b-l2-dense-a
g l2 r5b-l2-zero-a 1 2 1800 -- python3 $M --bundle $A/$B-zero-l2 --other $A/$B-dense-l2 --stages $PA $EXP --evidence $P/l2 --name r5b-l2-zero-a
for w in dense zero; do g l2 r5b-tl-controls-l2-$w 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-$w-l2 --evidence $P/l2 --name r5b-tl-controls-l2-$w; done
g l2 r5b-witcmp-l2 1 1.5 600 -- python3 $S/zk60_native_rg_witcmp.py --record $P/l2/r5b-l2-dense-a.json --label "R5b layers 7..9 ho00 (dense)" --witness dense --record $P/l2/r5b-l2-zero-a.json --label "R5b layers 7..9 all-zero" --witness zero --out $P/l2/r5b-witness_comparison_l2.json
g l2 r5b-g10-l2 1 2 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --legacy $V3 --evidence $P/l2 --name r5b-g10-l2
# ---- L = 1, layer 0
wb $B-dense-l1; wb $B-zero-l1
for w in dense zero; do g l1 predict-$w 1 1.5 600 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l1 --evidence $P/l1 --name prediction_r5b_l1_$w; done
g l1 r5b-l1-dense-a 1 2 1800 -- python3 $M --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --stages $PA $EXP --evidence $P/l1 --name r5b-l1-dense-a
g l1 r5b-l1-zero-a 1 2 1800 -- python3 $M --bundle $A/$B-zero-l1 --other $A/$B-dense-l1 --stages $PA $EXP --evidence $P/l1 --name r5b-l1-zero-a
g l1 r5b-tl-controls-l1-dense 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-dense-l1 --evidence $P/l1 --name r5b-tl-controls-l1-dense
g l1 r5b-g10-l1 1 2 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --legacy $V3 --evidence $P/l1 --name r5b-g10-l1
g l1 r5b-pincontrols-l1 1 2 1800 -- python3 $S/zk60_native_rg_pincontrols.py --bundle $A/$B-dense-l1 --evidence $P/l1/pincontrols --name r5b-pincontrols-l1
g l1 r5b-l1-dense-everything 1.5 3 5400 -- python3 $M --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l1 --name r5b-l1-dense-everything
# ---- L = 2 everything, both bundles
g l2 r5b-l2-dense-everything 1.5 3 5400 -- python3 $M --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l2 --name r5b-l2-dense-everything
g l2 r5b-l2-zero-everything 1.5 3 5400 -- python3 $M --bundle $A/$B-zero-l2 --other $A/$B-dense-l2 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l2 --name r5b-l2-zero-everything
# ---- L = 22, the whole stack
wb $B-dense-l22; wb $B-zero-l22
for w in dense zero; do g l22 predict-$w 1 1.5 900 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l22 --evidence $P/l22 --name prediction_r5b_l22_$w; done
g l22 r5b-schema 1.5 2.5 1800 -- python3 $S/zk60_native_rg_schema.py --bundle $A/$B-dense-l1 --bundle $A/$B-zero-l1 --bundle $A/$B-dense-l2 --bundle $A/$B-zero-l2 --bundle $A/$B-dense-l22 --bundle $A/$B-zero-l22 --controls --evidence $P --name r5b-schema-six-bundles
g l22 r5b-g10-l22 3 4 1800 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l22 --other $A/$B-zero-l22 --legacy $V3 --evidence $P/l22 --name r5b-g10-l22
g l22 r5b-tl4-l22 2.5 3.5 3600 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-dense-l22 --only TL-4 --evidence $P/l22 --name r5b-tl4-l22-dense
g l22 r5b-l22-dense-t 6 7 10800 -- /usr/bin/time -v python3 $M --bundle $A/$B-dense-l22 --other $A/$B-zero-l22 --cross-profile $X --old $OLD --legacy $OLD --stages $T --controls $EXP --evidence $P/l22 --name r5b-l22-dense-t
g l22 r5b-l22-zero-a 6 7 5400 -- /usr/bin/time -v python3 $M --bundle $A/$B-zero-l22 --other $A/$B-dense-l22 --stages $PA $EXP --evidence $P/l22 --name r5b-l22-zero-a
g l22 r5b-l22-dense-f 6 7 10800 -- /usr/bin/time -v python3 $M --bundle $A/$B-dense-l22 --other $A/$B-zero-l22 --cross-profile $X --legacy $OLD --stages $F --controls $EXP --evidence $P/l22 --name r5b-l22-dense-f
g l22 r5b-l22-zero-f 6 7 10800 -- /usr/bin/time -v python3 $M --bundle $A/$B-zero-l22 --other $A/$B-dense-l22 --cross-profile $X --legacy $OLD --stages $F --controls $EXP --evidence $P/l22 --name r5b-l22-zero-f
date -u > $P/light_queue.finished
