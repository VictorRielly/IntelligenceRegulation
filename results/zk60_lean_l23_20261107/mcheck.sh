#!/bin/bash
# D63 lane L23 (2026-11-07): the agreement check of M's functionals (weights and values) against the real W16R2 rung
# receipt (CoverW16MCheck.lean): L9's corpus and frame, L10's corpus (outside the repository; its sha256 is
# results/zk60_lean_l10_20261107/corpus.sha256, checked here first). Run inside a guarded job (iter.sh / check_l23.sh).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad9d55551b2c8d9df
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
export L23_L9_CORPUS=$WT/results/zk60_lean_l9_20261107/corpus.txt
export L23_L9_FRAME=$S/l9merge/fork_frame.bin
export L23_L10_CORPUS=$S/l10/corpus_w16r2.txt
want=$(head -c 64 "$WT/results/zk60_lean_l10_20261107/corpus.sha256")
have=$(shasum -a 256 "$L23_L10_CORPUS" | head -c 64)
if [ "$want" != "$have" ]; then echo "L10 corpus sha256 mismatch: $have"; exit 1; fi
echo "L10 corpus sha256 $have (as recorded)"
ulimit -s 65520
"$LAKE" -d "$WT/formal" build ZK60Formal.ExecBlockCheck ZK60Formal.CoverW16Unmask 2>&1 | tail -n 1
"$LAKE" -d "$WT/formal" env lean "$WT/formal/ZK60Formal/CoverW16MCheck.lean"
