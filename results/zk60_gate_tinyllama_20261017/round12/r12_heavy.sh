#!/bin/bash
# PRIVACY GATE lane, gate round 12: re-capture the ten harness token
# captures on frozen-r9.  The tree is `ops/zkp-mvp/token-gate-r9/`, an
# UNMODIFIED rsync of frozen-r9 (236 / 236 = manifest_final_r9, b666a991), so
# every capture pins exactly frozen-r9's files (the token writer aaff4e6e
# included).  The token lane's own capture tests and commands, the same
# exports (defaults), the same layers and prompts; new bundle dirs under
# ~/zk60-artifacts/token-io-r9-gate/captures/.
# Queue rules: declarations from the token lane's measured capture peaks
# (TinyLlama L1/L2 1.0-1.25 GiB, L22 3.05 rss / 3.74 cgroup, 8B 3.2-3.5 rss /
# 3.9 cgroup) plus a margin; the tk9 build 3 min 39 s; a hold-file check
# before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round12
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-gate-r9
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io-r9-gate/captures
HOLDF=$E/HOLD
cd /tmp
python3 - <<'PY' || { echo "SOURCES MOVED" > $P/r12_heavy.finished; exit 4; }
import hashlib, os, sys
root = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-gate-r9"
man = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/manifest_final_r9.sha256"
bad = [p for d, p in (l.split(None, 1) for l in open(man) if l.strip())
       if hashlib.sha256(open(os.path.join(root, p.strip()), "rb").read()).hexdigest() != d]
print("moved", bad)
sys.exit(1 if bad else 0)
PY
g() {  # g <class> <label> <need> <cap> <max> -- cmd...
  local c=$1 l=$2 n=$3 k=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class $c --need-gib $n --cap-gib $k --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/r12_heavy.progress
  return $rc
}
g build r12-build 2.6 5 3600 -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml || { date -u > $P/r12_heavy.finished; exit 5; }
BIN=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $P/r12-build.log | tail -1 | sed 's/.*(\(.*\))/\1/')
case "$BIN" in /*) ;; *) BIN=$T/hashline/$BIN ;; esac
[ -x "$BIN" ] || { echo "NO BINARY" > $P/r12_heavy.finished; exit 6; }
sha256sum $BIN > $P/hashline-lib-test-release.r12.sha256
mkdir -p $C
cap() {  # cap <name> <test> <blocks> <input> <need> <cap>
  local nm=$1 t=$2 b=$3 i=$4 n=$5 k=$6
  [ -e $C/$nm ] && { echo "$(date -u +%H:%M:%S) $nm exists" >> $P/r12_heavy.progress; date -u > $P/r12_heavy.finished; exit 7; }
  g cpu cap-$nm $n $k 1800 -- env HL_PB_CAPTURE_DIR=$C/$nm HL_PB_CAPTURE_BLOCKS=$b HL_PB_FIRST_LAYER=0 HL_PB_TOKEN_INPUT=$i HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=frozen-r9-b666a991-gate-copy $BIN private_block::token_io::capture_tests::$t --exact --ignored --nocapture --test-threads 1
  [ -f $C/$nm/manifest.json ] || echo "$(date -u +%H:%M:%S) $nm: no manifest" >> $P/r12_heavy.progress
}
TL=capture_a_tinyllama_token_run
L8=capture_a_llama3_8b_token_run
cap tinyllama-t32-L1-dense-pt1 $TL 1 dense 1.6 2.5
cap tinyllama-t32-L1-fixed-pt1 $TL 1 fixed 1.6 2.5
cap tinyllama-t32-L2-dense-pt1 $TL 2 dense 1.6 2.5
cap tinyllama-t32-L2-fixed-pt1 $TL 2 fixed 1.6 2.5
cap tinyllama-t32-L22-dense-pt1 $TL 22 dense 4 5
cap tinyllama-t32-L22-fixed-pt1 $TL 22 fixed 4 5
cap llama3-8b-t32-L1-dense-pt1 $L8 1 dense 4.2 5.5
cap llama3-8b-t32-L1-fixed-pt1 $L8 1 fixed 4.2 5.5
cap llama3-8b-t32-L2-dense-pt1 $L8 2 dense 4.2 5.5
cap llama3-8b-t32-L2-fixed-pt1 $L8 2 fixed 4.2 5.5
date -u > $P/r12_heavy.finished
