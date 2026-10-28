#!/bin/bash
# PRIVACY GATE lane, gate round 10: PR4-9's calibration attribution re-run
# with tools v16 (the attribution reader takes the object after libtest's
# `test <name> ... ` prefix; v12 missed the L = 1 line and refused the four
# L = 1 bundles by A1), then the v16 suite.  Measured: cal-all 0.1 GiB / 25 s,
# the suite 0.41 GiB / 27 s.  Hold-file check before each job.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round10
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v16/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
HOLDF=$E/HOLD
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v16.sha256 $GT/frozen_v16 > $P/r10_cal_v16.toolcheck 2>&1 || exit 4
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v16.sha256 $GT >> $P/r10_cal_v16.toolcheck 2>&1 || exit 4
cd /tmp
g() {
  local d=$1 l=$2 n=$3 c=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/r10_cal_v16.progress
  return $rc
}
CAPS="tinyllama-t32-L1-dense-pt1 tinyllama-t32-L1-fixed-pt1 tinyllama-t32-L2-dense-pt1 tinyllama-t32-L2-fixed-pt1 tinyllama-t32-L22-dense-pt1 tinyllama-t32-L22-fixed-pt1 llama3-8b-t32-L1-dense-pt1 llama3-8b-t32-L1-fixed-pt1 llama3-8b-t32-L2-dense-pt1 llama3-8b-t32-L2-fixed-pt1"
g cal v16-cal-all 0.5 1.5 1800 -- python3 $S/zk60_native_rg_tokencal.py --attribution $P/r10-pr4-9-tinyllama.log --attribution $P/r10-pr4-9-8b.log $(for c in $CAPS; do echo --bundle $C/$c; done) --evidence $P/cal --name v16-cal-all
g suite unittests-v16 0.8 1.5 1200 -- python3 -m unittest discover -s $GT/tests
