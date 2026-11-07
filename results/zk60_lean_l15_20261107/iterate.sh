#!/bin/bash
# D63 Lean lane L15 (2026-11-07): one iteration as ONE guarded job: the agreement check on the corpus and its negative
# control (the checker's library is already built), then the L15 modules; when they build, check_l15.sh (the full
# gate) with its output in check.log. Run through run_guarded.py (class cpu).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a656d67cb6858d77e
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l15_20261107
L=$WT/formal/ZK60Formal
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/l15
mkdir -p "$S"
start=$(date +%s)
echo "== StageCheckOutC on the corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/StageCheckOutC.lean" "$OUT/corpus.txt" > "$S/l15_check_iter.log" 2>&1
echo "rc $?"
tail -n 60 "$S/l15_check_iter.log"
echo "== negative control =="
python3 -I "$OUT/mutate_corpus.py" "$OUT/corpus.txt" "$S/l15_mutated.txt"
"$LAKE" -d "$WT/formal" env lean --run "$L/StageCheckOutC.lean" "$S/l15_mutated.txt" > "$S/l15_neg_iter.log" 2>&1
echo "rc $?"
tail -n 60 "$S/l15_neg_iter.log"
echo "== lake build of the L15 modules =="
"$LAKE" -d "$WT/formal" build ZK60Formal.StageOutCWhole ZK60Formal.StageFS ZK60Formal.StageCheckDefs \
  ZK60Formal.StageOutWhole ZK60Formal.StageCheckValid 2>&1 | grep -v '^✔\|^⣿\|Replayed\|Built\|^trace:' | head -n 200
brc=${PIPESTATUS[0]}
echo "build rc $brc, $(( $(date +%s) - start )) s"
if [ $brc -eq 0 ]; then
  /bin/bash "$OUT/check_l15.sh" > "$OUT/check.log" 2>&1
  crc=$?
  echo "check_l15 rc $crc"
  tail -n 80 "$OUT/check.log"
  exit $crc
fi
exit $brc
