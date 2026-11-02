#!/bin/bash
# D60 review closure: one guarded test-binary run during development. Usage:
#   run_tests.sh <stem> <cpu|metal> <test-binary args...>
# Logs to logs/close/dev/<stem>.log (guard-appended), exit code in <stem>.guard.done.
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2e328baa581cb5b0
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/logs/close/dev
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
B=$(cat $R/results/zk60_d60_20261102/logs/close/dev.binary)
S=$1; ARM=$2; shift 2
export ZK60_GUARD_POLL_SECS=0.05
mkdir -p $L
rm -f $L/$S.log $L/$S.guard.done
if [ "$ARM" = metal ]; then E="env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F"; C=gpu; else E="env HL_R13_LOADER_FIXTURES=$F"; C=cpu; fi
$G --class $C --need-gib 8 --cap-gib 40 --label d60close-dev-$S --wait-secs 7200 --max-secs 1800 --log $L/$S.log --done $L/$S.guard.done -- $E $B "$@"
grep -h "test result\|FAILED\|panicked\|^D60 F\|END " $L/$S.log | cut -c1-400
