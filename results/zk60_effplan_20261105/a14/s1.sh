#!/bin/bash
# A14 stage 1, THE PROFILE (diagnostic, no code change): the tree at perf 76e9b280 (A11 + A12 + A8). Build; the
# D55 harness at N = 6 with the phase clock in every fork and the GPU timeline (`phases`, 2 passes, proof only);
# then a second process with a sampler window of 3 proof-only fork calls on the default (/usr/bin/sample, 2 ms),
# as A11 stage 6 did. The raw call graph stays in raw/ (not committed). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9838ab349101784d
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a14
A11=$W/results/zk60_effplan_20261105/a11
HS=$O/raw/handshake
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
mkdir -p $O/raw
$C --no-run > $O/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  grep -E "^error" -A 12 $O/s1_build.log | head -80 >> $P
  say "all done (build failed)"
  exit 1
fi
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_TIMELINE=1 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=2 HL_D55_GPU_AB=phases $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_d55_phases.log 2>&1
say "d55 phases + timeline rc=$?"
grep -E "^D55-AB GPU-AB|^D55-AB A11|^D55-AB A12|^D55-AB SUMMARY|busy|panicked" $O/raw/s1_d55_phases.log | cut -c1-300 >> $P
mkdir -p $HS
rm -f $HS/go.* $HS/next.*
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_A11_SAMPLE=3 HL_A11_SAMPLE_DIR=$HS $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/raw/s1_d55_sample.log 2>&1 &
TP=$!
PID=""
for i in $(seq 1 3600); do
  PID=$(grep -o "A11-SAMPLE READY N6 pid [0-9]*" $O/raw/s1_d55_sample.log 2>/dev/null | awk '{print $5}')
  [ -n "$PID" ] && break
  kill -0 $TP 2>/dev/null || break
  sleep 1
done
say "N6 ready pid ${PID:-none}"
if [ -n "$PID" ]; then
  /usr/bin/sample "$PID" 16 2 -mayDie -file $O/raw/s1_sample_N6.txt > $O/raw/s1_sample_N6.out 2>&1 &
  SP=$!
  sleep 2
  touch $HS/go.N6
  say "N6 go"
  wait $SP
  say "N6 sample rc=$?"
  touch $HS/next.N6
fi
wait $TP
say "d55 sample window rc=$?"
grep -E "^D55-AB A11 USAGE|^A11-SAMPLE|^D55-AB SUMMARY" $O/raw/s1_d55_sample.log | cut -c1-330 >> $P
if [ -f $O/raw/s1_sample_N6.txt ]; then
  python3 $A11/sample_summary.py $O/raw/s1_sample_N6.txt --interval-ms 2 --top 40 --label "a14 s1 N=6, the tree at 76e9b280" > $O/s1_sample_N6.summary.txt 2>&1
  say "summary rc=$?"
fi
say "all done"
