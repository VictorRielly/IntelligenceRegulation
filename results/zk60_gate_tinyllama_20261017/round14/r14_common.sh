# sourced by the round-14 official gate queues (frozen tools v17)
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round14
GT=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama
S=$GT/frozen_v17/scripts
V16=$GT/frozen_v16/scripts
V3=$GT/frozen_v3/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts/dd-gate-r9
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
X=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/tinyllama_dg_rot1_T128
HOLDF=$E/HOLD
M=$S/zk60_native_rg_m125.py
PA_RUNG="load,replay,hash,terminals,commitments,boundary,preimage,channels"
PA_T128="load,replay,hash,terminals,commitments,boundary,preimage,export,channels"
ALL_RUNG="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,channels"
ALL_T128="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,export,channels"
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
