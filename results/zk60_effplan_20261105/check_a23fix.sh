#!/bin/bash
# A23 merge, follow-up: check_a23merge.sh (with D74's HL_A23_CHECKED default on) passed every step but A22's tests,
# which asserted 0 startup passes whenever HL_A23_CHECKED was left at its default (A23Set::all_checked read an unset
# switch as off; the default was off when A23 ran them). The helper now reads the switches in force. Test-only change;
# no prover source moved. This re-runs what failed and what could be touched: the test build, the full lib suite
# (expect exactly the known three), and A22's three device tests. One guarded job.
set -u
R=/Users/victorrielly/IntelligenceRegulation
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$R/results/zk60_effplan_20261105
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
P=$O/a23fix.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/a23fix_build.log 2>&1; rc=$?; say "test build rc=$rc"
if [ $rc -ne 0 ]; then grep -E "^error" -A 14 $O/a23fix_build.log | head -80 >> $P; say "all done (build failed)"; exit 1; fi
env HL_R13_LOADER_FIXTURES=$F $C -- --test-threads=8 > $O/a23fix_full.log 2>&1; say "full lib suite rc=$? (expect failures: exactly the known three)"
grep -E "^test result|^    [a-z_:0-9]+$" $O/a23fix_full.log | tail -8 >> $P
for t in a22_the_server_proves_the_r13_export_as_stack_prove_does_and_carries_on_after_every_refusal_on_the_device a22_the_resident_synthetic_rung_stream_replays_with_the_window_off_and_on_on_the_device; do
  env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a22::$t -- --ignored --exact --nocapture --test-threads=1 > $O/a23fix_$t.log 2>&1; say "$t rc=$?"
  grep -E "test result|panicked" $O/a23fix_$t.log | cut -c1-300 >> $P
done
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C $K::a22::a22_the_resident_8b_stream_replays -- --ignored --exact --nocapture --test-threads=1 > $O/a23fix_a22_8b.log 2>&1; say "a22 resident 8B stream rc=$?"
grep -E "^A22-|test result|panicked" $O/a23fix_a22_8b.log | cut -c1-400 >> $P
say "all done"
