#!/bin/bash
# D63 Lean lane L44 (2026-11-10), deliverable 5: run the Lean checker BlockHelperExportCheck.lean on the W16R2 rung
# corpus the test-only export wrote (src/lean_l44_export_tests.rs), with its negative controls, after confirming the
# corpus is the export's (sha256 against l44_export_sha256.txt). Run through run_guarded.py (class cpu).
# usage: exp_check.sh <corpus>
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-aef3f43a89ff2e7cf
OUT=$WT/results/zk60_lean_l44_20261110
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
C="$1"
start=$(date +%s)
ulimit -s 65520
echo "== corpus $C =="
shasum -a 256 "$C"
grep l44_w16r2_corpus.txt "$OUT/l44_export_sha256.txt"
echo "== source scan of the checker for the forbidden words =="
grep -nE 'sorry|axiom|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern\]|bv_decide|ofReduceBool' \
  "$WT/formal/ZK60Formal/BlockHelperExportCheck.lean" "$WT/ops/zkp-mvp/gpu-metal/hashline/src/lean_l44_export_tests.rs" \
  && echo "scan: FOUND" || echo "scan: none"
echo "== lean --run BlockHelperExportCheck.lean $C neg =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/BlockHelperExportCheck.lean" "$C" neg 2>&1 | head -n 300
r=${PIPESTATUS[0]}
echo "checker rc $r, $(( $(date +%s) - start )) s"
exit $r
