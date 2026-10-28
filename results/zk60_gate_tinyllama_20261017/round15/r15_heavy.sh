#!/bin/bash
# PRIVACY GATE lane, gate round 15: the frozen-r11 re-pin. Build the gate's
# UNMODIFIED copy of frozen-r11 (`ops/zkp-mvp/token-gate-r11/`, 237 / 237 =
# manifest_final_r11, d8075d76) and re-run the CLI-path capture through the
# NAMED round-11 CPU binary (cli/zk60_token_io.r11.release.bin, 0c9f247c...):
# the token lane's own test `capture_the_cli_verify_path_at_tinyllama_t32_l2`
# (the CLI's prove and verify as that binary's own processes; then the run
# directory read with the CLI's readers and verified with the recorder).
# Work files (the export view, the run directory, the owners' decommitments)
# go to a NEW directory under ~/zk60-owner-private/, which this lane never
# reads (D21). The bundle goes to ~/zk60-artifacts/token-io-r11-gate/captures/.
# Queue rules: declarations from measured peaks plus a margin (token test
# build 2.0 GiB / ~4 min; the r9 CLI capture 1.15 GiB rss, 1.36 GiB cgroup,
# 22 s); a hold-file check before each job (EV/HOLD).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round15
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-gate-r11
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
C=/home/victor/zk60-artifacts/token-io-r11-gate/captures
CLI=/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/zk60_token_io.r11.release.bin
CLISHA=0c9f247c0f91162177f8ed90285f8664cc4dd36ebd8934dc650804bafe5c2c6b
WORK=/home/victor/zk60-owner-private/gate-r15-cli-work
HOLDF=$E/HOLD
cd /tmp
python3 - <<'PY' || { echo "SOURCES OR BINARY MOVED" > $P/r15_heavy.finished; exit 4; }
import hashlib, os, sys
root = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-gate-r11"
man = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/manifest_final_r11.sha256"
bad = [p for d, p in (l.split(None, 1) for l in open(man) if l.strip())
       if hashlib.sha256(open(os.path.join(root, p.strip()), "rb").read()).hexdigest() != d]
b = hashlib.sha256(open("/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/cli/zk60_token_io.r11.release.bin", "rb").read()).hexdigest()
print("moved", bad, "binary", b)
sys.exit(1 if bad or b != "0c9f247c0f91162177f8ed90285f8664cc4dd36ebd8934dc650804bafe5c2c6b" else 0)
PY
g() {  # g <class> <label> <need> <cap> <max> -- cmd...
  local c=$1 l=$2 n=$3 k=$4 m=$5 rc; shift 6
  while [ -e $HOLDF ]; do sleep 60; done
  python3 $G run --class $c --need-gib $n --cap-gib $k --label gate-$l --wait-secs 21600 --max-secs $m \
    --log $P/$l.log --done $P/$l.done --result-json $P/$l.guard.json -- "$@"
  rc=$?
  echo "$(date -u +%H:%M:%S) $l exit $rc" >> $P/r15_heavy.progress
  return $rc
}
g build r15-build 2.6 5 3600 -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml || { date -u > $P/r15_heavy.finished; exit 5; }
BIN=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $P/r15-build.log | tail -1 | sed 's/.*(\(.*\))/\1/')
case "$BIN" in /*) ;; *) BIN=$T/hashline/$BIN ;; esac
[ -x "$BIN" ] || { echo "NO BINARY" > $P/r15_heavy.finished; exit 6; }
sha256sum $BIN > $P/hashline-lib-test-release.r15.sha256
mkdir -p $C
NM=tinyllama-t32-L2-dense-pt1-cli-r11
[ -e $C/$NM ] && { echo "$(date -u +%H:%M:%S) $NM exists" >> $P/r15_heavy.progress; date -u > $P/r15_heavy.finished; exit 7; }
[ -e $WORK ] && { echo "$(date -u +%H:%M:%S) the work dir exists" >> $P/r15_heavy.progress; date -u > $P/r15_heavy.finished; exit 7; }
g cpu cap-$NM 2 4 1800 -- env HL_PB_CAPTURE_DIR=$C/$NM HL_PB_CLI_WORK=$WORK HL_PB_CLI_BIN=$CLI HL_PB_CLI_BIN_SHA256=$CLISHA HL_RUN_CAPTURE_PUBLIC_TABLES=1 HL_TEST_SOURCE_COMMIT=frozen-r11-d8075d76-gate-copy $BIN private_block::token_io::capture_tests::capture_the_cli_verify_path_at_tinyllama_t32_l2 --exact --ignored --nocapture --test-threads 1
[ -f $C/$NM/manifest.json ] || echo "$(date -u +%H:%M:%S) $NM: no manifest" >> $P/r15_heavy.progress
date -u > $P/r15_heavy.finished
