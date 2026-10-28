#!/bin/bash
# PRIVACY GATE lane, gate round 10: the Rust side, on the gate's tk7 copy
# (test-only additions: gr4_token_tests.rs, the P-18 port).
#   build (class build), then on the test binary:
#   PR4-8  the token-run root-rebuild replay, L = 1 and 2, dense and fixed;
#   PR4-9  the calibration attribution, TinyLlama b4 (L = 1, 2, 22) and 8B b7voc0 (L = 1, 2);
#   PR4-2  the P-18 capture of the tk7 CLI run directory.
# Queue rules: one job at a time; declarations from measured peaks plus a
# margin (first runs: generous, the R7 analogues' peaks noted); a hold-file
# check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round10
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk7
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
A=/home/victor/zk60-artifacts
HOLDF=$E/HOLD
cd /tmp
python3 - <<'PY' || { echo "SOURCES MOVED" > $P/r10_heavy.finished; exit 4; }
import hashlib, os, sys
root = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-tk7"
bad = [p for d, p in (l.split(None, 1) for l in open("/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/round10/trained-1b-gate-tk7.sources.v2.sha256"))
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
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/r10_heavy.progress
  return $rc
}
# measured: the tk7 test build 4 min 53 s (R7 analogue peak 1.8 GiB)
g build r10-build 3 5 3600 -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml || { date -u > $P/r10_heavy.finished; exit 5; }
BIN=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $P/r10-build.log | tail -1 | sed 's/.*(\(.*\))/\1/')
case "$BIN" in /*) ;; *) BIN=$T/hashline/$BIN ;; esac
[ -x "$BIN" ] || { echo "NO BINARY" > $P/r10_heavy.finished; exit 6; }
sha256sum $BIN > $P/hashline-lib-test-release.r10.sha256
GT="private_block::run_capture_tests::gr4_trained_tests::gr4_token_tests"
XP=/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929/export/pg_rot1_b4_T32_cal128
HD=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r2_inputs
X8=/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019/exports/llama3_8b_pg_rot1_b7voc0_T32
ENV="env HL_PB_TOKEN_EXPORT=$XP HL_PB_TOKEN_HEAD=$HD HL_PB_TOKEN_EXPORT_8B=$X8"
# PR4-9 first (no proof; one block resident at a time)
g cpu r10-pr4-9-tinyllama 3 5 3600 -- $ENV $BIN $GT::pr4_9_calibration_words_tinyllama_b4 --exact --ignored --nocapture --test-threads 1
g cpu r10-pr4-9-8b 5 8 3600 -- $ENV $BIN $GT::pr4_9_calibration_words_llama3_8b_b7voc0 --exact --ignored --nocapture --test-threads 1
# PR4-8 (R7's two-block run replay: 15 s, 1.04 GiB; a token run adds two small stages)
for t in gr4_token_t32_l1_dense_ho00_commits_exactly_the_predicted_stream gr4_token_t32_l1_fixed_commits_exactly_the_predicted_stream gr4_token_t32_l2_dense_ho00_commits_exactly_the_predicted_stream gr4_token_t32_l2_fixed_commits_exactly_the_predicted_stream; do
  g cpu r10-${t#gr4_token_t32_} 3 5 1800 -- $ENV $BIN $GT::$t --exact --ignored --nocapture --test-threads 1
done
# PR4-2: the P-18 capture of the tk7 CLI run directory (R7 P-18 capture: about a minute)
CAP=$A/tinyllama-cli-tk7-capture-dense-l2
if [ ! -e $CAP ]; then
  g cpu r10-pr4-2-cli-capture 2.5 4 1800 -- env HL_PB_EXPORT=$A/tinyllama-cli-r7-verifier-export HL_PB_ARTIFACT=$A/tinyllama-cli-tk7-run-l2 HL_PB_LAYERS=7..9 HL_PB_LABEL=zk60-trained-stack HL_PB_CAPTURE_DIR=$CAP HL_PB_SEQ=ho00 HL_PB_CLI_SHA256=dac7fc7303ac5ce935cda487e539194bf6044e9685c948f92556c0f97dc17b93 HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=trained-1b-gate-tk7-sources-v2 $BIN private_block::run_capture_tests::capture_a_cli_run_directory --exact --ignored --nocapture --test-threads 1
fi
date -u > $P/r10_heavy.finished
