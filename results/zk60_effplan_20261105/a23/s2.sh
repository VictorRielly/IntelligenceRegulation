#!/bin/bash
# A23 stage 2: THE A/B. Production's server stream (`stack-serve`'s code path, `serve_stream` on the resident model) on
# the D55 harness's synthetic W16R2 8B T128 32-block stack, in process, N = 6, the witness budget the Mac's default
# (32 GiB). Arms: today's default (serve4: every request copies the resident blocks), the blocks shared (share1), the
# blocks shared with the startup checks taken (share1+chk1), the latter with smaller sealing pools (seal6, seal4), one
# request and a stream of 8 with the blocks shared and checked, one request at today's default, and the harness's
# stream of 4 (harness4, H124d). 4 passes, the arm order reversed in odd passes. Runs only if stage 1 passed. Each
# timing step waits for a quiet GPU (no RUNNING ds4-bench, matched by process name) and records whether one ran at its
# end. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a34b7617369662958
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a23
R=$O/raw
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
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
if [ "$(cat $O/s1.done 2>/dev/null)" != "0" ] || grep -qE "rc=[1-9]|FAILED|panicked" $O/s1.progress; then
  say "stage 1 did not pass (s1.done: $(cat $O/s1.done 2>/dev/null)); the A/B does not run"
  say "all done (skipped)"
  exit 3
fi
$C --no-run > $R/s2_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 14 $R/s2_build.log | head -120 >> $P
  say "all done (build failed)"
  exit 1
fi
A="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32"
ARMS=${A23_ARMS:-serve4,serve4+share1,serve4+share1+chk1,harness4,serve4+share1+chk1+seal6,serve4+share1+chk1+seal4,serve8+share1+chk1,serve1+share1+chk1,serve1}
quiet "s2 the stream A/B ($ARMS)"
env $A HL_A22_AB_PASSES=4 HL_D55_AB_ALTERNATE=1 HL_A22_AB=$ARMS $C $K::a22::a22_stream_ab -- --ignored --exact --nocapture --test-threads=1 > $R/s2_ab.log 2>&1; say "s2 the stream A/B rc=$?"
seen "s2 the stream A/B"
grep -E "^A22-AB|panicked" $R/s2_ab.log | cut -c1-1500 > $O/s2_ab.log
python3 $O/stream_table.py $R/s2_ab.log serve4 serve4+share1 serve4+share1 serve4+share1+chk1 serve4 serve4+share1+chk1 serve4+share1+chk1 harness4 serve4 harness4 serve4+share1+chk1 serve4+share1+chk1+seal6 serve4+share1+chk1 serve4+share1+chk1+seal4 serve4+share1+chk1 serve8+share1+chk1 serve1 serve1+share1+chk1 > $O/s2_table.md 2>&1
cat $O/s2_table.md >> $P
grep -E "SUMMARY|STARTUP|cold request|panicked" $R/s2_ab.log | cut -c1-400 >> $P
say "all done"
