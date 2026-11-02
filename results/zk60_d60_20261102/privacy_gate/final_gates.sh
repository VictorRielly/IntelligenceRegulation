#!/bin/bash
# D60 privacy gate (2026-11-02): the floors before the commit, on the FINAL test code (guarded, one after another):
# the gpu-metal test build + the no-feature check, the source scans (58/58), the dev bytes gate (CPU = Metal,
# 01fa1b2e / 992034f8 / 371e6b00 / 3ab090df), the D55 / D60 test set on the CPU (the D60 writer test now runs the
# Rust gate on its written bundle), and the staging_v25 Python suite with every bundle named.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ac47d053f76c60f1c/results/zk60_d60_20261102/privacy_gate
L=$P/logs
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ac47d053f76c60f1c
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
T=private_block::slot_ir::accuracy::tests
step() { echo "== $1 $(date +%H:%M:%S)"; }
step build
bash $P/build.sh full build3 || exit 1
grep -c "Finished" $L/build3.log
sleep 5
step scans
bash $P/run.sh scans cpu 4 20 -- r19b s24 s25 absorb s33 hash_domain:: || exit 1
grep -q "test result: ok. 58 passed; 0 failed" $L/scans.log || { echo "THE SCAN SET IS NOT 58/0"; exit 1; }
sleep 5
step devbytes
bash $P/run.sh devbytes gpu 60 160 HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 -- --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal || exit 1
grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}.*" $L/devbytes.log | cut -c1-120
for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
  grep -q "M4-ACCURACY-DIGEST $d" $L/devbytes.log || { echo "BYTES MOVED: $d"; exit 1; }
done
sleep 5
step d55-cpu
bash $P/run.sh d55_cpu cpu 8 40 -- private_block::run::fork:: --nocapture --test-threads=1 || exit 1
grep -h "D60 CAPTURE\|test result" $L/d55_cpu.log | cut -c1-300
grep -q "test result: ok. 18 passed; 0 failed; 4 ignored" $L/d55_cpu.log || { echo "THE D55 SET IS NOT 18 OK / 4 IGNORED"; exit 1; }
grep -q "D60 CAPTURE | the Rust gate on the written bundle: R13_RUNG_H24 D55-registered registered: .* all PASS" $L/d55_cpu.log || { echo "THE D60 WRITER TEST DID NOT RUN THE RUST GATE"; exit 1; }
sleep 5
step py-suite
rm -f $L/suite_v25.log $L/suite_v25.guard.done
$G --class cpu --need-gib 4 --cap-gib 24 --label pg-suite --wait-secs 7200 --max-secs 3600 --log $L/suite_v25.log --done $L/suite_v25.guard.done -- \
  env ZK60_W16_RUNG_BUNDLE=$W/w16_rung_h24-s0 ZK60_W16R2_RUNG_BUNDLE=$W/w16r2_rung_h24-s0 ZK60_D55_BUNDLE=$W/d55-w16_rung_h24-s0 \
  ZK60_D55_R13_BUNDLE=$B/d55-r13_rung_h24-s0 ZK60_D55_R13_OTHER=$B/d55-r13_rung_h24-s1 \
  $PY -B -m unittest discover -s $R/ops/zkp-mvp/gate-tinyllama/staging_v25/tests -v
grep -E "^(FAIL|ERROR):|^Ran |^OK|^FAILED" $L/suite_v25.log
step done
