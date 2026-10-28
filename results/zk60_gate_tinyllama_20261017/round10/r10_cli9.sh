#!/bin/bash
# PRIVACY GATE lane, gate round 10, PR4-10: the token lane's CLI-path token
# capture (`tinyllama-t32-L2-dense-pt1-cli-r9`, the named round-9 binary
# b56f1b71...) gated with the CURRENT tools (v12).  The capture pins six
# files that differ from frozen-r7 (round 9), which v12 has no reading of:
# the token pin check must refuse them by name, and every check that relies
# on a pinned transcription refuses before evaluating.  The checks that do
# not depend on a pin (the surjection; NL-1's IR stages) still run.
# Queue rules: measured-peak declarations; hold-file check before each job.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round10
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v12/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
B=/home/victor/zk60-artifacts/token-io/captures/tinyllama-t32-L2-dense-pt1-cli-r9
HOLDF=$E/HOLD
python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v12.sha256 $GT/frozen_v12 > $P/r10_cli9.toolcheck 2>&1 || { echo "TOOLS MOVED" > $P/r10_cli9.finished; exit 4; }
mkdir -p $P/cli9
sha256sum $B/manifest.json > $P/cli9/cli9-bundle-manifest.sha256
cd /tmp
g() {
  local l=$1 n=$2 c=$3 m=$4 rc; shift 5
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/cli9/$l.log --done $P/cli9/$l.done --result-json $P/cli9/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) cli9/$l exit $rc" >> $P/r10_cli9.progress
}
# measured: the v10 token gate at L2 0.6 GiB / 860 s; NL-1 0.14 GiB; surjection 0.11 GiB / 520 s
g v12-tokengate-cli9 1 2 3600 -- python3 $S/zk60_native_rg_tokengate.py --bundle $B --evidence $P/cli9 --name v12-tokengate-cli9
g v12-nl-cli9 0.5 1.5 900 -- python3 $S/zk60_native_rg_tokennl.py --bundle $B --evidence $P/cli9 --name v12-nl-cli9
g v12-ts-cli9 0.6 2 3600 -- python3 $S/zk60_native_rg_tokents.py --bundle $B --evidence $P/cli9 --name v12-ts-cli9
date -u > $P/r10_cli9.finished
