#!/bin/bash
# A21 stage 1: the build (cached from stage 0); A21's device byte tests (production's path at the R13 rung under the
# forms off and on, on Metal; the 8B block's words, digest, record, sealing pass and production path); then, each
# waiting for a quiet GPU (no RUNNING `ds4-bench`, matched by process name): THE PROFILE
# (`a21_profile_of_production_hashing`), THE VERIFIER'S A/B (`a21_verifier_ab`, 4 passes, both orders) and a `sample`
# of production's request on the A21 defaults. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a21
E=$W/results/zk60_effplan_20261105
R=$O/raw
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
EXT='ds4-bench'
# a RUNNING ds4-bench, by process name (A20 stage 1: `pgrep -f` also matched a guard wrapper queued behind this job)
quiet() {
  local n=0
  while pgrep "$EXT" > /dev/null; do
    if [ $n -eq 0 ]; then say "waiting for a quiet GPU ($EXT running): $1"; fi
    n=$((n + 1))
    if [ $n -ge 480 ]; then say "GPU still busy after 4 h; $1 runs anyway (TIMING POLLUTED)"; return; fi
    sleep 30
  done
  say "GPU quiet (no $EXT): $1"
}
seen() { if pgrep "$EXT" > /dev/null; then say "$EXT RUNNING at the end of $1 (TIMING POLLUTED)"; else say "no $EXT at the end of $1"; fi; }
say start
$C --no-run > $R/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s1_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
# hash_domain's label scan (its module path: stage 0 named the file's, which filters out every test)
$C private_block::hash_domain::tests -- --test-threads=6 > $R/s1_suite_hash_domain.log 2>&1; say "suite private_block::hash_domain::tests rc=$?"
grep -E "^test result|^    [a-z_:0-9]+$|panicked" $R/s1_suite_hash_domain.log | cut -c1-300 | tail -6 >> $P
# A21's device byte tests
env HL_R13_LOADER_FIXTURES=$F HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 $C $K::a21_production_d55_path_under_the_forms_off_and_on_at_the_r13_rung_on_the_device -- --ignored --exact --nocapture --test-threads=1 > $R/s1_a21_prod_metal.log 2>&1; say "a21 production path at the R13 rung on the device rc=$?"
grep -E "A21-PROD.*(statement identity|every arm)|test result|panicked" $R/s1_a21_prod_metal.log | cut -c1-500 >> $P
env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_PB_ORACLE=0 $C $K::a21_the_8b_words_digest_record_sealing_pass_and_production_path_under_every_setting -- --ignored --exact --nocapture --test-threads=1 > $R/s1_a21_8b.log 2>&1; say "a21 8B words, digest, record, sealing pass and production path rc=$?"
grep -E "A21-8B|test result|panicked" $R/s1_a21_8b.log | cut -c1-500 >> $P
# THE PROFILE
quiet "s1 profile"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_A20_REPS=6 $C $K::a21_profile_of_production_hashing -- --ignored --exact --nocapture --test-threads=1 > $R/s1_profile.log 2>&1; say "profile rc=$?"
seen "s1 profile"
grep -E "^A21-PROFILE" $R/s1_profile.log | cut -c1-400 > $O/s1_profile.log
cat $O/s1_profile.log >> $P
# THE VERIFIER'S A/B
quiet "s1 verifier A/B"
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_A21_VERIFY_PASSES=4 HL_A21_VERIFY_AB=a21old,sha1+b3par0,sha0+b3par1,default $C $K::a21_verifier_ab -- --ignored --exact --nocapture --test-threads=1 > $R/s1_verify_ab.log 2>&1; say "verifier A/B rc=$?"
seen "s1 verifier A/B"
grep -E "^A21-VERIFY|test result|panicked" $R/s1_verify_ab.log | cut -c1-400 > $O/s1_verify_ab.log
for t in default sha1+b3par0 sha0+b3par1; do
  python3 $O/verify_pairs.py $R/s1_verify_ab.log a21old $t >> $O/s1_verify_pairs.md 2>&1
  echo >> $O/s1_verify_pairs.md
done
cat $O/s1_verify_ab.log $O/s1_verify_pairs.md >> $P
# a `sample` of production's request on the A21 defaults (12 s from 20 s into the run: the second call's middle)
A="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32"
quiet "s1 sample default"
env $A HL_A19_AB_PASSES=3 HL_A19_AB=default $C $K::a19_production_d55_ab -- --ignored --exact --nocapture --test-threads=1 > $R/s1_sample_run.log 2>&1 &
bg=$!
sleep 20
pid=$(pgrep -f "deps/hashline-.*a19_production_d55_ab" | head -1)
if [ -n "$pid" ]; then /usr/bin/sample $pid 12 -mayDie -file $R/s1_sample_default.txt > /dev/null 2>&1; say "sample of the defaults (pid $pid) rc=$?"; else say "sample: no test process found"; fi
wait $bg
say "sampled run rc=$?"
seen "s1 sample default"
grep -E "^D55-AB (A19 PROD|SUMMARY)" $R/s1_sample_run.log | cut -c1-1200 >> $P
if [ -f $R/s1_sample_default.txt ]; then
  awk '/Sort by top of stack/{f=1} f' $R/s1_sample_default.txt | head -45 > $O/s1_sample_default_top.txt
fi
say "all done"
