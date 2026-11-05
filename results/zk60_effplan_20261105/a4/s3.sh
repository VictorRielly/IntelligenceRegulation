#!/bin/bash
# A4 stage 3, the BEFORE figures on this build: the D55 A/B harness with every witness weight product on the CPU
# (HL_GPU_WITNESS=0), one W16R2 8B T128 request sealed, and a 4-request stream. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a183d3e509aa57c38
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a4
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s3.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
env HL_GPU_WITNESS=0 HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s3_d55_cpu.log 2>&1; say "d55 A/B (CPU products) rc=$?"
grep -E "sealing pass|forks N6 pass|SEALED pass|^D55-AB SUMMARY|^D55-AB PIPE|A4 witness" $O/s3_d55_cpu.log >> $P
say "all done"
