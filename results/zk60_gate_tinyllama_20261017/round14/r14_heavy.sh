#!/bin/bash
# PRIVACY GATE lane, gate round 14 (DD): build the gate's R9 copy (frozen R9
# af90c703 + the test-only H-1..H-5 patch) and a FAILING-FIRST copy (frozen R9
# + only the new tests); show the unpatched capture path refusing a DD run;
# run the patched copy's plane-index check and the existing capture suite;
# then capture the DD rung (L = 1, 2; dense, zero) and TinyLlama T128 DD
# (layers 0 / 0-1; ho00 dense, zero).
# Queue rules: declarations from measured peaks plus a margin (test builds
# 2.0 GiB; trained captures 1-3.5 GiB; T128 DD 22-layer CLI prove 7.3 GiB, so
# L <= 2 is declared at 4 GiB); a hold-file check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round14
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r9
F=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r9-ff
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts/dd-gate-r9
HOLDF=$E/HOLD
cd /tmp
python3 - <<'PY' || { echo "PRODUCTION FILES MOVED" > $P/r14_heavy.finished; exit 4; }
import hashlib, json, os, sys
m = json.load(open("/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r9/manifest_frozen.json"))["files"]
test_only = {"hashline/src/private_block/run_capture.rs", "hashline/src/private_block/plane_index.rs", "hashline/src/private_block/run_capture_tests.rs"}
bad = []
for root in ("/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r9", "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r9-ff"):
    for f, h in m.items():
        if f in test_only:
            continue
        if hashlib.sha256(open(os.path.join(root, f), "rb").read()).hexdigest() != h:
            bad.append((root, f))
print("production files moved:", bad)
sys.exit(1 if bad else 0)
PY
g() {  # g <class> <label> <need> <cap> <max> -- cmd...
  local c=$1 l=$2 n=$3 k=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class $c --need-gib $n --cap-gib $k --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/r14_heavy.progress
  return $rc
}
binof() { local b; b=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $1 | tail -1 | sed 's/.*(\(.*\))/\1/'); case "$b" in /*) ;; *) b=$2/hashline/$b ;; esac; echo $b; }
g build r14-build-gate 2.6 5 3600 -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml || { date -u > $P/r14_heavy.finished; exit 5; }
g build r14-build-ff 2.6 5 3600 -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $F/hashline/Cargo.toml || { date -u > $P/r14_heavy.finished; exit 5; }
BIN=$(binof $P/r14-build-gate.log $T); FBIN=$(binof $P/r14-build-ff.log $F)
sha256sum $BIN $FBIN > $P/r14-test-binaries.sha256
RC="private_block::run_capture_tests"
# FAILING FIRST: the unpatched capture path (frozen R9's run_capture.rs and plane_index.rs)
g cpu r14-ff-planeindex 0.5 1.5 900 -- $FBIN $RC::the_plane_index_builds_at_the_dd_layouts --exact --nocapture --test-threads 1
mkdir -p $A
g cpu r14-ff-capture-rung-l1 1 2 900 -- env HL_PB_CAPTURE_DIR=$A/ff-probe-rung-l1-dense HL_PB_INPUT=dense HL_PB_CAPTURE_BLOCKS=1 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=frozen-r9-unpatched-ff $FBIN $RC::capture_a_dd_rung_run --exact --ignored --nocapture --test-threads 1
# the patched copy: H-3's check, then the existing capture suite (non-DD bundles unchanged in kind)
g cpu r14-planeindex 0.5 1.5 900 -- $BIN $RC::the_plane_index_builds_at_the_dd_layouts --exact --nocapture --test-threads 1 || { date -u > $P/r14_heavy.finished; exit 6; }
g cpu r14-capture-suite 2 3.5 3600 -- $BIN $RC:: --test-threads 1
LBL="HL_TEST_SOURCE_COMMIT=trained-1b-gate-r9-sources-v1"
cap() {  # cap <name> <test> <need> <cap> <env...>
  local nm=$1 t=$2 n=$3 k=$4; shift 4
  [ -e $A/$nm ] && { echo "$(date -u +%H:%M:%S) $nm exists" >> $P/r14_heavy.progress; return 1; }
  g cpu cap-$nm $n $k 3600 -- env HL_PB_CAPTURE_DIR=$A/$nm HL_RUN_CAPTURE_PUBLIC_TABLES=1 $LBL "$@" $BIN $RC::$t --exact --ignored --nocapture --test-threads 1
}
cap dd-rung-l1-dense capture_a_dd_rung_run 1 2 HL_PB_INPUT=dense HL_PB_CAPTURE_BLOCKS=1
cap dd-rung-l1-zero capture_a_dd_rung_run 1 2 HL_PB_INPUT=zero HL_PB_CAPTURE_BLOCKS=1
cap dd-rung-l2-dense capture_a_dd_rung_run 1 2 HL_PB_INPUT=dense HL_PB_CAPTURE_BLOCKS=2
cap dd-rung-l2-zero capture_a_dd_rung_run 1 2 HL_PB_INPUT=zero HL_PB_CAPTURE_BLOCKS=2
cap tl128dd-l1-dense capture_a_tinyllama_t128_dd_run 4 6 HL_PB_INPUT=dense HL_PB_CAPTURE_BLOCKS=1 HL_PB_FIRST_LAYER=0 HL_PB_SEQ=ho00
cap tl128dd-l1-zero capture_a_tinyllama_t128_dd_run 4 6 HL_PB_INPUT=zero HL_PB_CAPTURE_BLOCKS=1 HL_PB_FIRST_LAYER=0
cap tl128dd-l2-dense capture_a_tinyllama_t128_dd_run 4 6 HL_PB_INPUT=dense HL_PB_CAPTURE_BLOCKS=2 HL_PB_FIRST_LAYER=0 HL_PB_SEQ=ho00
cap tl128dd-l2-zero capture_a_tinyllama_t128_dd_run 4 6 HL_PB_INPUT=zero HL_PB_CAPTURE_BLOCKS=2 HL_PB_FIRST_LAYER=0
date -u > $P/r14_heavy.finished
