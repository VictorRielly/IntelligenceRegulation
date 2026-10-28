#!/bin/bash
# PRIVACY GATE lane, gate round 10, PR4-10: the CLI-path token capture gated
# with tools v14 (= v13 + the token gate's export override, so the
# block-stage terminals read the b4 export the capture's README names only
# as the source of its prover-side VIEW).  Then the v14 unit suite.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round10
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v14/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
B=/home/victor/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128
HOLDF=$E/HOLD
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v14.sha256 $GT/frozen_v14 > $P/r10_cli9_v14.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r10_cli9_v14.finished; exit 4; }
cd /tmp
g() {
  local l=$1 n=$2 c=$3 m=$4 rc; shift 5
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/cli9/$l.log --done $P/cli9/$l.done --result-json $P/cli9/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) cli9/$l exit $rc" >> $P/r10_cli9_v14.progress
}
# measured: the v13 run on this capture 0.6 GiB / 694 s
g v14-tokengate-cli9 1 2 3600 -- python3 $S/zk60_native_rg_tokengate.py --bundle $B --export $XP --evidence $P/cli9 --name v14-tokengate-cli9
g unittests-v14 0.8 1.5 1800 -- python3 -m unittest discover -s $GT/tests
date -u > $P/r10_cli9_v14.finished
