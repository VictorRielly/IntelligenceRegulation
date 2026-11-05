#!/bin/bash
# A11 stage 6, THE PROFILE AFTER (diagnostic): the final tree's build; the D55 harness at N = 6 with the phase
# clock in every fork, `global+phases` against `fpauto+phases` (2 passes, alternating), then a sampler window of 3
# proof-only fork calls on the new default (/usr/bin/sample, 2 ms). One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ae8b54c76e79d7cfe
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a11
HS=$O/handshake
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s6.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s6_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
mkdir -p $HS
rm -f $HS/go.* $HS/next.*
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=1 HL_D55_AB_PASSES=2 HL_D55_AB_ALTERNATE=1 HL_D55_GPU_AB=global+phases,fpauto+phases HL_A11_SAMPLE=3 HL_A11_SAMPLE_DIR=$HS $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s6_d55.log 2>&1 &
TP=$!
PID=""
for i in $(seq 1 3600); do
  PID=$(grep -o "A11-SAMPLE READY N6 pid [0-9]*" $O/s6_d55.log 2>/dev/null | awk '{print $5}')
  [ -n "$PID" ] && break
  kill -0 $TP 2>/dev/null || break
  sleep 1
done
say "N6 ready pid ${PID:-none}"
if [ -n "$PID" ]; then
  /usr/bin/sample "$PID" 12 2 -mayDie -file $O/s6_sample_N6.txt > $O/s6_sample_N6.out 2>&1 &
  SP=$!
  sleep 2
  touch $HS/go.N6
  say "N6 go"
  wait $SP
  say "N6 sample rc=$?"
  touch $HS/next.N6
fi
wait $TP
say "d55 profile after rc=$?"
grep -E "^D55-AB A11 USAGE|^A11-SAMPLE|^D55-AB SUMMARY" $O/s6_d55.log | cut -c1-330 >> $P
if [ -f $O/s6_sample_N6.txt ]; then
  python3 $O/sample_summary.py $O/s6_sample_N6.txt --interval-ms 2 --top 30 --label "s6 N=6, per-fork pools (the A11 default)" > $O/s6_sample_N6.summary.txt 2>&1
  python3 $O/sample_nesting.py $O/s6_sample_N6.txt > $O/s6_nesting_N6.txt 2>&1
  say "summary rc=$?"
fi
say "all done"
