#!/bin/bash
# D63 Lean lane L17 (2026-11-07): build the named modules (iterate.sh); only if they build, run the whole check
# (check_l17.sh), in ONE guarded job (the heavy lock is shared with other lanes). Run through run_guarded.py.
# usage: iter_then_check.sh "<modules>"
OUT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1625b90fca168135/results/zk60_lean_l17_20261107
/bin/bash "$OUT/iterate.sh" "$1" || { echo "ITERATE FAILED: the check was not run"; exit 1; }
echo "== check_l17.sh =="
/bin/bash "$OUT/check_l17.sh"
