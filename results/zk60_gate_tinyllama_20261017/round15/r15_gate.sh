#!/bin/bash
# PRIVACY GATE lane, gate round 15: the frozen-r11 re-pin on the CLI-path
# capture through the named round-11 binary (0c9f247c...).
#   FAILING FIRST: frozen v17 (no round-11 reading) must refuse token_io.rs
#   7730c8d0 and cli.rs 3eaaacdb by name.
#   Then frozen v18 (= v17 + the round-11 readings, walked back to the
#   port's digests): the token gate with the b4 export override (as v14 on
#   the r9 CLI capture), NL-1, the surjection, and the v18 unit suite.
# Declarations from measured peaks plus a margin (v14 on the r9 CLI capture
# 0.6 GiB / 653 s; NL-1 < 0.5; surjection < 1); a hold-file check before each
# job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round15
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v18/scripts
V17=$GT/frozen_v17/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
B=/home/victor/zk60-artifacts/token-io-r11-gate/captures/tinyllama-t32-L2-dense-pt1-cli-r11
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128
HOLDF=$E/HOLD
cd /tmp
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v18.sha256 $GT/frozen_v18 > $P/r15_gate.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r15_gate.finished; exit 4; }
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v17.sha256 $GT/frozen_v17 >> $P/r15_gate.toolcheck 2>&1 || { echo "V17 MOVED" > $P/r15_gate.finished; exit 4; }
[ -f $B/manifest.json ] || { echo "NO CAPTURE" > $P/r15_gate.finished; exit 5; }
mkdir -p $P/gate
g() {  # g <label> <need> <cap> <max> -- cmd...
  local l=$1 n=$2 c=$3 m=$4 rc; shift 5
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/gate/$l.log --done $P/gate/$l.done --result-json $P/gate/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) gate/$l exit $rc" >> $P/r15_gate.progress
}
g ff-v17-tokengate-cli11 1 2 3600 -- python3 $V17/zk60_native_rg_tokengate.py --bundle $B --export $XP --evidence $P/gate --name ff-v17-tokengate-cli11
g v18-tokengate-cli11 1 2 3600 -- python3 $S/zk60_native_rg_tokengate.py --bundle $B --export $XP --evidence $P/gate --name v18-tokengate-cli11
g v18-nl-cli11 0.6 1.5 1800 -- python3 $S/zk60_native_rg_tokennl.py --bundle $B --evidence $P/gate --name v18-nl-cli11
g v18-ts-cli11 1 2 5400 -- python3 $S/zk60_native_rg_tokents.py --bundle $B --evidence $P/gate --name v18-ts-cli11
# the v18 suite in the frozen snapshot itself (its `original` is a link to
# the gate's originals): the working copy stays at v17 until round 14's
# queue A has run the v17 suite there
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v18.sha256 $GT/frozen_v18 >> $P/r15_gate.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r15_gate.finished; exit 4; }
g unittests-v18 0.8 1.5 1200 -- python3 -m unittest discover -s $GT/frozen_v18/tests
date -u > $P/r15_gate.finished
