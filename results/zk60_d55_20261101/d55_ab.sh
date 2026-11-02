#!/bin/bash
# D55 A/B on ONE request (2026-11-01): D12a serial against the fork run, W16 8B T128 at its true geometry,
# synthetic diagonal weights, one process (Metal concurrency must be measured in one process: M10),
# HL_PB_ORACLE=0, HL_METAL_TIMING unset, warm passes. Guarded (gpu class), one leaf.
# Usage: d55_ab.sh <binary> <tag> [L] [workers] [passes] [need-gib] [cap-gib]
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-af0bd172154265b70
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
B=$1
TAG=$2
NL=${3:-32}
NW=${4:-1,2,4,6}
NP=${5:-2}
NEED=${6:-80}
CAP=${7:-180}
L=$R/results/zk60_d55_20261101/logs/ab_$TAG
mkdir -p $L
echo "== ab $TAG L=$NL workers=$NW passes=$NP $(date +%H:%M:%S)"
$G --class gpu --need-gib $NEED --cap-gib $CAP --label d55-ab-$TAG --wait-secs 7200 --max-secs 5400 --log $L/ab.log --done $L/ab.done --result-json $L/ab.guard.json -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_D55_L=$NL HL_D55_WORKERS=$NW HL_D55_PASSES=$NP \
  $B --ignored --exact private_block::run::fork::tests::d55_ab_one_request_serial_against_forks --nocapture --test-threads=1
rc=$?
grep -h "D55-AB\|test result\|FAILED\|panicked" $L/ab.log | cut -c1-400
echo "== ab $TAG rc=$rc $(date +%H:%M:%S)"
exit $rc
