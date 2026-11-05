#!/bin/bash
# A13 stage 4, THE MITIGATIONS (exploratory): stage 2 found the parts slow the sealing pass by about what they save
# the forks. Here: the parts queued and taken lowest-first by the side workers, any part not started when the forks
# run taken back whole (the new default form), and the side workers' quality of service (qos1 utility, qos2
# background: the efficiency cores); and, harness only, the sealing pass's witness builds in a pool of 16 or 8 threads
# (sp16, sp8: its 26 of 42 CPU-seconds were system time on the 32-thread global pool). The GPU timeline is on (HL_D55_TIMELINE=1), so every SEALED call also prints
# the GPU over its sealing pass (the witness products' queue waits). In-process A/B at N = 6, 2 passes, alternating
# order: one request from its input and a 4-request stream. Then the CPU byte test again on the new form. One
# guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-afed131c59aa694b5
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a13
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s4.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s4_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 8 $O/s4_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
$C private_block::run::fork::a13_tests::a13_parked_forks_equal_whole_forks_byte_for_byte_at_the_w16r2_rung -- --exact --nocapture --test-threads=1 > $O/s4_bytes_cpu.log 2>&1; say "a13 fork byte test (CPU) rc=$?"
grep -E "test result|panicked" $O/s4_bytes_cpu.log | cut -c1-300 >> $P
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_TIMELINE=1 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=2 HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4 HL_D55_GPU_AB=noahead,ahead32+qos2,ahead32+qos1,ahead16+qos2,sp16,sp8,ahead32+qos2+sp16 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s4_d55_ab.log 2>&1
say "d55 exploration rc=$?"
grep -E "^D55-AB SUMMARY|panicked" $O/s4_d55_ab.log | cut -c1-240 >> $P
grep -E "^D55-AB A13 SEALED" $O/s4_d55_ab.log | cut -c1-460 >> $P
grep -E "A13 sealing pass|tag wprod|tag commit" $O/s4_d55_ab.log | cut -c1-260 >> $P
for t in ahead32+qos2 ahead32+qos1 ahead16+qos2 sp16 sp8 ahead32+qos2+sp16; do
  python3 $W/results/zk60_effplan_20261105/a11/pairs.py $O/s4_d55_ab.log noahead $t --alternate --n 6 > "$O/s4_pairs_$t.md" 2>&1
  echo "--- $t" >> $P
  grep -E "^\| (proof|sealed|stream)" "$O/s4_pairs_$t.md" >> $P
done
say "all done"
