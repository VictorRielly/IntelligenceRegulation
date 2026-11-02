#!/bin/bash
# D59 condition (5) privacy re-check (2026-11-02): one guarded run of the test binary this worktree built
# (binary.path). Usage: run.sh <tag> <cpu|gpu> [VAR=value ...] -- <test binary arguments>
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_20261101/logs/privacy_recheck
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
TAG=$1; CLASS=$2; shift 2
ENVS=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do ENVS+=("$1"); shift; done
[ "${1:-}" = "--" ] && shift
B=$(cat $L/binary.path)
rm -f $L/$TAG.log $L/$TAG.guard.done
echo "binary $(shasum -a 256 $B | cut -c1-16) $B" > $L/$TAG.cmd
echo "env ${ENVS[*]+${ENVS[*]}} HL_R13_LOADER_FIXTURES=$F" >> $L/$TAG.cmd
echo "args $*" >> $L/$TAG.cmd
NEED=8; CAP=40; [ "$CLASS" = gpu ] && { NEED=60; CAP=160; }
$G --class $CLASS --need-gib $NEED --cap-gib $CAP --label pr-$TAG --wait-secs 7200 --max-secs 3600 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  env ${ENVS[@]+"${ENVS[@]}"} HL_R13_LOADER_FIXTURES=$F $B "$@"
rc=$?
grep -h "W16-PG \|D55-PG\|test result\|FAILED\|panicked" $L/$TAG.log | cut -c1-600
exit $rc
