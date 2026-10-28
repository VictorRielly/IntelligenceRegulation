#!/bin/bash
# PRIVACY GATE lane, gate round 10: the Python side, tools v12 (frozen_v12).
#   the v12 unit suite (working copy);
#   PR4-7  NL-1 S1-S5 on the new slots, all ten token captures;
#   PR4-7  the terminal surjection on the token stages' commitments, all ten
#          captures, plus the b4 block stage of the TinyLlama L = 1 captures
#          (the review's two-member controls run on its A);
#   PR4-9  the calibration attribution (after the Rust queue printed it);
#   PR4-2  the gate on the P-18 capture of the tk7 CLI run directory, as
#          round 6 gated R7's (cli_queue.sh): prediction, pass A, everything,
#          schema, G-10, TL controls.
# Queue rules: declarations from measured peaks plus a margin; a hold-file
# check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round10
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v12/scripts
V3=$GT/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
C=$A/token-io/captures
HOLDF=$E/HOLD
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v12.sha256 $GT/frozen_v12 > $P/r10_light.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r10_light.finished; exit 4; }
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v12.sha256 $GT >> $P/r10_light.toolcheck 2>&1 || { echo "WORKING COPY MOVED" > $P/r10_light.finished; exit 4; }
mkdir -p $P/nl $P/ts $P/cal $P/cli $P/suite
cd /tmp
g() {  # g <dir> <label> <need> <cap> <max> -- cmd...
  local d=$1 l=$2 n=$3 c=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/r10_light.progress
  return $rc
}
# measured: the v11 suite 0.41 GiB / 24 s; v12 adds the L1 NL-1 run (0.11 GiB)
g suite unittests-v12 0.8 1.5 1800 -- python3 -m unittest discover -s $GT/tests
CAPS="tinyllama-t32-L1-dense-pt1 tinyllama-t32-L1-fixed-pt1 tinyllama-t32-L2-dense-pt1 tinyllama-t32-L2-fixed-pt1 tinyllama-t32-L22-dense-pt1 tinyllama-t32-L22-fixed-pt1 llama3-8b-t32-L1-dense-pt1 llama3-8b-t32-L1-fixed-pt1 llama3-8b-t32-L2-dense-pt1 llama3-8b-t32-L2-fixed-pt1"
# measured (L1 probe): NL-1 0.11 GiB / 10 s; surjection 0.11 GiB / 103 s (IN + OUT)
for c in $CAPS; do
  g nl nl-$c 0.5 1.5 1800 -- python3 $S/zk60_native_rg_tokennl.py --bundle $C/$c --evidence $P/nl --name nl-$c
done
for c in $CAPS; do
  g ts ts-$c 0.6 2 3600 -- python3 $S/zk60_native_rg_tokents.py --bundle $C/$c --evidence $P/ts --name ts-$c
done
# the b4 block stage (R7 block stage file: 0.54 GiB, about 430 s each)
for c in tinyllama-t32-L1-dense-pt1 tinyllama-t32-L1-fixed-pt1; do
  g ts ts-block-$c 1 2 5400 -- python3 $S/zk60_native_rg_tokents.py --bundle $C/$c --evidence $P/ts --name ts-block-$c --block-stages 1
done
# PR4-9: wait for both attribution runs of the Rust queue
until [ -f $P/r10-pr4-9-tinyllama.done ] && [ -f $P/r10-pr4-9-8b.done ]; do
  [ -f $P/r10_heavy.finished ] && break
  sleep 60
done
g cal cal-all 0.8 1.5 1800 -- python3 $S/zk60_native_rg_tokencal.py --attribution $P/r10-pr4-9-tinyllama.log --attribution $P/r10-pr4-9-8b.log $(for c in $CAPS; do echo --bundle $C/$c; done) --evidence $P/cal --name cal-all
# PR4-2: the gate on the tk7 CLI capture (round 6's cli_queue.sh on R7, re-pointed)
CLI=tinyllama-cli-tk7-capture-dense-l2
Z=tinyllama-trained-tk7-capture-zero-l2
until [ -f $A/$CLI/manifest.json ]; do
  [ -f $P/r10_heavy.finished ] && break
  sleep 60
done
if [ -f $A/$CLI/manifest.json ]; then
  K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
  X=$K/run-i-dense-k4
  OLD=$K/run-a-tame
  XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
  ST=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r2/stack-pg_rot1-ho00-gpu/run/statement/statement.json
  EXP="--export $XP --statement $ST"
  PA="load,replay,hash,terminals,commitments,boundary,preimage,export,channels"
  ALL="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,export,channels"
  M=$S/zk60_native_rg_m125.py
  sha256sum $A/$CLI/manifest.json > $P/cli/cli-bundle-manifest.sha256
  g cli tk7-cli-l2-dense-a 0.6 1.5 1800 -- python3 $M --bundle $A/$CLI --other $A/$Z --stages $PA $EXP --evidence $P/cli --name tk7-cli-l2-dense-a
  g cli predict-cli-validated 0.6 1.5 600 -- python3 $S/zk60_native_rg_predict.py --bundle $A/$CLI --validate $A/$CLI:$P/cli/tk7-cli-l2-dense-a.json --evidence $P/cli --name prediction_tk7_cli_l2_dense_validated
  g cli tk7-cli-l2-dense-everything 1.2 2 5400 -- python3 $M --bundle $A/$CLI --other $A/$Z --stages $ALL --controls --old $OLD --legacy $OLD --cross-profile $X $EXP --evidence $P/cli --name tk7-cli-l2-dense-everything
  g cli tk7-cli-schema 1 1.5 900 -- python3 $S/zk60_native_rg_schema.py --bundle $A/$CLI --controls --evidence $P/cli --name tk7-cli-schema
  g cli tk7-cli-g10 0.6 1.5 900 -- python3 $S/zk60_native_rg_g10controls.py --bundle $A/$CLI --other $A/$Z --legacy $V3 --evidence $P/cli --name tk7-cli-g10
  g cli tk7-cli-tl-controls 0.6 1.5 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/$CLI --evidence $P/cli --name tk7-cli-tl-controls
fi
date -u > $P/r10_light.finished
