#!/bin/bash
# A4 stage 4, the AFTER figures: the same D55 A/B harness with the witness weight products on the Metal GPU (the
# default under HL_GPU=1), one W16R2 8B T128 request sealed, and a 4-request stream. One guarded job, class gpu.
set -u
W=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a183d3e509aa57c38
H=$W/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
O=$W/results/zk60_effplan_20261105/a4
C="/opt/homebrew/bin/cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib"
D=private_block::run::fork::tests::d55_ab_one_request_serial_against_forks
P=$O/s4.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say start
env HL_GPU=1 HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1 HL_D55_PIPE=4 $C $D -- --ignored --exact --nocapture --test-threads=1 > $O/s4_d55_gpu.log 2>&1; say "d55 A/B (device products) rc=$?"
grep -E "sealing pass|forks N6 pass|SEALED pass|^D55-AB SUMMARY|^D55-AB PIPE|A4 witness" $O/s4_d55_gpu.log >> $P
say "all done"
