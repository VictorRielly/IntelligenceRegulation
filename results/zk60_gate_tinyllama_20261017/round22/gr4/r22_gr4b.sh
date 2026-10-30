#!/bin/bash
# PRIVACY GATE lane, gate round 22, item 2: the seeded G-R4 replay of a classifier run at the R13 h24 rung,
# in the gate copy ops/zkp-mvp/gate-tinyllama/gr4-tree-r17 (= token frozen-r17, 303 / 303 files, plus the
# test-only module token_io/gr4_classify_tests.rs mounted by one #[path] line in gate19_capture_tests.rs,
# which is not a capture pin). Heavy-slot priority (coordinator 22:50Z): Astra's app post, then token round 18
# (tio18-*): every step waits until NO other lane's guarded job is live or waiting, twice 60 s apart.
# 1. the lib test binary (build class; round 19's build of the same tree size peaked 2.33 GiB -> 2.7 / 3.5);
# 2. three replays (cpu class; round 19's rung captures 0.53-0.56 GiB; the review's form 2 / 3).
# Marker r22_gr4b.done = 0 when all exited 0, else the first failing step's name.
# [r22_gr4b, 00:24 UTC] the first chain's build guard was withdrawn while still queued (SIGTERM, exit 70) on the
# coordinator's 00:23 instruction; this relaunch first waits until Astra's three categories are done (astra_done.py).
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017
P=$E/round22/gr4
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/gr4-tree-r17/hashline
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
W=/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD
A=$E/round20/alone_check.py
FX=/tmp/claude-1000/-home-victor-IntelligenceRegulation/fd35cd14-b711-4cce-8e3f-39cf044eb009/scratchpad/fx22
R13FX=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
CARGO=/home/victor/.cargo/bin/cargo
mkdir -p $FX
cd /tmp
until python3 $P/astra_done.py > $P/astra_done.last; do sleep 60; done
cp $P/astra_done.last $P/astra_done.at_go.json
quiet() {  # no other lane's guarded job live or waiting, twice 60 s apart; no hold file
  while true; do
    while [ -e $W ] || [ -e $E/HOLD ]; do sleep 30; done
    if python3 $A gate22- > $P/alone.last; then
      sleep 60
      if python3 $A gate22- > $P/alone.last; then return 0; fi
    fi
    sleep 30
  done
}
quiet
date -u +%H:%M:%S > $P/build.launched
python3 $G run --class build --need-gib 2.7 --cap-gib 3.5 --label gate22-gr4-build --wait-secs 14400 --max-secs 2400 \
  --log $P/build.log --done $P/build.guard.done --result-json $P/build.guard.json -- \
  /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib --no-run
rc=$?
echo "$(date -u +%H:%M:%S) build exit $rc" >> $P/r22_gr4b.progress
[ $rc -eq 0 ] || { echo build > $P/r22_gr4b.done; exit 0; }
run() {  # run <name> <test fn>
  local nm=$1 fn=$2 rc
  quiet
  python3 $G run --class cpu --need-gib 2.0 --cap-gib 3.0 --label gate22-gr4-$nm --wait-secs 14400 --max-secs 1800 \
    --log $P/$nm.log --done $P/$nm.guard.done --result-json $P/$nm.guard.json -- \
    /usr/bin/env TMPDIR=$FX HL_TIO_FIXTURE_DIR=$FX HL_R13_LOADER_FIXTURES=$R13FX RAYON_NUM_THREADS=4 \
    $CARGO test --release --offline --locked -j2 --manifest-path $H/Cargo.toml --lib -- \
    private_block::token_io::classify_capture_tests::gate19::gr4::$fn --exact --ignored --nocapture
  rc=$?
  echo "$(date -u +%H:%M:%S) $nm exit $rc" >> $P/r22_gr4b.progress
  [ $rc -eq 0 ] || { echo "$nm" > $P/r22_gr4b.done; exit 0; }
}
run l2-v1-whole gr4_classify_r13_rung_l2_v1_whole_commits_exactly_the_predicted_stream
run l2-v0-short1 gr4_classify_r13_rung_l2_v0_short1_commits_exactly_the_predicted_stream
run l1-vtie-whole gr4_classify_r13_rung_l1_vtie_whole_commits_exactly_the_predicted_stream
echo 0 > $P/r22_gr4b.done
