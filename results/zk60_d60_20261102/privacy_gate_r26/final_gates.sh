#!/bin/bash
# Gate round 26 wiring (2026-11-02): the floors before the records commit, on the FINAL code (the test binary of
# logs/build1.log, built from the Rust of 23199feb; no Rust file changed after it), guarded, one after another:
# the source scans (58/58), the dev bytes gate (CPU = Metal, 01fa1b2e / 992034f8 / 371e6b00 / 3ab090df), the
# D55 / D60 set on the CPU, the w16_privacy_gate set, the capture allow-list / pin tests, the W16 / W16R2
# one-block gate regressions, and the staging_v25 Python suite with every bundle named.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad2863f50f3102344/results/zk60_d60_20261102/privacy_gate_r26
L=$P/logs
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad2863f50f3102344
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
O=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
S=$R/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts
T=private_block::slot_ir::accuracy::tests
rc=0
step() { echo "== $1 $(date +%H:%M:%S)"; }
step warnings
echo "build1 (gpu-metal test build + no-feature check): $(grep -c '^warning' $L/build1.log) warnings, $(grep -c 'Finished' $L/build1.log) Finished"
step scans
bash $P/run.sh scans_final cpu 4 20 -- r19b s24 s25 absorb s33 hash_domain:: || rc=1
grep -q "test result: ok. 58 passed; 0 failed" $L/scans_final.log || { echo "THE SCAN SET IS NOT 58/0"; rc=1; }
sleep 3
step devbytes
bash $P/run.sh devbytes gpu 60 160 HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 -- --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal || rc=1
grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}.*" $L/devbytes.log | cut -c1-120
for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
  grep -q "M4-ACCURACY-DIGEST $d" $L/devbytes.log || { echo "BYTES MOVED: $d"; rc=1; }
done
sleep 3
step d55-cpu
bash $P/run.sh d55_cpu cpu 8 40 -- private_block::run::fork:: --nocapture --test-threads=1 || rc=1
grep -h "D60 CAPTURE\|test result" $L/d55_cpu.log | cut -c1-300
grep -q "test result: ok\. [0-9]* passed; 0 failed" $L/d55_cpu.log || { echo "THE D55 SET FAILED"; rc=1; }
grep -q "D60 CAPTURE | the Rust gate on the written bundle: R13_RUNG_H24 D55-registered registered: .* all PASS" $L/d55_cpu.log || { echo "THE D60 WRITER TEST DID NOT RUN THE RUST GATE"; rc=1; }
sleep 3
step w16-privacy-gate
bash $P/run.sh w16pg cpu 8 40 -- private_block::w16_privacy_gate_tests:: --test-threads=4 || rc=1
grep -q "test result: ok\. [0-9]* passed; 0 failed" $L/w16pg.log || { echo "THE W16 PRIVACY GATE SET FAILED"; rc=1; }
sleep 3
step capture-tests
bash $P/run.sh capture_final cpu 4 20 -- every_key_of_a_bundle_is_on_the_allow_list the_bundle_pins_every_source_file_that_decides_its_contents the_capture_writer_pins_every_run_layer_source_it_depends_on || rc=1
grep -q "test result: ok. 3 passed; 0 failed" $L/capture_final.log || { echo "THE CAPTURE TESTS ARE NOT 3/0"; rc=1; }
sleep 3
step w16-one-block-regressions
for b in w16_rung_h24-s0 w16r2_rung_h24-s0; do
  rm -f $L/py-w16blk-$b.log $L/py-w16blk-$b.guard.done
  $G --class cpu --need-gib 4 --cap-gib 24 --label r26-w16blk-$b --wait-secs 7200 --max-secs 3600 --log $L/py-w16blk-$b.log --done $L/py-w16blk-$b.guard.done -- \
    $PY -B $S/zk60_native_rg_w16.py --bundle $W/$b --evidence $P/records --name blk-$b || rc=1
  grep -h "^status\|^pins" $L/py-w16blk-$b.log | cut -c1-300
done
sleep 3
step py-suite
rm -f $L/suite_v25.log $L/suite_v25.guard.done
$G --class cpu --need-gib 4 --cap-gib 24 --label r26-suite --wait-secs 7200 --max-secs 3600 --log $L/suite_v25.log --done $L/suite_v25.guard.done -- \
  env ZK60_W16_RUNG_BUNDLE=$W/w16_rung_h24-s0 ZK60_W16R2_RUNG_BUNDLE=$W/w16r2_rung_h24-s0 ZK60_D55_BUNDLE=$W/d55-w16_rung_h24-s0 \
  ZK60_D55_R13_BUNDLE=$B/d55-r13_rung_h24-s0 ZK60_D55_R13_OTHER=$B/d55-r13_rung_h24-s1 ZK60_D60_OLD_BUNDLE=$O/d55-r13_rung_h24-s0 \
  $PY -B -m unittest discover -s $R/ops/zkp-mvp/gate-tinyllama/staging_v25/tests -v
grep -E "^(FAIL|ERROR):|^Ran |^OK|^FAILED" $L/suite_v25.log
step done
exit $rc
