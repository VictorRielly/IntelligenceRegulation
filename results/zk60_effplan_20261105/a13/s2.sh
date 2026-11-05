#!/bin/bash
# A13 stage 2: build; the A13 byte tests (the split core at the W16R2 rung golden on the CPU and the device; every
# fork parked against the same fork whole, and the three real paths at several windows, N and side workers, on the
# CPU and the device); the census and regression subset the change touches (s25 incl. W-8 and r19b, hash-domain
# scans, every non-ignored D55 test); then an exploratory in-process A/B at N = 6 over five arms, 2 passes in
# alternating order (one request from its input and a 4-request stream; the proof-only call is the control: no
# sealing pass, so no part is made ahead). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a13
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 6 $O/s2_build.log | head -60 >> $P
  say "all done (build failed)"
  exit 1
fi
$C private_block::w16r2_tests::a13_w16r2_rung_golden_with_the_core_split_across_threads -- --exact --nocapture --test-threads=1 > $O/s2_split_cpu.log 2>&1; say "a13 split core golden (CPU) rc=$?"
grep -E "A13-SPLIT|test result|panicked" $O/s2_split_cpu.log | cut -c1-300 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::w16r2_tests::a13_w16r2_rung_golden_with_the_core_split_across_threads_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s2_split_metal.log 2>&1; say "a13 split core golden (Metal) rc=$?"
grep -E "A13-SPLIT|test result|panicked" $O/s2_split_metal.log | cut -c1-300 >> $P
$C private_block::run::fork::a13_tests::a13_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung -- --exact --nocapture --test-threads=1 > $O/s2_bytes_cpu.log 2>&1; say "a13 fork byte test (CPU) rc=$?"
grep -E "A13-BYTES|test result|panicked" $O/s2_bytes_cpu.log | cut -c1-300 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C private_block::run::fork::a13_tests::a13_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $O/s2_bytes_metal.log 2>&1; say "a13 fork byte test (Metal) rc=$?"
grep -E "A13-BYTES|test result|panicked" $O/s2_bytes_metal.log | cut -c1-300 >> $P
env HL_R13_LOADER_FIXTURES=$F $C private_block::s25_tests -- --test-threads=8 > $O/s2_s25.log 2>&1; say "s25 census rc=$?"
grep -E "^test result|FAILED|panicked" $O/s2_s25.log | cut -c1-300 >> $P
env HL_R13_LOADER_FIXTURES=$F $C private_block::hash_domain_tests -- --test-threads=8 > $O/s2_hashdomain.log 2>&1; say "hash-domain scans rc=$?"
grep -E "^test result|FAILED|panicked" $O/s2_hashdomain.log | cut -c1-300 >> $P
env HL_R13_LOADER_FIXTURES=$F $C private_block::run::fork -- --test-threads=8 > $O/s2_fork_tests.log 2>&1; say "every non-ignored D55 test rc=$?"
grep -E "^test result|FAILED|panicked" $O/s2_fork_tests.log | cut -c1-300 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=2 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=noahead,ahead32,ahead16,ahead32+aw1,ahead32+aw3+ap4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s2_d55_ab.log 2>&1
say "d55 exploration rc=$?"
grep -E "^D55-AB SUMMARY|panicked" $O/s2_d55_ab.log | cut -c1-240 >> $P
grep -E "^D55-AB A13 SEALED" $O/s2_d55_ab.log | cut -c1-420 >> $P
grep -E "^D55-AB A13 PIPE-SEAL" $O/s2_d55_ab.log | cut -c1-200 | head -12 >> $P
for t in ahead32 ahead16 ahead32+aw1 ahead32+aw3+ap4; do
  python3 $W/results/zk60_effplan_20261105/a11/pairs.py $O/s2_d55_ab.log noahead $t --alternate --n 6 > "$O/s2_pairs_$t.md" 2>&1
  echo "--- $t" >> $P
  grep -E "^\| (proof|sealed|stream)" "$O/s2_pairs_$t.md" >> $P
done
say "all done"
