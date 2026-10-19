#!/bin/bash
# PRIVACY GATE lane, round 6, review round 2 Q-6: the stage-47 G-R4 seeded
# replay extended to a two-block trained run (L = 2), on the gate's R5b copy.
# One guarded build (heavy lock, queued behind whatever holds it), then the
# five gr4 tests one guarded light job at a time: the two new L = 2 tests and
# the three existing ones (unchanged in behaviour; `rebuild` now wraps
# `rebuild_on`).
P=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/q6
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-r5b
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
cd /tmp
sha256sum $T/hashline/src/private_block/gr4_trained_tests.rs > $P/gr4_trained_tests.rs.sha256
python3 $G run --class build --need-gib 3 --cap-gib 5 --label gate-q6-build --wait-secs 21600 --max-secs 3600 \
  --log $P/q6-build.log --done $P/q6-build.done --result-json $P/q6-build.guard.json -- \
  /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml
rc=$?
echo "$(date -u +%H:%M:%S) build exit $rc" >> $P/q6_queue.progress
[ $rc -eq 0 ] || exit 5
BIN=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $P/q6-build.log | tail -1 | sed 's/.*(\(.*\))/\1/')
case "$BIN" in /*) ;; *) BIN=$T/hashline/$BIN ;; esac
sha256sum $BIN > $P/q6-test-binary.sha256
GR="private_block::run_capture_tests::gr4_trained_tests"
for t in gr4_trained_t32_run_l2_dense_ho00_commits_exactly_the_predicted_stream gr4_trained_t32_run_l2_zero_commits_exactly_the_predicted_stream gr4_trained_t32_block_dense_ho00_commits_exactly_the_predicted_stream gr4_trained_t32_block_zero_commits_exactly_the_predicted_stream gr4_trained_t32_boundary_commits_exactly_the_predicted_stream; do
  s=${t#gr4_trained_t32_}
  python3 $G run --class light --need-gib 2.5 --cap-gib 4 --label gate-q6-$s --wait-secs 3600 --max-secs 900 \
    --log $P/q6-$s.log --done $P/q6-$s.done --result-json $P/q6-$s.guard.json -- \
    $BIN $GR::$t --exact --ignored --nocapture --test-threads 1
  echo "$(date -u +%H:%M:%S) $s exit $?" >> $P/q6_queue.progress
done
