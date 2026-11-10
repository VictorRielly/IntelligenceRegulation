#!/bin/bash
# D63 Lean lane L47 (2026-11-10), fork D: run the Lean checker BlockHostExportCheck.lean (lane L44's host public tables
# pubsW16, by value) on the host corpora the test-only export wrote (src/lean_l47_export_tests.rs,
# lean_l47_export_the_host_tables), each with its negative controls, after confirming each corpus is the export's
# (sha256 against l47_export_sha256.txt). Run through run_guarded.py (class cpu).
# usage: exp_check_host.sh <corpus> [<corpus> ...]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a12c7ac7215ab5406
OUT=$WT/results/zk60_lean_l47_20261110
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
start=$(date +%s)
ulimit -s 65520
echo "== source scan of the checker and the export for the forbidden words =="
grep -nE 'sorry|axiom|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern\]|bv_decide|ofReduceBool' \
  "$WT/formal/ZK60Formal/BlockHostExportCheck.lean" "$WT/ops/zkp-mvp/gpu-metal/hashline/src/lean_l47_export_tests.rs" \
  && echo "scan: FOUND" || echo "scan: none"
rc=0
for C in "$@"; do
  echo "== corpus $C =="
  shasum -a 256 "$C"
  grep "$(basename "$C")" "$OUT/l47_export_sha256.txt"
  echo "== lean --run BlockHostExportCheck.lean $C neg =="
  "$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/BlockHostExportCheck.lean" "$C" neg 2>&1 | head -n 300
  r=${PIPESTATUS[0]}
  echo "checker rc $r, $(( $(date +%s) - start )) s"
  [ $r -ne 0 ] && rc=$r
done
exit $rc
