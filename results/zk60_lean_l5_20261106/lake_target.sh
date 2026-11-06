#!/bin/bash
# D63 step L5 Lean lane (2026-11-06): build named library modules with their dependencies (run through run_guarded.py,
# the zk60 resource guard, class cpu). usage: lake_target.sh ZK60Formal.ExecField [more modules]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a27bb5b90225b127d
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
"$LAKE" -d "$WT/formal" build "$@"
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
