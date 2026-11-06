#!/bin/bash
# A19 stage 3: window 16 did not clear the noise floor on one request through production's path (stage 2), so window 8
# is not run; instead the whole window, which production's long sealing pass leaves slack for: noahead against ahead32,
# the witness budget raised to 64 GiB (at the default 32 GiB the budget holds about 26 parts), the hashing loads, 6
# passes, both orders. Waits for a quiet GPU. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a19
E=$W/results/zk60_effplan_20261105
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::a19_production_d55_ab
P=$O/s3.progress
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
$C --no-run > $O/raw/s3_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
A="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_A19_BUDGET_GIB=64"
quiet "s3 window 32 A/B"
env $A HL_A19_AB=noahead,ahead32 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s3_prod_ab.log 2>&1; say "s3 noahead against ahead32 (budget 64 GiB) rc=$?"
seen "s3 window 32 A/B"
grep -E "^D55-AB (A19|GPU-AB|A11 USAGE|A15 SEALED|SUMMARY)" $O/raw/s3_prod_ab.log | cut -c1-900 > $O/s3_prod_ab.log
python3 $E/a11/pairs.py $O/raw/s3_prod_ab.log noahead ahead32 --alternate --n 6 > $O/s3_pairs.md 2>&1
python3 $E/a15/seal_pairs.py $O/raw/s3_prod_ab.log noahead ahead32 --n 6 > $O/s3_seal.md 2>&1
cat $O/s3_pairs.md $O/s3_seal.md >> $P
grep -E "SUMMARY|panicked" $O/raw/s3_prod_ab.log | cut -c1-300 >> $P
say "all done"
