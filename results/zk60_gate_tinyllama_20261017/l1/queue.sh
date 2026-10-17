#!/bin/bash
# TINYLLAMA PORT, round 2 of records: the ONE-BLOCK bound run (the standalone
# block at a trained profile), dense and zero, at layer 0 of pg_rot1; then
# the everything pass on the L = 2 ZERO bundle (every control family on the
# degenerate partner too).  One guarded job at a time.  Tools: v2 frozen
# (`gate-tinyllama.tools.frozen.v2.sha256`); the computed half of the L = 1
# prediction is ALSO run with the v1 tools (`frozen_v1/`), to show the
# predictor's old one-block fallback wrong exactly as predicted.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/l1
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
S1=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v1/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
X=/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-i-dense-k4
BIN=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate/hashline/target/release/deps/hashline-771b814586910244
cd /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama || exit 3
sha256sum -c --quiet $E/gate-tinyllama.tools.frozen.v2.sha256 || { echo "TOOLS MOVED" > $P/queue.finished; exit 4; }
[ "$(sha256sum $BIN | awk '{print $1}')" = "$(cat $P/hashline-lib-test-release.v2.sha256)" ] || { echo "BINARY MOVED" > $P/queue.finished; exit 5; }
cd /tmp
g() {  # g <class> <label> <need> <cap> <max-secs> -- cmd...
  local c=$1 l=$2 n=$3 k=$4 m=$5; shift 6
  python3 $G run --class $c --need-gib $n --cap-gib $k --label tl-$l --wait-secs 7200 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  echo "$l exit $?" >> $P/queue.progress
}
CAP="HL_PB_CAPTURE_BLOCKS=1 HL_PB_FIRST_LAYER=0 HL_PB_SEQ=ho00 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=trained-1b-gate-sources-v2-9b0265cd"
g cpu capture-l1-dense 2 3.5 1800 -- env $CAP HL_PB_INPUT=dense HL_PB_CAPTURE_DIR=$A/tinyllama-trained-capture-dense-l1 $BIN private_block::run_capture_tests::capture_a_tinyllama_trained_run --exact --ignored --nocapture --test-threads 1
g cpu capture-l1-zero 2 3.5 1800 -- env $CAP HL_PB_INPUT=zero HL_PB_CAPTURE_DIR=$A/tinyllama-trained-capture-zero-l1 $BIN private_block::run_capture_tests::capture_a_tinyllama_trained_run --exact --ignored --nocapture --test-threads 1
g light predict-v1 1 1.5 600 -- python3 $S1/zk60_native_rg_predict.py --bundle $A/tinyllama-trained-capture-dense-l1 --evidence $P --name prediction_tinyllama_l1_dense_tools_v1
g light predict-v2-dense 1 1.5 600 -- python3 $S/zk60_native_rg_predict.py --bundle $A/tinyllama-trained-capture-dense-l1 --evidence $P --name prediction_tinyllama_l1_dense
g light predict-v2-zero 1 1.5 600 -- python3 $S/zk60_native_rg_predict.py --bundle $A/tinyllama-trained-capture-zero-l1 --evidence $P --name prediction_tinyllama_l1_zero
PA="load,replay,hash,terminals,commitments,boundary,preimage,channels"
ALL="load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,runcontrols,channels"
g light tl-l1-dense-a 1 2 1800 -- python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-dense-l1 --other $A/tinyllama-trained-capture-zero-l1 --stages $PA --evidence $P --name tl-l1-dense-a
g light tl-l1-zero-a 1 2 1800 -- python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-zero-l1 --other $A/tinyllama-trained-capture-dense-l1 --stages $PA --evidence $P --name tl-l1-zero-a
g light tl-controls-l1-dense 1 2 1800 -- python3 $S/zk60_native_rg_tlcontrols.py --bundle $A/tinyllama-trained-capture-dense-l1 --evidence $P --name tl-controls-l1-dense
g light tl-l1-dense-everything 1.5 3 5400 -- python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-dense-l1 --other $A/tinyllama-trained-capture-zero-l1 --stages $ALL --controls --cross-profile $X --evidence $P --name tl-l1-dense-everything
g light tl-l2-zero-everything 1.5 3 5400 -- python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-zero-l2 --other $A/tinyllama-trained-capture-dense-l2 --stages $ALL --controls --cross-profile $X --evidence $E/l2 --name tl-zero-everything
date -u > $P/queue.finished
