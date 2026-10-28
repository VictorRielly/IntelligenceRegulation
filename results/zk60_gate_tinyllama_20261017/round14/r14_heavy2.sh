#!/bin/bash
# PRIVACY GATE lane, gate round 14 (DD), second heavy queue: the test-only
# harness fix (DdChain builds each block's witness at its layer's own shape,
# as the stack CLI does, trained_block.rs NATIVE R8), recorded as patch v2
# (052a82cf...) and sources v2 (d9b80c92...). Rebuild the gate copy, re-run
# its plane-index check and the capture suite, then recapture TinyLlama T128
# DD L = 2 (layers 0-1; ho00 dense, zero).
# Queue rules: declarations from measured peaks plus a margin (test build
# 2.0 GiB measured; T128 DD L = 1 capture 3.25 GiB measured, so L = 2 is
# declared at 4.5 GiB, cap 7); a hold-file check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round14
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r9
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts/dd-gate-r9
HOLDF=$E/HOLD
cd /tmp
python3 - <<'PY' || { echo "PRODUCTION FILES OR SOURCES MOVED" > $P/r14_heavy2.finished; exit 4; }
import hashlib, json, os, sys
R = "/home/victor/IntelligenceRegulation"
T = R + "/ops/zkp-mvp/trained-1b-gate-r9"
m = json.load(open(R + "/results/zk60_1b_native_20261017/r9/manifest_frozen.json"))["files"]
test_only = {"hashline/src/private_block/run_capture.rs", "hashline/src/private_block/plane_index.rs", "hashline/src/private_block/run_capture_tests.rs"}
sh = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
bad = [f for f, h in m.items() if f not in test_only and sh(os.path.join(T, f)) != h]
v2 = dict(l.split("  ")[::-1] for l in open(R + "/results/zk60_gate_tinyllama_20261017/round14/trained-1b-gate-r9.sources.v2.sha256").read().splitlines())
moved = [f for f, h in v2.items() if sh(os.path.join(T, f)) != h]
print("production files moved:", bad, "sources moved from v2:", moved)
sys.exit(1 if bad or moved else 0)
PY
g() {  # g <class> <label> <need> <cap> <max> -- cmd...
  local c=$1 l=$2 n=$3 k=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class $c --need-gib $n --cap-gib $k --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/r14_heavy2.progress
  return $rc
}
binof() { local b; b=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $1 | tail -1 | sed 's/.*(\(.*\))/\1/'); case "$b" in /*) ;; *) b=$2/hashline/$b ;; esac; echo $b; }
g build r14-build-gate-v2 2.6 5 3600 -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml || { date -u > $P/r14_heavy2.finished; exit 5; }
BIN=$(binof $P/r14-build-gate-v2.log $T)
sha256sum $BIN > $P/r14-test-binary-v2.sha256
RC="private_block::run_capture_tests"
g cpu r14-planeindex-v2 0.5 1.5 900 -- $BIN $RC::the_plane_index_builds_at_the_dd_layouts --exact --nocapture --test-threads 1 || { date -u > $P/r14_heavy2.finished; exit 6; }
g cpu r14-capture-suite-v2 2 3.5 3600 -- $BIN $RC:: --test-threads 1
LBL="HL_TEST_SOURCE_COMMIT=trained-1b-gate-r9-sources-v2-d9b80c92"
cap() {  # cap <name> <test> <need> <cap> <env...>
  local nm=$1 t=$2 n=$3 k=$4; shift 4
  [ -e $A/$nm ] && { echo "$(date -u +%H:%M:%S) $nm exists" >> $P/r14_heavy2.progress; return 1; }
  g cpu cap-$nm $n $k 3600 -- env HL_PB_CAPTURE_DIR=$A/$nm HL_RUN_CAPTURE_PUBLIC_TABLES=1 $LBL "$@" $BIN $RC::$t --exact --ignored --nocapture --test-threads 1
}
cap tl128dd-l2-dense capture_a_tinyllama_t128_dd_run 4.5 7 HL_PB_INPUT=dense HL_PB_CAPTURE_BLOCKS=2 HL_PB_FIRST_LAYER=0 HL_PB_SEQ=ho00
cap tl128dd-l2-zero capture_a_tinyllama_t128_dd_run 4.5 7 HL_PB_INPUT=zero HL_PB_CAPTURE_BLOCKS=2 HL_PB_FIRST_LAYER=0
date -u > $P/r14_heavy2.finished
