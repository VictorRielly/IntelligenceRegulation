#!/bin/bash
# G-7 sub-lane (privacy gate): build the gate-owned copy
# ops/zkp-mvp/trained-1b-gate-g7/ (R5b frozen tree 44013397... + the test-only
# module g7_trained_slot_ir_tests.rs), then run the ignored export test with
# the built binary.  Two guarded jobs, one after the other (build under the
# shared heavy lock; the export test as class light).  Not a privacy result.
E=/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/g7
T=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-gate-g7
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
cd /tmp
echo "$(date -u +%FT%TZ) queue start" >> $E/queue.progress
python3 $G run --class build --need-gib 3 --cap-gib 5 --label g7-build --wait-secs 14400 --max-secs 3600 \
  --log $E/g7-build.log --done $E/g7-build.done --result-json $E/g7-build.guard.json -- \
  /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path $T/hashline/Cargo.toml
rc=$?
echo "$(date -u +%FT%TZ) g7-build exit $rc" >> $E/queue.progress
[ $rc -eq 0 ] || exit 5
BIN=$(grep -o "Executable unittests src/lib.rs ([^)]*)" $E/g7-build.log | tail -1 | sed 's/.*(\(.*\))/\1/')
case "$BIN" in /*) ;; *) BIN=$T/hashline/$BIN ;; esac
[ -x "$BIN" ] || { echo "$(date -u +%FT%TZ) no binary ($BIN)" >> $E/queue.progress; exit 6; }
sha256sum $BIN > $E/hashline-lib-test-release.g7.sha256
mkdir -p $E/export
python3 $G run --class light --need-gib 2 --cap-gib 3.5 --label g7-export --wait-secs 14400 --max-secs 1800 \
  --log $E/g7-export.log --done $E/g7-export.done --result-json $E/g7-export.guard.json -- \
  /usr/bin/env HL_G7_OUT=$E/export RAYON_NUM_THREADS=2 $BIN \
  private_block::slot_ir_tests::g7_trained_slot_ir_tests::g7_the_trained_t32_slot_ir_export_at_pg_rot1 \
  --exact --ignored --nocapture --test-threads 1
rc=$?
echo "$(date -u +%FT%TZ) g7-export exit $rc" >> $E/queue.progress
exit $rc
