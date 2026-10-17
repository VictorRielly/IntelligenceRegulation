#!/bin/bash
# P2-2 heavy runs, launched only when no r4-* guard is running or queued
# (the coordinator's priority rule, checked before EVERY heavy step), and
# after the lane's light queue has finished (one guarded job at a time).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/l22
S=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
BIN=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate/hashline/target/release/deps/hashline-771b814586910244
until [ -f $E/p2/light_queue.finished ]; do sleep 20; done
no_r4() { ! ps -eo args | grep "zk60_resource_guard.py run" | grep -q -- "--label r4-"; }
wait_r4() { until no_r4; do sleep 60; done; sleep 30; until no_r4; do sleep 60; done; echo "$(date -u +%H:%M:%S) r4 clear before $1" >> $P/heavy_queue.progress; }
cd /home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama || exit 3
sha256sum -c --quiet $E/gate-tinyllama.tools.frozen.v3.sha256 || { echo "TOOLS MOVED" > $P/heavy_queue.finished; exit 4; }
[ "$(sha256sum $BIN | awk '{print $1}')" = "$(cat $E/l1/hashline-lib-test-release.v2.sha256)" ] || { echo "BINARY MOVED" > $P/heavy_queue.finished; exit 5; }
cd /tmp
g() { local c=$1 l=$2 n=$3 k=$4 m=$5; shift 6
  python3 $G run --class $c --need-gib $n --cap-gib $k --label tl-$l --wait-secs 14400 --max-secs $m --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  echo "$l exit $?" >> $P/heavy_queue.progress; }
wait_r4 capture-l22-zero
g cpu capture-l22-zero 3 4.5 3600 -- env HL_PB_CAPTURE_BLOCKS=22 HL_PB_FIRST_LAYER=0 HL_PB_SEQ=ho00 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=trained-1b-gate-sources-v2-9b0265cd HL_PB_INPUT=zero HL_PB_CAPTURE_DIR=$A/tinyllama-trained-capture-zero-l22 $BIN private_block::run_capture_tests::capture_a_tinyllama_trained_run --exact --ignored --nocapture --test-threads 1
[ -f $A/tinyllama-trained-capture-zero-l22/manifest.json ] || { date -u > $P/heavy_queue.finished; exit 6; }
g light predict-l22-zero 1 1.5 900 -- python3 $S/zk60_native_rg_predict.py --bundle $A/tinyllama-trained-capture-zero-l22 --evidence $P --name prediction_tinyllama_l22_zero
wait_r4 tl-l22-zero-arms
g cpu tl-l22-zero-arms 7 9 10800 -- /usr/bin/time -v python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-zero-l22 --other $A/tinyllama-trained-capture-dense-l22 --stages load,replay,hash,terminals,commitments,boundary,preimage,fullpreimage,mask,joint,channels --evidence $P --name tl-l22-zero-arms
wait_r4 tl-l22-dense-arms
g cpu tl-l22-dense-arms 7 9 10800 -- /usr/bin/time -v python3 $S/zk60_native_rg_m125.py --bundle $A/tinyllama-trained-capture-dense-l22 --other $A/tinyllama-trained-capture-zero-l22 --stages load,replay,commitments,boundary,preimage,fullpreimage,mask,joint,channels --evidence $P --name tl-l22-dense-arms
date -u > $P/heavy_queue.finished
