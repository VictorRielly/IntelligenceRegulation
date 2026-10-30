# sourced by the round-20 gate queues (frozen tools v23)
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round20
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v23/scripts
S22=$GT/frozen_v22/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
HOLDF=$E/HOLD
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
R13FX=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures/r13-h24-dense
REAL=classify-r13-shield-t128-cli-hate-r17-values
RUNG17=classify-r13-rung-L2-v1-r17-values
# round 19's declared preimage sample (stage IN-C, blocks 0 / 12 / 25 with their boundaries, stage OUT-C with B_out)
SAMPLE="A-in@0,H-in@0,E-token-in,A@1,H@1,B0,A@13,H@13,B12,A@26,H@26,B25,A-out@27,H-out@27,B26"
hold() { while [ -e $HOLDF ] || [ -e $W ]; do sleep 60; done; }
# alone <own-prefix>: wait until no other guarded job is live or waiting (sol- / astra- included) and no hold file
alone() { while ! python3 $P/alone_check.py "$1" > $P/alone.last 2>&1; do sleep 60; done; }
toolcheck() {  # toolcheck <queue>
  python3 $E/v4/freeze.py check $E/gate-tinyllama.tools.frozen.v23.sha256 $GT/frozen_v23 > $P/$1.toolcheck 2>&1 \
    || { echo "TOOLS MOVED" > $P/$1.finished; exit 4; }
}
g() {  # g <queue> <dir> <label> <class> <need> <cap> <max> -- cmd...
  local q=$1 d=$2 l=$3 cl=$4 n=$5 c=$6 m=$7 rc; shift 8
  mkdir -p $P/$d
  hold
  python3 $G run --class $cl --need-gib $n --cap-gib $c --label gate20-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/$q.progress
  return $rc
}
