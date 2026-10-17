#!/bin/bash
# TINYLLAMA PORT, the records of record on the two trained two-block bundles,
# with the tool bytes FROZEN (gate-tinyllama.tools.frozen.sha256, checked
# first).  Each step is ONE guarded light job; the steps run one after the
# other, so this lane never has two guarded jobs live.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/l2
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
K=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920
cd /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama || exit 3
sha256sum -c --quiet $E/gate-tinyllama.tools.frozen.sha256 || { echo "TOOLS MOVED" > $P/queue.finished; exit 4; }
cd /tmp
g() {  # g <label> <need> <cap> <max-secs> -- cmd...
  local l=$1 n=$2 c=$3 m=$4; shift 5
  python3 $G run --class light --need-gib $n --cap-gib $c --label tl-$l --wait-secs 7200 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  echo "$l exit $?" >> $P/queue.progress
}
g equivalence-k4 1.5 3 3600 -- python3 $E/equivalence.py $K/run-i-dense-k4 $K/run-j-zero-k4 $E/equivalence equivalence-k4
g tl-dense-a 1 2 1800 -- bash $P/gate.sh a dense
g tl-zero-a 1 2 1800 -- bash $P/gate.sh a zero
g tl-controls-dense 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/tinyllama-trained-capture-dense-l2 --evidence $P --name tl-controls-dense
g tl-controls-zero 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/tinyllama-trained-capture-zero-l2 --evidence $P --name tl-controls-zero
g witcmp 1 1.5 600 -- python3 $S/zk60_native_rg_witcmp.py --record $P/tl-dense-a.json --label "layers 7..9 ho00 (dense, the export's real hidden input)" --witness dense --record $P/tl-zero-a.json --label "layers 7..9 all-zero" --witness zero --out $P/witness_comparison_tl_dense_vs_zero.json
g tl-dense-everything 1.5 3 5400 -- bash $P/gate.sh b
g tl-zero-arms 1.5 3 5400 -- bash $P/gate.sh c
date -u > $P/queue.finished
