#!/bin/bash
# PRIVACY GATE lane, gate round 10, the frozen-r9 re-pin: queue B of two, the
# whole stack L = 22 on the tk9 bundles, tools v15: schema over the six
# bundles, G-10, pass A on both inputs, the two validated predictions.  Runs
# beside queue A; the guard's memory admission orders them.
# Queue rules: declarations from the tk7 measured peaks plus a margin; a
# hold-file check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/tk9
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v15/scripts
V3=$GT/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
HOLDF=$E/HOLD
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
ST=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r2/stack-pg_rot1-ho00-gpu/run/statement/statement.json
EXP="--export $XP --statement $ST"
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v15.sha256 $GT/frozen_v15 > $P/gate_queue_l22.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/gate_queue_l22.finished; exit 4; }
mkdir -p $P/l22
cd /tmp
g() {  # g <dir> <label> <need> <cap> <max> -- cmd...
  local d=$1 l=$2 n=$3 c=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/gate_queue_l22.progress
  return $rc
}
B=tinyllama-trained-tk9-capture
for b in dense-l1 zero-l1 dense-l2 zero-l2 dense-l22 zero-l22; do
  until [ -f $A/$B-$b/manifest.json ]; do
    if [ -f $P/heavy_queue.done ] && [ ! -f $A/$B-$b/manifest.json ]; then
      echo "$(date -u +%H:%M:%S) no bundle $B-$b; stopping" >> $P/gate_queue_l22.progress; date -u > $P/gate_queue_l22.finished; exit 6
    fi
    sleep 30
  done
done
sleep 5
PA="load,replay,hash,terminals,commitments,boundary,preimage,export,channels"
M=$S/zk60_native_rg_m125.py
# measured (tk7): schema 0.82, G-10 L22 1.32 (50 min), pass A L22 5.4-5.5 GiB (about 1 h each), validated prediction L22 1.09 GiB
g l22 tk9-schema 1.2 2 1800 -- python3 $S/zk60_native_rg_schema.py --bundle $A/$B-dense-l1 --bundle $A/$B-zero-l1 --bundle $A/$B-dense-l2 --bundle $A/$B-zero-l2 --bundle $A/$B-dense-l22 --bundle $A/$B-zero-l22 --controls --evidence $P --name tk9-schema-six-bundles
g l22 tk9-g10-l22 1.8 2.5 3600 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$B-dense-l22 --other $A/$B-zero-l22 --legacy $V3 --evidence $P/l22 --name tk9-g10-l22
g l22 tk9-l22-zero-a 6.2 7 5400 -- /usr/bin/time -v python3 $M --bundle $A/$B-zero-l22 --other $A/$B-dense-l22 --stages $PA $EXP --evidence $P/l22 --name tk9-l22-zero-a
g l22 tk9-l22-dense-a 6.2 7 5400 -- /usr/bin/time -v python3 $M --bundle $A/$B-dense-l22 --other $A/$B-zero-l22 --stages $PA $EXP --evidence $P/l22 --name tk9-l22-dense-a
for w in dense zero; do g l22 predict-validated-$w 1.6 2.5 1800 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-l22 --validate $A/$B-$w-l22:$P/l22/tk9-l22-$w-a.json --evidence $P/l22 --name prediction_tk9_l22_${w}_validated; done
date -u > $P/gate_queue_l22.finished
