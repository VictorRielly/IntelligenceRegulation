#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02): one guarded run of the test binary this worktree built (logs/binary.path).
# Usage: run.sh <tag> <cpu|gpu> <need GiB> <cap GiB> [VAR=value ...] -- <test binary arguments>
# (privacy_gate_r26/run.sh with this worktree's paths.)  HL_GPU is never set here: the bundles are CPU-made.
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/privacy_gate_tsbases/logs
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
TAG=$1; CLASS=$2; NEED=$3; CAP=$4; shift 4
ENVS=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do ENVS+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
B=$(cat $L/binary.path)
rm -f $L/$TAG.log $L/$TAG.guard.done
echo "binary $(shasum -a 256 $B | cut -c1-16) $B" > $L/$TAG.cmd
echo "env ${ENVS[*]+${ENVS[*]}} HL_R13_LOADER_FIXTURES=$F (HL_GPU unset)" >> $L/$TAG.cmd
echo "args $*" >> $L/$TAG.cmd
$G --class $CLASS --need-gib $NEED --cap-gib $CAP --label tsb-$TAG --wait-secs 7200 --max-secs 7200 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  env -u HL_GPU ${ENVS[@]+"${ENVS[@]}"} HL_R13_LOADER_FIXTURES=$F $B "$@"
rc=$?
grep -h "D60-PG\|test result\|FAILED\|panicked\|zk60-guard.*END" $L/$TAG.log | cut -c1-600
exit $rc
