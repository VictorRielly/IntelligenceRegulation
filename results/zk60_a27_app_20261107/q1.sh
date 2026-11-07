#!/bin/bash
# Lane A27, job q1 (one guarded gpu-class job): the quick gates of the kernel changes before the long
# acceptance. The test build; the a27_ unit tests (three-product folds = five-product words; extrapolation);
# the slot census at the trained Shieldstral shape; the M4 byte gates (every development accuracy shape and
# the trained R13 Shieldstral and W16R2 8B blocks: CPU digest = Metal digest = the recorded digests); the
# Metal commitment tests against the CPU (the NTT change). Then the trained R13 Shieldstral block again with
# every A27 switch OFF, for the device clock beside the default (diagnostic only).
set -u
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247
H=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
R=$WT/results/zk60_a27_app_20261107
TAG=${1:-q1}
P=$R/$TAG.progress
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --lib"
T=private_block::slot_ir::accuracy::tests
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $R/${TAG}_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $R/${TAG}_build.log | head -120 >> $P; say "all done (test build failed)"; exit 1; fi
$C a27_ -- --test-threads=4 > $R/${TAG}_a27.log 2>&1; say "a27_ unit tests rc=$?"
grep -E "^test |^test result" $R/${TAG}_a27.log >> $P
$C $T::a27_slot_census_at_a_trained_shape -- --ignored --exact --nocapture --test-threads=1 > $R/${TAG}_census.log 2>&1; say "census rc=$?"
grep -E "A27-CENSUS" $R/${TAG}_census.log | cut -c1-330 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal -- --ignored --exact --nocapture --test-threads=1 > $R/${TAG}_m4dev.log 2>&1; say "M4 development shapes CPU = Metal rc=$?"
grep -E "M4-ACCURACY-DIGEST|test result|panicked" $R/${TAG}_m4dev.log | cut -c1-260 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 HL_M4_WARM_PASSES=2 HL_A27_GPU_TRACE=/Users/victorrielly/zk60-artifacts/a27-traces/${TAG}_trained HL_M4_PROFILES=R13_SHIELD_T128_H24,W16R2_8B_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $R/${TAG}_trained.log 2>&1; say "trained R13 Shieldstral + W16R2 8B CPU = Metal rc=$?"
grep -E "M4-TRAINED.*digest|test result|panicked" $R/${TAG}_trained.log | sed -e 's/digest cpu \([0-9a-f]\{16\}\)[0-9a-f]* metal \([0-9a-f]\{16\}\)[0-9a-f]*/digest cpu \1 metal \2/' | cut -c1-330 >> $P
for d in 5a6193d3 90003b76; do if grep -q "digest cpu $d" $R/${TAG}_trained.log && grep -q "metal $d" $R/${TAG}_trained.log; then say "recorded digest $d: CPU and Metal"; else say "RECORDED DIGEST $d MISSING"; fi; done
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 HL_M4_WARM_PASSES=2 HL_A27_LIN=0 HL_A27_DEGREE=0 HL_A27_FOLD=0 HL_A27_NTT=0 HL_A27_GPU_TRACE=/Users/victorrielly/zk60-artifacts/a27-traces/${TAG}_trained_off HL_M4_PROFILES=R13_SHIELD_T128_H24 $C $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times -- --ignored --exact --nocapture --test-threads=1 > $R/${TAG}_trained_off.log 2>&1; say "trained R13 Shieldstral, every A27 switch off rc=$?"
grep -E "M4-TRAINED.*digest|test result|panicked" $R/${TAG}_trained_off.log | sed -e 's/digest cpu \([0-9a-f]\{16\}\)[0-9a-f]* metal \([0-9a-f]\{16\}\)[0-9a-f]*/digest cpu \1 metal \2/' | cut -c1-330 >> $P
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --features gpu-metal --manifest-path $H --test zk60_metal_commit -- --test-threads=1 > $R/${TAG}_commit.log 2>&1; say "Metal commitment tests rc=$?"
grep -E "^test |^test result" $R/${TAG}_commit.log >> $P
say "all done"
