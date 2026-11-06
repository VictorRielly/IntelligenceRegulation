#!/bin/bash
# A22 stage 2: THE A/B, on the tree with A21 merged (perf 2eb26c7f; no A/B ran before the merge). Production's server stream (`stack-serve`'s code path, `serve_stream` on the resident model) on
# the D55 harness's synthetic W16R2 8B T128 32-block stack, in process, N = 6, the witness budget the Mac's default
# (32 GiB): one request (serve1), streams of 4 and 8 (serve4, serve8), the harness's stream of 4 on the same tree
# (harness4, H124d), and the two forms off by default in a stream of 4 (serve4+dig1: the digests ahead; serve4+ahead16:
# A13's window at 16). 4 passes, the arm order reversed in odd passes. Then the original harness test's stream once,
# for reference. Each timing step waits for a quiet GPU (no RUNNING ds4-bench, matched by process name) and records
# whether one ran at its end. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a75997b3d20d4ca57
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a22
R=$O/raw
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
K=private_block::run::fork::tests
D=$K::d55_ab_one_request_serial_against_forks
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
A="HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32"
ARMS=${A22_ARMS:-serve1,serve4,harness4,serve8,serve4+dig1,serve4+ahead16}
quiet "s2 the stream A/B ($ARMS)"
env $A HL_A22_AB_PASSES=4 HL_D55_AB_ALTERNATE=1 HL_A22_AB=$ARMS $C $K::a22::a22_stream_ab -- --ignored --exact --nocapture --test-threads=1 > $R/s2_ab.log 2>&1; say "s2 the stream A/B rc=$?"
seen "s2 the stream A/B"
grep -E "^A22-AB|panicked" $R/s2_ab.log | cut -c1-1400 > $O/s2_ab.log
python3 $O/stream_table.py $R/s2_ab.log serve4 harness4 serve4 serve4+dig1 serve4 serve4+ahead16 serve4 serve8 > $O/s2_table.md 2>&1
cat $O/s2_table.md >> $P
grep -E "SUMMARY|STARTUP|cold request|panicked" $R/s2_ab.log | cut -c1-400 >> $P
quiet "s2 the harness's own stream"
env $A HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 HL_D55_WORKERS=6 $C $D -- --ignored --exact --nocapture --test-threads=1 > $R/s2_d55.log 2>&1; say "s2 the harness's own stream rc=$?"
seen "s2 the harness's own stream"
grep -E "sealing pass|verified|^D55-AB SUMMARY|^D55-AB PIPE|A15 PIPE-SEAL" $R/s2_d55.log | cut -c1-300 > $O/s2_d55.log
grep -E "^D55-AB SUMMARY|^D55-AB PIPE" $R/s2_d55.log | cut -c1-300 >> $P
say "all done"
