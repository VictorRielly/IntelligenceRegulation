#!/bin/bash
# PRIVACY GATE lane, gate round 10, PR4-10: the CLI-path token capture gated
# with tools v13 (= v12 + the readings of the six round-9 files the capture
# pins, pre-freeze).  The full token gate (every G-item, the computed joint,
# the full preimage and joint assignment, the new-slot and block-stage
# terminals, every control family), NL-1 S1-S5, then the v13 unit suite.
# Queue rules: measured-peak declarations; hold-file check before each job.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round10
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v13/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
B=/home/victor/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9
HOLDF=$E/HOLD
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v13.sha256 $GT/frozen_v13 > $P/r10_cli9_v13.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r10_cli9_v13.finished; exit 4; }
mkdir -p $P/cli9
cd /tmp
g() {
  local l=$1 n=$2 c=$3 m=$4 rc; shift 5
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/cli9/$l.log --done $P/cli9/$l.done --result-json $P/cli9/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) cli9/$l exit $rc" >> $P/r10_cli9_v13.progress
}
g v13-tokengate-cli9 1 2 3600 -- python3 $S/zk60_native_rg_tokengate.py --bundle $B --evidence $P/cli9 --name v13-tokengate-cli9
g v13-nl-cli9 0.5 1.5 900 -- python3 $S/zk60_native_rg_tokennl.py --bundle $B --evidence $P/cli9 --name v13-nl-cli9
mkdir -p $P/suite
g unittests-v13 0.8 1.5 1800 -- python3 -m unittest discover -s $GT/tests
date -u > $P/r10_cli9_v13.finished
