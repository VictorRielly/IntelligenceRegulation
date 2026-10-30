#!/bin/bash
# PRIVACY GATE lane, gate round 24, step 3: ONE real capture made by the r19b release binary, on the
# classifier rung (the P-18 CLI path: `capture_the_classify_cli_verify_path`, in token frozen-r19b since
# round 12 / 16): the named binary results/zk60_token_io_r1_20261017/cli/zk60_classify.r19b.release.bin
# (6d65d32e...) runs `zk60_classify prove` and `zk60_classify verify` as its own processes on the rung's tiny
# export; the CLI's own door then reads the run directory and verifies it with the recorder attached.
# The tree is the gate's byte-for-byte copy capture-tree-r19b (306 / 306 = frozen-r19b, round24/COPY_TREE.json).
# 1. the lib test binary (build class; rounds 19 / 22 measured 2.26-2.33 GiB RSS, cgroup up to 2.76 -> 2.9 / 3.5);
# 2. the capture (cpu class; the token lane's P-18 captures 0.21 GiB -> 1.0 / 2.0, as theirs).
# Each step waits for the lean-memory rule (round24/lean_check.py) and the hold files.
# Marker r24_capture.done = 0 when both exited 0, else the failing step's name.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round24
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/capture-tree-r19b/hashline
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
FX=/tmp/claude-1000/-home-victor-IntelligenceRegulation/bcfb5879-8e60-469d-8a11-08d61fb61e65/scratchpad/fx24
R13FX=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
BIN=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/zk60_classify.r19b.release.bin
BINSHA=6d65d32ea783e36db2458ccce2d459cb29a91bcb45a89c4e23e484914126d609
CAPDIR=/home/victor/zk60-artifacts/token-io/captures/classify-rc3-cli-p18-r19b-gate24
CARGO=/home/victor/.cargo/bin/cargo
mkdir -p $FX $P/logs
cd /tmp
wait_lean() {  # wait_lean <need> <class>
  until python3 $P/lean_check.py $1 $2 gate24- > $P/lean.last; do sleep 30; done
}
echo "$(date -u +%H:%M:%S) start" >> $P/r24_capture.progress
wait_lean 2.9 build
date -u +%H:%M:%S > $P/build.launched
python3 $G run --class build --need-gib 2.9 --cap-gib 3.5 --label gate24-build-tests --wait-secs 14400 --max-secs 2400 \
  --log $P/logs/build.log --done $P/logs/build.guard.done --result-json $P/logs/build.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib --no-run
rc=$?
echo "$(date -u +%H:%M:%S) build exit $rc" >> $P/r24_capture.progress
[ $rc -eq 0 ] || { echo build > $P/r24_capture.done; exit 0; }
got=$(sha256sum $BIN | cut -d' ' -f1)
echo "$(date -u +%H:%M:%S) binary $got" >> $P/r24_capture.progress
[ "$got" = "$BINSHA" ] || { echo binary > $P/r24_capture.done; exit 0; }
wait_lean 1.0 cpu
python3 $G run --class cpu --need-gib 1.0 --cap-gib 2.0 --label gate24-cap-p18-r19b --wait-secs 14400 --max-secs 1200 \
  --log $P/logs/capture.log --done $P/logs/capture.guard.done --result-json $P/logs/capture.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$R13FX HL_PB_CAPTURE_DIR=$CAPDIR \
  HL_PB_CLI_BIN=$BIN HL_PB_CLI_BIN_SHA256=$BINSHA HL_RUN_CAPTURE_PUBLIC_TABLES=1 \
  HL_TEST_SOURCE_COMMIT=token-frozen-r19b-cfae2d1e-gate-capture-tree-r19b \
  $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- \
  private_block::token_io::classify_capture_tests::capture_the_classify_cli_verify_path --exact --ignored --nocapture
rc=$?
echo "$(date -u +%H:%M:%S) capture exit $rc" >> $P/r24_capture.progress
[ $rc -eq 0 ] || { echo capture > $P/r24_capture.done; exit 0; }
echo 0 > $P/r24_capture.done
