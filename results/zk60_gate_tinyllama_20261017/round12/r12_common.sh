# sourced by the round-12 gate queues
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round12
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v16/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io-r9-gate/captures
HOLDF=$E/HOLD
g() {  # g <queue> <dir> <label> <need> <cap> <max> -- cmd...
  local q=$1 d=$2 l=$3 n=$4 c=$5 m=$6 rc; shift 7
  mkdir -p $P/$d
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class light --need-gib $n --cap-gib $c --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$d/$l.log --done $P/$d/$l.done --result-json $P/$d/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $d/$l exit $rc" >> $P/$q.progress
  return $rc
}
wb() {  # wait for a capture's manifest; give up if the capture queue ended without it
  until [ -f $C/$1/manifest.json ]; do
    if [ -f $P/r12_heavy.done ] && [ ! -f $C/$1/manifest.json ]; then return 1; fi
    sleep 30
  done
  sleep 5
}
