#!/bin/bash
# A11 stage 1, THE PROFILE (no code change to the prover's path; the harness only): build; then the D55
# harness on W16R2 8B T128, 32 blocks, at N = 1 and N = 6:
#  - one warm pass each (the first verified);
#  - two in-process A/B arms with the phase clock in every fork (shared queue; spin wait, then block wait):
#    per-phase walls summed over the forks, the process's usage (user/sys, faults, context switches) and
#    each fork worker's own thread CPU;
#  - then the sampling window: 3 proof-only fork calls back to back at N = 1 and again at N = 6, each
#    window recorded by /usr/bin/sample (2 ms) between two file handshakes.
# One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ae8b54c76e79d7cfe
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a11
HS=$O/handshake
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
$C --no-run > $O/s1_build.log 2>&1
rc=$?
say "build rc=$rc"
if [ $rc -ne 0 ]; then
  say "all done (build failed)"
  exit 1
fi
mkdir -p $HS
rm -f $HS/go.* $HS/next.*
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=1,6 HL_D55_PASSES=1 HL_D55_AB_PASSES=1 HL_D55_TIMELINE=1 HL_D55_GPU_AB=shared+spin+phases,shared+block+phases HL_A11_SAMPLE=3 HL_A11_SAMPLE_DIR=$HS $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s1_d55.log 2>&1 &
TP=$!
for N in 1 6; do
  if [ $N = 1 ]; then S=26; else S=13; fi
  PID=""
  for i in $(seq 1 3600); do
    PID=$(grep -o "A11-SAMPLE READY N$N pid [0-9]*" $O/s1_d55.log 2>/dev/null | awk '{print $5}')
    [ -n "$PID" ] && break
    kill -0 $TP 2>/dev/null || break
    sleep 1
  done
  say "N$N ready pid ${PID:-none}"
  [ -z "$PID" ] && break
  /usr/bin/sample "$PID" $S 2 -mayDie -file $O/s1_sample_N$N.txt > $O/s1_sample_N$N.out 2>&1 &
  SP=$!
  sleep 2
  touch $HS/go.N$N
  say "N$N go"
  wait $SP
  say "N$N sample rc=$?"
  touch $HS/next.N$N
done
wait $TP
say "d55 profile rc=$?"
grep -E "^D55-AB A11 USAGE|^A11-SAMPLE|^D55-AB A7 CPU|^D55-AB SUMMARY" $O/s1_d55.log >> $P
for N in 1 6; do
  if [ -f $O/s1_sample_N$N.txt ]; then
    python3 $O/sample_summary.py $O/s1_sample_N$N.txt --interval-ms 2 --top 30 --label "s1 N=$N" > $O/s1_sample_N$N.summary.txt 2>&1
    say "N$N summary rc=$?"
  fi
done
say "all done"
