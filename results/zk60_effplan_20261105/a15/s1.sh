#!/bin/bash
# A15 stage 1, MEASURE FIRST (the sealing pass alone; no default decided yet). Build; the no-feature
# `cargo check --tests`; the A15 rung test (the pool rule and every witness plane in every pool, CPU). Then the D55
# harness with HL_A15_ONLY=1 (it ends after the sealing passes):
#  (a) the sealing pass alone under every place (sp0 = the global pool from the harness thread, as the harness
#      before A15; spg = the global pool entered on a worker, as seal_and_record's join before A15; sp<t> a
#      sealing pool of t threads), 1 pass, each arm's digest of every plane of every witness of the 32-block chain
#      compared (pools 1 to 32);
#  (b) the same alone, 4 passes, alternating order, for the wall, user / system CPU, context switches and faults;
#  (c) a sampler window (/usr/bin/sample, 2 ms) of 2 sealing passes on sp0, on spg and on sp8.
# The raw call graphs stay in raw/ (not committed). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a15
HS=$O/raw/handshake
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s1.progress
E="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_A15_ONLY=1"
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
mkdir -p $O/raw $HS
$C --no-run > $O/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^(error|warning)" -A 14 $O/s1_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
grep -E "^warning" -A 6 $O/s1_build.log | head -40 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $O/s1_check_nometal.log 2>&1
rc=$?
say "no-feature cargo check --tests rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/s1_check_nometal.log | head -80 >> $P
fi
$C private_block::w16r2_tests::a15_the_seal_pool_rule_and_the_rung_witness_planes_in_every_pool -- --exact --nocapture --test-threads=1 > $O/s1_rung.log 2>&1
say "a15 rung test rc=$?"
grep -E "A15-RUNG|test result|panicked" $O/s1_rung.log | cut -c1-240 >> $P
env $E HL_A15_SEAL_AB=sp0,sp1,sp2,sp4,sp8,sp16,sp32,spg,spauto HL_A15_SEAL_PASSES=1 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_bytes.log 2>&1
say "sealing alone, the 8B chain's planes in every place rc=$?"
grep -E "^D55-AB A15|panicked|one witness" $O/raw/s1_bytes.log | cut -c1-330 >> $P
env $E HL_A15_SEAL_AB=sp0,spg,sp32,sp16,sp12,sp8,sp6,sp4,sp2 HL_A15_SEAL_PASSES=4 HL_D55_AB_ALTERNATE=1 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_alone.log 2>&1
say "sealing alone, 4 passes rc=$?"
grep -E "^D55-AB A15 SEALONLY|panicked" $O/raw/s1_alone.log | cut -c1-330 >> $P
rm -f $HS/go.* $HS/next.*
env $E HL_A15_SAMPLE=2 HL_A15_SAMPLE_ARMS=sp0,spg,sp8 HL_A15_SAMPLE_DIR=$HS $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_sample.log 2>&1 &
TP=$!
for arm in sp0 spg sp8; do
  PID=""
  for i in $(seq 1 1800); do
    PID=$(grep -o "A15-SAMPLE READY $arm pid [0-9]*" $O/raw/s1_sample.log 2>/dev/null | awk '{print $5}')
    [ -n "$PID" ] && break
    kill -0 $TP 2>/dev/null || break
    sleep 1
  done
  say "$arm ready pid ${PID:-none}"
  if [ -n "$PID" ]; then
    /usr/bin/sample "$PID" 11 2 -mayDie -file $O/raw/s1_sample_$arm.txt > $O/raw/s1_sample_$arm.out 2>&1 &
    SP=$!
    sleep 1
    touch $HS/go.$arm
    wait $SP
    say "$arm sample rc=$?"
    touch $HS/next.$arm
  fi
done
wait $TP
say "sample windows rc=$?"
grep -E "^A15-SAMPLE|panicked" $O/raw/s1_sample.log | cut -c1-300 >> $P
say "all done"
