#!/bin/bash
# PRIVACY GATE lane, round 8 (the D33 re-pin), after the tk7 gate queue:
# (1) the six tk7 predictions VALIDATED against the tk7 pass-A records (the
#     gate queue ran the predictor without --validate, so its records say
#     ok: false with an empty validated_on by construction, predict.py:690-692;
#     the coordinator asked for the explanation and a re-run);
# (2) the full unit suite in the working copy, now tools v11.
# Queue rules since 2026-10-19 20:21 UTC: one job at a time; declarations
# from measured peaks plus a margin; a hold-file check before each job
# (EV/HOLD, the lane's own, anyone may create it); and, until the token
# lane's r8_round.done exists, the coordinator's hold: need 0.8 / cap 1.5.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/tk7
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v11/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
HOLDF=$E/HOLD
R8=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/logs/r8_round.done
until [ -f $P/gate_queue.done ]; do sleep 30; done
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v11.sha256 $GT/frozen_v11 > $P/post_queue.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/post_queue.finished; exit 4; }
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v11.sha256 $GT >> $P/post_queue.toolcheck 2>&1 || { echo "WORKING COPY MOVED" > $P/post_queue.finished; exit 4; }
cd /tmp
g() {  # g <dir> <label> <need> <cap> <max> -- cmd...
  local d=$1 l=$2 n=$3 c=$4 m=$5 decl rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  if [ -f $R8 ]; then decl="--need-gib $n --cap-gib $c"; else decl="--need-gib 0.8 --cap-gib 1.5"; fi
  python3 $G run --class light $decl --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc ($decl)" >> $P/post_queue.progress
}
B=tinyllama-trained-tk7-capture
# measured: prediction alone 0.07 (L1/L2) / 0.57 GiB (L22, R7); validation loads the bundle a second time
for L in l1 l2 l22; do
  for w in dense zero; do
    g $L predict-validated-$w 1.2 2 1200 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$B-$w-$L \
      --validate $A/$B-$w-$L:$P/$L/tk7-$L-$w-a.json --evidence $P/$L --name prediction_tk7_${L}_${w}_validated
  done
done
# measured: the staged suite 0.41 GiB
mkdir -p $P/suite
g suite unittests-v11 0.8 1.5 1200 -- python3 -m unittest discover -s $GT/tests
date -u > $P/post_queue.finished
