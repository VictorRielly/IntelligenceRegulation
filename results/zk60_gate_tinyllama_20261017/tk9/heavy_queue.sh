#!/bin/bash
# PRIVACY GATE lane, gate round 10, the frozen-r9 re-pin: build the gate's tk9
# copy (the token lane's frozen round-9 tree, manifest_final_r9 b666a991, +
# the gate's four test-only files, byte-identical to the tk7 copy's: the
# capture patch in run_capture.rs, run_capture_tests.rs with the P-18 port,
# the stage-47 module gr4_trained_tests.rs and its token child
# gr4_token_tests.rs), run the five block stage-47 tests and the four token
# stage-47 tests, capture L = 1, 2, 22 on dense ho00 and the all-zero input,
# build the trained-block CPU CLI and exercise it on review P-18's inputs.
# Queue rules: declarations from the tk7 / round-10 measured peaks plus a
# margin; a hold-file check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/tk9
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk9
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
HOLDF=$E/HOLD
cd /tmp
python3 - <<'PY' || { echo "SOURCES MOVED" > $P/heavy_queue.finished; exit 4; }
import hashlib, os, sys
root = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk9"
bad = [p for d, p in (l.split(None, 1) for l in open("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/tk9/trained-1b-gate-tk9.sources.v1.sha256"))
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
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/heavy_queue.progress
  return $rc
}
# measured: tk7 test build 4 min 53 s, 2.0 GiB
g build tk9-build 2.6 5 3600 -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml || { date -u > $P/heavy_queue.finished; exit 5; }
BIN=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $P/tk9-build.log | tail -1 | sed 's/.*(\(.*\))/\1/')
case "$BIN" in /*) ;; *) BIN=$T/hashline/$BIN ;; esac
[ -x "$BIN" ] || { echo "NO BINARY" > $P/heavy_queue.finished; exit 6; }
sha256sum $BIN > $P/hashline-lib-test-release.tk9.sha256
mkdir -p $A/tinyllama-gate-bins
cp $BIN $A/tinyllama-gate-bins/hashline-lib-test-release.tk9
GR="private_block::run_capture_tests::gr4_trained_tests"
# measured (tk7): 0.3-1.05 GiB, 1-19 s each
for t in gr4_trained_t32_run_l2_dense_ho00_commits_exactly_the_predicted_stream gr4_trained_t32_run_l2_zero_commits_exactly_the_predicted_stream gr4_trained_t32_block_dense_ho00_commits_exactly_the_predicted_stream gr4_trained_t32_block_zero_commits_exactly_the_predicted_stream gr4_trained_t32_boundary_commits_exactly_the_predicted_stream; do
  g cpu gr4-${t#gr4_trained_t32_} 1.5 2.5 900 -- $BIN $GR::$t --exact --ignored --nocapture --test-threads 1
done
GT="$GR::gr4_token_tests"
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128
HD=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r2_inputs
X8=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32
ENV="env HL_PB_TOKEN_EXPORT=$XP HL_PB_TOKEN_HEAD=$HD HL_PB_TOKEN_EXPORT_8B=$X8"
# measured (round 10, tk7): 1.04-1.22 GiB, 16-26 s each
for t in gr4_token_t32_l1_dense_ho00_commits_exactly_the_predicted_stream gr4_token_t32_l1_fixed_commits_exactly_the_predicted_stream gr4_token_t32_l2_dense_ho00_commits_exactly_the_predicted_stream gr4_token_t32_l2_fixed_commits_exactly_the_predicted_stream; do
  g cpu tok-${t#gr4_token_t32_} 1.6 2.5 1800 -- $ENV $BIN $GT::$t --exact --ignored --nocapture --test-threads 1
done
CAP="HL_PB_SEQ=ho00 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=trained-1b-gate-tk9-sources-v1-597b2204"
TEST="private_block::run_capture_tests::capture_a_tinyllama_trained_run --exact --ignored --nocapture --test-threads 1"
cap() {  # cap <label> <need> <cap> <max> <blocks> <first> <input> <dir>
  local l=$1 n=$2 k=$3 m=$4 b=$5 f=$6 i=$7 d=$8
  [ -e $A/$d ] && { echo "$(date -u +%H:%M:%S) $l: $d exists" >> $P/heavy_queue.progress; date -u > $P/heavy_queue.finished; exit 7; }
  g cpu $l $n $k $m -- env $CAP HL_PB_CAPTURE_BLOCKS=$b HL_PB_FIRST_LAYER=$f HL_PB_INPUT=$i HL_PB_CAPTURE_DIR=$A/$d $BIN $TEST
  [ -f $A/$d/manifest.json ] || { echo "$(date -u +%H:%M:%S) $l: no manifest" >> $P/heavy_queue.progress; date -u > $P/heavy_queue.finished; exit 7; }
}
# measured (tk7): L1/L2 0.80-0.95 GiB; L22 2.5 GiB rss, 3.5 GiB cgroup, 80 s
cap capture-tk9-l2-dense 1.3 2.5 1800 2 7 dense tinyllama-trained-tk9-capture-dense-l2
cap capture-tk9-l2-zero 1.3 2.5 1800 2 7 zero tinyllama-trained-tk9-capture-zero-l2
cap capture-tk9-l1-dense 1.3 2.5 1800 1 0 dense tinyllama-trained-tk9-capture-dense-l1
cap capture-tk9-l1-zero 1.3 2.5 1800 1 0 zero tinyllama-trained-tk9-capture-zero-l1
cap capture-tk9-l22-dense 3.5 4.5 3600 22 0 dense tinyllama-trained-tk9-capture-dense-l22
cap capture-tk9-l22-zero 3.5 4.5 3600 22 0 zero tinyllama-trained-tk9-capture-zero-l22
date -u > $P/heavy_queue.captures
# the trained-block CPU CLI from the tk9 copy (the copy differs from frozen-r9
# only in #[cfg(test)] files), with the native lane's own command
# measured (tk7): 1 min 16 s, 1.11 GiB
g build tk9-cli-build 1.6 3 3600 -- /home/victor/.cargo/bin/cargo build --release --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml --example zk60_trained_block || { date -u > $P/heavy_queue.finished; exit 8; }
CLI=$A/tinyllama-gate-bins/zk60_trained_block.tk9.release.bin
cp $T/hashline/target/release/examples/zk60_trained_block $CLI
sha256sum $CLI > $P/zk60_trained_block.tk9.release.bin.sha256
# review P-18's inputs, checked against their manifests first
XP7=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32
SEQ=$A/tinyllama-cli-r7-seq-ho00
VX=$A/tinyllama-cli-r7-verifier-export
RUN=$A/tinyllama-cli-tk9-run-l2
mkdir -p $P/cli
python3 - "$SEQ" "$E/r7cli/inputs.seq-ho00.sha256" "$VX" "$E/r7cli/inputs.verifier-export.sha256" > $P/cli/inputs.check 2>&1 <<'PY' || { echo "INPUTS MOVED" > $P/heavy_queue.finished; exit 9; }
import hashlib, os, sys
bad = 0
for root, man in ((sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])):
    n = 0
    for line in open(man):
        d, p = line.split(None, 1)
        p = p.strip()
        n += 1
        if hashlib.sha256(open(os.path.join(root, p), "rb").read()).hexdigest() != d:
            print("MOVED", root, p); bad += 1
    print(root, n, "listed")
print("bad", bad)
sys.exit(1 if bad else 0)
PY
[ -e $RUN ] && { echo "RUN DIR EXISTS" > $P/heavy_queue.finished; exit 10; }
# measured (tk7): prove 1.04 GiB / 6.5 s, verify 0.27 GiB / 1.3 s
g cpu tk9-cli-stack-prove 1.5 2.5 1800 -- $CLI stack-prove --export $XP7 --seq-dir $SEQ --out $RUN --layers 7..9 --label zk60-trained-stack || { date -u > $P/heavy_queue.finished; exit 11; }
[ -d $RUN.unverified-statement ] && cp -r $RUN.unverified-statement $P/cli/prover-unverified-statement
g cpu tk9-cli-stack-verify 0.6 1.5 1800 -- $CLI stack-verify --export $VX --artifact $RUN --expect-statement ef0610008901e09101709db727a19b30a5de9afb64217e284432afe892aaeb54 --layers 7..9 --label zk60-trained-stack
date -u > $P/heavy_queue.finished
