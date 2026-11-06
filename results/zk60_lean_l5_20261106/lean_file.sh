#!/bin/bash
# D63 step L5 Lean lane (2026-11-06): elaborate ONE file with `lake env lean` (run through run_guarded.py, the zk60
# resource guard, class cpu). usage: lean_file.sh <path to .lean> [more args for lean]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a27bb5b90225b127d
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
"$LAKE" -d "$WT/formal" env lean "$@"
rc=$?
echo "rc $rc, $(( $(date +%s) - start )) s"
exit $rc
