#!/bin/bash
# TINYLLAMA PORT, round 3 of records: the 22-block bound run (all of
# pg_rot1, dense, ho00).  Starts only after the L = 1 queue has finished
# (one guarded job of this lane at a time).  Tools v2 frozen; the release
# test binary pinned by digest.  Capture (cpu), prediction (light), pass A
# (cpu: the whole-run joint system is projected at ~6.5 GB), pass M (mask /
# CFS per stage with its controls, light).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/l22
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
BIN=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate/hashline/target/release/deps/hashline-771b814586910244
until [ -f $E/l1/queue.finished ]; do sleep 20; done
cd /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama || exit 3
sha256sum -c --quiet $E/gate-tinyllama.tools.frozen.v2.sha256 || { echo "TOOLS MOVED" > $P/queue.finished; exit 4; }
[ "$(sha256sum $BIN | awk '{print $1}')" = "$(cat $E/l1/hashline-lib-test-release.v2.sha256)" ] || { echo "BINARY MOVED" > $P/queue.finished; exit 5; }
cd /tmp
g() {  # g <class> <label> <need> <cap> <max-secs> -- cmd...
  local c=$1 l=$2 n=$3 k=$4 m=$5; shift 6
  python3 $G run --class $c --need-gib $n --cap-gib $k --label tl-$l --wait-secs 10800 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  echo "$l exit $?" >> $P/queue.progress
}
g cpu capture-l22-dense 4.5 6 3600 -- env HL_PB_CAPTURE_BLOCKS=22 HL_PB_FIRST_LAYER=0 HL_PB_SEQ=ho00 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=trained-1b-gate-sources-v2-9b0265cd HL_PB_INPUT=dense HL_PB_CAPTURE_DIR=$A/tinyllama-trained-capture-dense-l22 $BIN private_block::run_capture_tests::capture_a_tinyllama_trained_run --exact --ignored --nocapture --test-threads 1
[ -f $A/tinyllama-trained-capture-dense-l22/manifest.json ] || { date -u > $P/queue.finished; exit 6; }
g light predict-l22 1 1.5 900 -- python3 $S/zk60_native_rg_predict.py --bundle $A/tinyllama-trained-capture-dense-l22 --evidence $P --name prediction_tinyllama_l22_dense
g cpu tl-l22-dense-a 7.5 9 5400 -- /usr/bin/time -v python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-dense-l22 --stages load,replay,hash,terminals,commitments,boundary,preimage,channels --evidence $P --name tl-l22-dense-a
g light tl-l22-dense-m 1.5 3 3600 -- python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-dense-l22 --stages load,replay,mask --controls --evidence $P --name tl-l22-dense-m
date -u > $P/queue.finished
