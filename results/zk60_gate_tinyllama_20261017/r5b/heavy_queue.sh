#!/bin/bash
# PRIVACY GATE lane, round 5: build the gate's R5b copy (the native lane's
# frozen R5b tree 44013397... plus the test-only capture code and the P-12
# stage-47 tests, sources manifest trained-1b-gate-r5b.sources.v1.sha256),
# run the three stage-47 tests (class light, ~20 s), and capture L = 1, 2, 22
# bundles (dense and all-zero) from it.  Each step is ONE guarded job under
# the shared heavy lock (class build / cpu), queued behind whatever holds it;
# the lock is taken per step, so other lanes interleave.  Never two of this
# lane's guarded jobs at once.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/r5b
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r5b
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
cd /tmp
python3 - <<'PY' || { echo "SOURCES MOVED" > $P/heavy_queue.finished; exit 4; }
import hashlib, os, sys
root = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r5b"
bad = [p for d, p in (l.split(None, 1) for l in open("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/r5b/trained-1b-gate-r5b.sources.v1.sha256"))
       if hashlib.sha256(open(os.path.join(root, p.strip()), "rb").read()).hexdigest() != d]
sys.exit(1 if bad else 0)
PY
g() {  # g <class> <label> <need> <cap> <max-secs> -- cmd...
  local c=$1 l=$2 n=$3 k=$4 m=$5; shift 6
  python3 $G run --class $c --need-gib $n --cap-gib $k --label tl-$l --wait-secs 21600 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  local rc=$?
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/heavy_queue.progress
  return $rc
}
g build r5b-build 3 5 3600 -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml || { date -u > $P/heavy_queue.finished; exit 5; }
BIN=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $P/r5b-build.log | tail -1 | sed 's/.*(\(.*\))/\1/')
[ -x "$BIN" ] || { echo "NO BINARY" > $P/heavy_queue.finished; exit 6; }
sha256sum $BIN > $P/hashline-lib-test-release.r5b.sha256
mkdir -p $A/tinyllama-gate-bins
cp $BIN $A/tinyllama-gate-bins/hashline-lib-test-release-r5b
GR="private_block::run_capture_tests::gr4_trained_tests"
for t in gr4_trained_t32_block_dense_ho00_commits_exactly_the_predicted_stream gr4_trained_t32_block_zero_commits_exactly_the_predicted_stream gr4_trained_t32_boundary_commits_exactly_the_predicted_stream; do
  g light gr4-${t#gr4_trained_t32_} 2 3.5 900 -- $BIN $GR::$t --exact --ignored --nocapture --test-threads 1
done
CAP="HL_PB_SEQ=ho00 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=trained-1b-gate-r5b-sources-v1-444b948f"
TEST="private_block::run_capture_tests::capture_a_tinyllama_trained_run --exact --ignored --nocapture --test-threads 1"
cap() {  # cap <label> <need> <cap> <max> <blocks> <first> <input> <dir>
  local l=$1 n=$2 k=$3 m=$4 b=$5 f=$6 i=$7 d=$8
  g cpu $l $n $k $m -- env $CAP HL_PB_CAPTURE_BLOCKS=$b HL_PB_FIRST_LAYER=$f HL_PB_INPUT=$i HL_PB_CAPTURE_DIR=$A/$d $BIN $TEST
  [ -f $A/$d/manifest.json ] || { echo "$(date -u +%H:%M:%S) $l: no manifest" >> $P/heavy_queue.progress; date -u > $P/heavy_queue.finished; exit 7; }
}
cap capture-r5b-l2-dense 2 3.5 1800 2 7 dense tinyllama-trained-r5b-capture-dense-l2
cap capture-r5b-l2-zero 2 3.5 1800 2 7 zero tinyllama-trained-r5b-capture-zero-l2
cap capture-r5b-l1-dense 2 3.5 1800 1 0 dense tinyllama-trained-r5b-capture-dense-l1
cap capture-r5b-l1-zero 2 3.5 1800 1 0 zero tinyllama-trained-r5b-capture-zero-l1
cap capture-r5b-l22-dense 3 4.5 3600 22 0 dense tinyllama-trained-r5b-capture-dense-l22
cap capture-r5b-l22-zero 3 4.5 3600 22 0 zero tinyllama-trained-r5b-capture-zero-l22
date -u > $P/heavy_queue.finished
