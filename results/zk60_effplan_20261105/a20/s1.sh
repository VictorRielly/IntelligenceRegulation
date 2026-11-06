#!/bin/bash
# A20 stage 1: build; the no-feature check; the byte evidence and the suites the forms touch (A20's suite tests,
# the D55 fork-run suite with A19's tests, the trained-stack and trained-block tests, R6's sealing-pass audit, s25's
# census and hash_domain's label scan); A20's device tests (production's path at the R13 rung under the forms off and
# on; the 8B block's records, sealing pass and production path); then, each waiting for a quiet GPU (no `ds4-bench`):
# THE PROFILE (`a20_profile_of_the_sealing_pass_loads_and_the_receipt_write`), a `sample` of production's request with
# every form off and on, and a 2-pass smoke A/B through production's function to pick the defaults. One guarded job.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a62001526e01569c9
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a20
E=$W/results/zk60_effplan_20261105
R=$O/raw
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
EXT='ds4-bench'
quiet() {
  local n=0
  while pgrep -f "$EXT" > /dev/null; do
    if [ $n -eq 0 ]; then say "waiting for a quiet GPU ($EXT running): $1"; fi
    n=$((n + 1))
    if [ $n -ge 480 ]; then say "GPU still busy after 4 h; $1 runs anyway (TIMING POLLUTED)"; return; fi
    sleep 30
  done
  say "GPU quiet (no $EXT): $1"
}
seen() { if pgrep -f "$EXT" > /dev/null; then say "$EXT RUNNING at the end of $1 (TIMING POLLUTED)"; else say "no $EXT at the end of $1"; fi; }
say start
$C --no-run > $R/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s1_build.log | head -160 >> $P
  say "all done (build failed)"
  exit 1
fi
grep -E "^warning" -A 6 $R/s1_build.log | grep -E "trained_statement.rs|trained_block.rs|run_fork.rs|run_fork_tests.rs" -B 3 | head -40 >> $P
/opt/homebrew/bin/cargo check --tests --offline --locked --manifest-path $H > $R/s1_check_nometal.log 2>&1; say "no-feature cargo check --tests rc=$?"
grep -E "^error" -A 10 $R/s1_check_nometal.log | head -60 >> $P
# the suites the forms touch (CPU)
for t in "$K" private_block::trained_stack_tests private_block::trained_block_tests private_block::r6_tests private_block::s25_tests private_block::hash_domain_tests; do
  n=$(echo $t | sed 's/.*:://')
  env HL_R13_LOADER_FIXTURES=$F $C $t -- --test-threads=6 > $R/s1_suite_$n.log 2>&1; say "suite $t rc=$?"
  grep -E "^test result|^    [a-z_:0-9]+$|panicked" $R/s1_suite_$n.log | cut -c1-240 | tail -8 >> $P
done
grep -E "A20-(RECORDS|SEAL|WRITE|PROD)" $R/s1_suite_tests.log | cut -c1-400 >> $P
env HL_R13_LOADER_FIXTURES=$F $C $K::a20_ -- --nocapture --test-threads=1 > $R/s1_a20_suite.log 2>&1; say "A20 suite tests alone (nocapture) rc=$?"
grep -E "A20-|test result|panicked" $R/s1_a20_suite.log | cut -c1-500 >> $P
# A20's device tests
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a20_production_d55_path_under_the_forms_off_and_on_at_the_r13_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $R/s1_a20_prod_metal.log 2>&1; say "a20 production path on the device rc=$?"
grep -E "A20-PROD|test result|panicked" $R/s1_a20_prod_metal.log | grep -E "statement identity|every arm|refused|test result|panicked" | cut -c1-400 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C $K::a20_the_8b_records_sealing_pass_and_production_path_under_every_setting -- --ignored --exact --nocapture --test-threads=1 > $R/s1_a20_8b.log 2>&1; say "a20 8B records, sealing pass and production path rc=$?"
grep -E "A20-8B|test result|panicked" $R/s1_a20_8b.log | cut -c1-400 >> $P
# THE PROFILE
quiet "s1 profile"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_A20_REPS=6 $C $K::a20_profile_of_the_sealing_pass_loads_and_the_receipt_write -- --ignored --exact --nocapture --test-threads=1 > $R/s1_profile.log 2>&1; say "profile rc=$?"
seen "s1 profile"
grep -E "^A20-PROFILE" $R/s1_profile.log | cut -c1-400 > $O/s1_profile.log
cat $O/s1_profile.log >> $P
# a `sample` of production's request (every form off, then every form on), 12 s from 26 s into the run
A="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32"
for arm in a20old cast1+recpar1+loads2+write4; do
  quiet "s1 sample $arm"
  env $A HL_A19_AB_PASSES=2 HL_A19_AB=$arm $C $K::a19_production_d55_ab -- --ignored --exact --nocapture --test-threads=1 > $R/s1_sample_run_$arm.log 2>&1 &
  bg=$!
  sleep 26
  pid=$(pgrep -f "deps/hashline-.*a19_production_d55_ab" | head -1)
  if [ -n "$pid" ]; then /usr/bin/sample $pid 12 -mayDie -file $R/s1_sample_$arm.txt > /dev/null 2>&1; say "sample of $arm (pid $pid) rc=$?"; else say "sample of $arm: no test process found"; fi
  wait $bg
  say "sampled run $arm rc=$?"
  seen "s1 sample $arm"
  grep -E "^D55-AB (A19 PROD|SUMMARY)" $R/s1_sample_run_$arm.log | cut -c1-900 >> $P
done
# the smoke A/B (2 passes, both orders) through production's function
quiet "s1 smoke A/B"
env $A HL_A19_AB_PASSES=2 HL_D55_AB_ALTERNATE=1 HL_A19_AB=a20old,cast1+recpar1+loads0+write0,a20old+loads1,a20old+loads2,a20old+loads3,a20old+write4,a20old+write8,cast1+recpar1+loads2+write4 $C $K::a19_production_d55_ab -- --ignored --exact --nocapture --test-threads=1 > $R/s1_smoke_ab.log 2>&1; say "smoke A/B rc=$?"
seen "s1 smoke A/B"
grep -E "^D55-AB (A19|GPU-AB|A11 USAGE|A15 SEALED|SUMMARY)" $R/s1_smoke_ab.log | cut -c1-1000 > $O/s1_smoke_ab.log
python3 $E/a19/prod_table.py $R/s1_smoke_ab.log > $O/s1_smoke_table.md 2>&1
cat $O/s1_smoke_table.md >> $P
grep -E "SUMMARY|panicked" $R/s1_smoke_ab.log | cut -c1-300 >> $P
say "all done"
