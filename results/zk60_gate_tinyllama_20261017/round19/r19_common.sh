# sourced by the round-19 gate queues (frozen tools v22)
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round19
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v22/scripts
S21=$GT/frozen_v21/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
HOLDF=$E/HOLD
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
EX=/home/victor/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
R13FX=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures/r13-h24-dense
hold() { while [ -e $HOLDF ] || [ -e $W ]; do sleep 60; done; }
g() {  # g <queue> <dir> <label> <class> <need> <cap> <max> -- cmd...
  local q=$1 d=$2 l=$3 cl=$4 n=$5 c=$6 m=$7 rc; shift 8
  mkdir -p $P/$d
  hold
  python3 $G run --class $cl --need-gib $n --cap-gib $c --label gate19-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/$q.progress
  return $rc
}
