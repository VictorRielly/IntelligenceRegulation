#!/bin/bash
# PRIVACY GATE lane, gate round 10, the frozen-r9 re-pin: the gate on the
# bundles captured from the gate's tk9 copy, the plan of the tk7 re-pin (and
# of round 6 (B) on R7): L = 1 and 2 in full, both inputs.  Queue A of two;
# queue B (gate_queue_l22.sh) takes L = 22.
#   FAILING FIRST: frozen v14 (no tk9 reading) must refuse run.rs cc2c4204 by name.
#   Then tools v15 (frozen_v15 = v14 + the tk9 reading of run.rs).
# Queue rules: declarations from the tk7 measured peaks plus a margin; a
# hold-file check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/tk9
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v15/scripts
V14=$GT/frozen_v14/scripts
V3=$GT/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
HOLDF=$E/HOLD
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
X=$K/run-i-dense-k4
OLD=$K/run-a-tame
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
ST=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r2/stack-pg_rot1-ho00-gpu/run/statement/statement.json
EXP="--export $XP --statement $ST"
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v15.sha256 $GT/frozen_v15 > $P/gate_queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/gate_queue.finished; exit 4; }
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v14.sha256 $GT/frozen_v14 >> $P/gate_queue.toolcheck 2>&1 || { echo "V14 MOVED" > $P/gate_queue.finished; exit 4; }
mkdir -p $P/l1 $P/l2 $P/l22 $P/probe_before_repin $P/suite
cd /tmp
g() {  # g <dir> <label> <need> <cap> <max> -- cmd...
  local d=$1 l=$2 n=$3 c=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/gate_queue.progress
  return $rc
}
wb() {  # wait for a bundle's manifest; give up if the heavy queue finished without it
  until [ -f $A/$1/manifest.json ]; do
    if [ -f $P/heavy_queue.done ] && [ ! -f $A/$1/manifest.json ]; then
      echo "$(date -u +%H:%M:%S) no bundle $1; stopping" >> $P/gate_queue.progress; date -u > $P/gate_queue.finished; exit 6
    fi
    sleep 30
  done
  sleep 5
}
B=tinyllama-trained-tk9-capture
PA="load,replay,hash,terminals,commitments,boundary,preimage,export,channels"
ALL="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,export,channels"
M=$S/zk60_native_rg_m125.py
# ---- L = 2, layers 7-8
wb $B-dense-l2; wb $B-zero-l2
# FAILING FIRST (tk7 measured 0.1 GiB)
g probe_before_repin probe-v14-tk9-l2-dense 0.5 1.5 900 -- python3 $V14/zk60_native_rg_m125.py --bundle $A/$B-dense-l2 --stages load,replay,hash,terminals,commitments,boundary,preimage --evidence $P/probe_before_repin --name probe-v14-tk9-l2-dense
# measured (tk7): pass A 0.18, TL 0.16, witcmp 0.0, G-10 0.19, validated prediction 0.16 GiB
g l2 tk9-l2-dense-a 0.5 1.5 1800 -- python3 $M --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --stages $PA $EXP --evidence $P/l2 --name tk9-l2-dense-a
g l2 tk9-l2-zero-a 0.5 1.5 1800 -- python3 $M --bundle $A/$B-zero-l2 --other $A/$B-dense-l2 --stages $PA $EXP --evidence $P/l2 --name tk9-l2-zero-a
for w in dense zero; do g l2 predict-validated-$w 0.5 1.5 1200 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l2 --validate $A/$B-$w-l2:$P/l2/tk9-l2-$w-a.json --evidence $P/l2 --name prediction_tk9_l2_${w}_validated; done
for w in dense zero; do g l2 tk9-tl-controls-l2-$w 0.5 1.5 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-$w-l2 --evidence $P/l2 --name tk9-tl-controls-l2-$w; done
g l2 tk9-witcmp-l2 0.3 1 600 -- python3 $S/zk60_native_rg_witcmp.py --record $P/l2/tk9-l2-dense-a.json --label "tk9 layers 7..9 ho00 (dense)" --witness dense --record $P/l2/tk9-l2-zero-a.json --label "tk9 layers 7..9 all-zero" --witness zero --out $P/l2/tk9-witness_comparison_l2.json
g l2 tk9-g10-l2 0.5 1.5 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --legacy $V3 --evidence $P/l2 --name tk9-g10-l2
# ---- L = 1, layer 0 (measured (tk7): pass A 0.13, TL 0.14, G-10 0.14, PC 0.15 GiB)
wb $B-dense-l1; wb $B-zero-l1
g l1 tk9-l1-dense-a 0.5 1.5 1800 -- python3 $M --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --stages $PA $EXP --evidence $P/l1 --name tk9-l1-dense-a
g l1 tk9-l1-zero-a 0.5 1.5 1800 -- python3 $M --bundle $A/$B-zero-l1 --other $A/$B-dense-l1 --stages $PA $EXP --evidence $P/l1 --name tk9-l1-zero-a
for w in dense zero; do g l1 predict-validated-$w 0.5 1.5 1200 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l1 --validate $A/$B-$w-l1:$P/l1/tk9-l1-$w-a.json --evidence $P/l1 --name prediction_tk9_l1_${w}_validated; done
g l1 tk9-tl-controls-l1-dense 0.5 1.5 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$B-dense-l1 --evidence $P/l1 --name tk9-tl-controls-l1-dense
g l1 tk9-g10-l1 0.5 1.5 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --legacy $V3 --evidence $P/l1 --name tk9-g10-l1
g l1 tk9-pincontrols-l1 0.5 1.5 1800 -- python3 $S/zk60_native_rg_pincontrols.py --bundle $A/$B-dense-l1 --evidence $P/l1/pincontrols --name tk9-pincontrols-l1
# ---- L = 1 and L = 2 everything, both inputs (measured (tk7): 0.70-0.83 GiB, 14-18 min)
g l1 tk9-l1-dense-everything 1.2 2 5400 -- python3 $M --bundle $A/$B-dense-l1 --other $A/$B-zero-l1 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l1 --name tk9-l1-dense-everything
g l1 tk9-l1-zero-everything 1.2 2 5400 -- python3 $M --bundle $A/$B-zero-l1 --other $A/$B-dense-l1 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l1 --name tk9-l1-zero-everything
g l2 tk9-l2-dense-everything 1.2 2 5400 -- python3 $M --bundle $A/$B-dense-l2 --other $A/$B-zero-l2 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l2 --name tk9-l2-dense-everything
g l2 tk9-l2-zero-everything 1.2 2 5400 -- python3 $M --bundle $A/$B-zero-l2 --other $A/$B-dense-l2 --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/l2 --name tk9-l2-zero-everything
# ---- the v15 unit suite in the working copy (measured: 0.41 GiB, 25 s)
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v15.sha256 $GT >> $P/gate_queue.toolcheck 2>&1 || { echo "WORKING COPY MOVED" > $P/gate_queue.finished; exit 4; }
g suite unittests-v15 0.8 1.5 1200 -- python3 -m unittest discover -s $GT/tests
date -u > $P/gate_queue.finished
