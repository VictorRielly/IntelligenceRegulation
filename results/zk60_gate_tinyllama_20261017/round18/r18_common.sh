# sourced by the round-18 gate queues (frozen tools v21)
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round18
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v21/scripts
S20=$GT/frozen_v20/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io/captures
HOLDF=$E/HOLD
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
g() {  # g <queue> <dir> <label> <need> <cap> <max> -- cmd...
  local q=$1 d=$2 l=$3 n=$4 c=$5 m=$6 rc; shift 7
  mkdir -p $P/$d
  while [ -e $HOLDF ] || [ -e $W ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate18-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/$q.progress
  return $rc
}
