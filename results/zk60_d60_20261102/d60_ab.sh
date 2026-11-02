#!/bin/bash
# D60 (2026-11-02) A/B on ONE request, on one binary: the REGISTERED base (R13_8B_T128_H24's D12a run profile,
# serial) against its REGISTERED D55 profile at N = 6 fork workers, a 32-block Llama-3-8B T128 run at the true
# geometry (ONE synthetic diagonal-weight block at every layer: M10's recipe, as D55's A/B), warm, BOTH ORDERS
# (HL_D55_ORDER=both: serial first in even passes, forks first in odd ones) after one cold serial pass,
# HL_GPU=1, HL_PB_ORACLE=0, never HL_METAL_TIMING. The first warm pass of each arm is verified. Guarded (gpu
# class), alone. Usage: d60_ab.sh <test binary> [passes, default 4]
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a13712d1ade4dcee1
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/logs/ab
B=$1
PASSES=${2:-4}
mkdir -p $L
export ZK60_GUARD_POLL_SECS=0.05
$G --class gpu --need-gib 60 --cap-gib 160 --label d60-ab-8b --wait-secs 7200 --max-secs 5400 --log $L/ab.log --done $L/ab.done -- \
  env -u HL_METAL_TIMING HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_D55_PROFILE=R13_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_D55_PASSES=$PASSES HL_D55_ORDER=both \
  $B --ignored --exact private_block::run::fork::tests::d55_ab_one_request_serial_against_forks --nocapture --test-threads=1
grep -h "D55-AB\|test result\|FAILED\|panicked" $L/ab.log | cut -c1-400
grep -q "test result: ok. 1 passed" $L/ab.log
