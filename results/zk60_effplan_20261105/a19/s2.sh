#!/bin/bash
# A19 stage 2, the A/Bs through PRODUCTION's D55 path (`trained_block::d55_seal_and_prove`, what `stack-prove
# --d55-workers` runs) on the D55 harness's synthetic W16R2 8B T128 32-block stack, in-process, 6 passes, both arm
# orders (HL_D55_AB_ALTERNATE=1), N = 6, the witness budget the Mac's default (32 GiB). (a) A13's window: noahead
# against ahead16 (the blocks shared, the A19 default). (b) the blocks: share0+noahead (every block loaded again after
# the sealing pass, the path before A19) against share1+noahead. Each timing step waits for a quiet GPU (no
# `ds4-bench`) and records whether one ran at its end. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1f45d632690f8326
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a19
E=$W/results/zk60_effplan_20261105
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::a19_production_d55_ab
P=$O/s2.progress
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
$C --no-run > $O/raw/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $O/raw/s2_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
A="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_AB_PASSES=6 HL_D55_AB_ALTERNATE=1 HL_A19_BUDGET_GIB=32"
quiet "s2a window A/B"
env $A HL_A19_AB=noahead,ahead16 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2a_prod_ab.log 2>&1; say "s2a noahead against ahead16 rc=$?"
seen "s2a window A/B"
grep -E "^D55-AB (A19|GPU-AB|A11 USAGE|A15 SEALED|SUMMARY)" $O/raw/s2a_prod_ab.log | cut -c1-900 > $O/s2a_prod_ab.log
python3 $E/a11/pairs.py $O/raw/s2a_prod_ab.log noahead ahead16 --alternate --n 6 > $O/s2a_pairs.md 2>&1
python3 $E/a15/seal_pairs.py $O/raw/s2a_prod_ab.log noahead ahead16 --n 6 > $O/s2a_seal.md 2>&1
cat $O/s2a_pairs.md $O/s2a_seal.md >> $P
grep -E "SUMMARY|panicked" $O/raw/s2a_prod_ab.log | cut -c1-300 >> $P
quiet "s2b blocks A/B"
env $A HL_A19_AB=share0+noahead,share1+noahead $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2b_prod_ab.log 2>&1; say "s2b share0 against share1 (window off) rc=$?"
seen "s2b blocks A/B"
grep -E "^D55-AB (A19|GPU-AB|A11 USAGE|A15 SEALED|SUMMARY)" $O/raw/s2b_prod_ab.log | cut -c1-900 > $O/s2b_prod_ab.log
python3 $E/a11/pairs.py $O/raw/s2b_prod_ab.log share0+noahead share1+noahead --alternate --n 6 > $O/s2b_pairs.md 2>&1
python3 $E/a15/seal_pairs.py $O/raw/s2b_prod_ab.log share0+noahead share1+noahead --n 6 > $O/s2b_seal.md 2>&1
cat $O/s2b_pairs.md $O/s2b_seal.md >> $P
grep -E "SUMMARY|panicked" $O/raw/s2b_prod_ab.log | cut -c1-300 >> $P
# (c) the window again with each load only copying its block (HL_A19_SYNTH_LOAD=copy: the D55 harness's sealing pass,
# which loads nothing, plus a copy), to join these numbers to A18's harness A/B
quiet "s2c window A/B, copy loads"
env $A HL_A19_SYNTH_LOAD=copy HL_A19_AB=noahead,ahead16 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s2c_prod_ab.log 2>&1; say "s2c noahead against ahead16, copy loads, rc=$?"
seen "s2c window A/B, copy loads"
grep -E "^D55-AB (A19|GPU-AB|A11 USAGE|A15 SEALED|SUMMARY)" $O/raw/s2c_prod_ab.log | cut -c1-900 > $O/s2c_prod_ab.log
python3 $E/a11/pairs.py $O/raw/s2c_prod_ab.log noahead ahead16 --alternate --n 6 > $O/s2c_pairs.md 2>&1
python3 $E/a15/seal_pairs.py $O/raw/s2c_prod_ab.log noahead ahead16 --n 6 > $O/s2c_seal.md 2>&1
cat $O/s2c_pairs.md $O/s2c_seal.md >> $P
grep -E "SUMMARY|panicked" $O/raw/s2c_prod_ab.log | cut -c1-300 >> $P
say "all done"
