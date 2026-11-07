#!/bin/bash
# D63 lane L10 (2026-11-07): one iteration as ONE guarded job (run_guarded.py, class cpu): the Lean files (stage2.sh,
# its plan file), the corpus export (export_corpus.sh: a cargo build and a W16R2 rung proof), then this lane's checker
# on the reduced corpus (mksmall.py: without the three openings whose every column is checked) and, when that passes,
# on the full corpus (runchk.py: RSS and wall-clock watchdog).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9f0e162e79db6aa4
OUT=$WT/results/zk60_lean_l10_20261107
SCR=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l10
start=$(date +%s)
/bin/bash "$OUT/stage2.sh"
echo "== corpus export =="
/bin/bash "$OUT/export_corpus.sh" 2>&1 | grep -E "LEAN-L10|test result|error|panicked|rc |corpus|^[0-9a-f]{64}" | head -n 40
python3 -I "$OUT/mksmall.py" "$SCR/corpus_w16r2.txt" "$SCR/corpus_small.txt"
python3 -I "$OUT/runchk.py" 8 1800 "$SCR/corpus_small.txt" "$OUT/l10check_small.log"
rs=$?
if [ $rs -eq 0 ]; then
  python3 -I "$OUT/runchk.py" 8 3600 "$SCR/corpus_w16r2.txt" "$OUT/l10check_full.log"
fi
echo "total $(( $(date +%s) - start )) s"
