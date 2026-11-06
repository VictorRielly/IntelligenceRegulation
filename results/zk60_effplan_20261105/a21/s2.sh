#!/bin/bash
# A21 stage 2, the A/Bs through PRODUCTION's D55 path (`trained_block::d55_seal_and_prove`, what `stack-prove
# --d55-workers` runs) on the D55 harness's synthetic W16R2 8B T128 32-block stack (each load copies the block and
# hashes its record, as production's load does), in-process, 6 passes, both arm orders (HL_D55_AB_ALTERNATE=1),
# N = 6, the witness budget the Mac's default (32 GiB), A13's window off, the blocks shared and A20's forms at their
# defaults. Each A21 form alone against both off (`a21old`), both together, and each form taken out of the defaults.
# Each timing step waits for a quiet GPU (no RUNNING `ds4-bench`, by process name) and records whether one ran at
# its end. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-accc7730ca1479119
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a21
E=$W/results/zk60_effplan_20261105
R=$O/raw
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::a19_production_d55_ab
P=$O/s2.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
EXT='ds4-bench'
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
$C --no-run > $R/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s2_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
A="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_A19_BUDGET_GIB=32"
ab() {
  local tag=$1 base=$2 test=$3
  quiet "s2$tag $base against $test"
  env $A HL_A19_AB=$base,$test $C $D -- --ignored --exact --nocapture --test-threads=1 > $R/s2${tag}_prod_ab.log 2>&1; say "s2$tag $base against $test rc=$?"
  seen "s2$tag $base against $test"
  grep -E "^D55-AB (A19|GPU-AB|A11 USAGE|A15 SEALED|SUMMARY)" $R/s2${tag}_prod_ab.log | cut -c1-1300 > $O/s2${tag}_prod_ab.log
  python3 $E/a11/pairs.py $R/s2${tag}_prod_ab.log $base $test --alternate --n 6 > $O/s2${tag}_pairs.md 2>&1
  python3 $E/a15/seal_pairs.py $R/s2${tag}_prod_ab.log $base $test --n 6 > $O/s2${tag}_seal.md 2>&1
  python3 $O/prod_pairs.py $R/s2${tag}_prod_ab.log $base $test > $O/s2${tag}_prod_pairs.md 2>&1
  python3 $E/a19/prod_table.py $R/s2${tag}_prod_ab.log > $O/s2${tag}_table.md 2>&1
  cat $O/s2${tag}_pairs.md $O/s2${tag}_seal.md $O/s2${tag}_prod_pairs.md $O/s2${tag}_table.md >> $P
  grep -E "SUMMARY|panicked" $R/s2${tag}_prod_ab.log | cut -c1-300 >> $P
}
# each form alone against both off
ab a a21old a21old+sha1
ab b a21old a21old+b3par1
# both together against both off
ab c a21old default
# each form taken out of the defaults
ab d default+sha0 default
ab e default+b3par0 default
say "all done"
