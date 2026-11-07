#!/bin/bash
# D63 lane L10 (2026-11-07): the full Lean build, the axiom audit of every theorem of the L10 files, the source scan,
# the L6Check and L5Check regressions on their committed corpora, and this lane's checker (ExecOpeningCheck.lean) on
# the W16R2 rung corpus that export_corpus.sh writes (outside the repository; its sha256 is in corpus.sha256), as ONE
# guarded job. Run through run_guarded.py (the zk60 resource guard, class cpu). The corpus export (a cargo build and a
# rung proof) is its own guarded job, run first: export_corpus.sh.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9f0e162e79db6aa4
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l10_20261107
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
SCR=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
CORPUS=${LEAN_L10_CORPUS:-$SCR/l10/corpus_w16r2.txt}
FILES="$WT/formal/ZK60Formal/ExecOpeningCode.lean $WT/formal/ZK60Formal/BindingW16.lean $WT/formal/ZK60Formal/ExecOpening.lean $WT/formal/ZK60Formal/ExecOpeningM.lean $WT/formal/ZK60Formal/ExecOpeningFS.lean $WT/formal/ZK60Formal/ExecOpeningCheck.lean"
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$WT/formal/ZK60Formal" "$OUT/axioms_l10.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l10.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L10 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L10 library files =="
for m in ExecOpeningCode BindingW16 ExecOpening ExecOpeningM ExecOpeningFS; do
  grep -q "^import ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" && echo "imported: $m" || echo "MISSING: $m"
done
echo "== regression: L6Check on the committed L6 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L6Check.lean" "$O6/corpus.txt" > "$OUT/l6check_regression.log" 2>&1
c6=$?
tail -n 1 "$OUT/l6check_regression.log"
echo "L6Check rc $c6"
echo "== regression: L5Check on the committed L5 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/L5Check.lean" "$O5/corpus.txt" > "$OUT/l5check_regression.log" 2>&1
c5=$?
tail -n 1 "$OUT/l5check_regression.log"
echo "L5Check rc $c5"
g6=1
grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1
grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
echo "regression verdicts: L6 $g6, L5 $g5 (0 = the committed count with 0 failed)"
echo "== the L10 checker on the W16R2 rung corpus =="
ls -la "$CORPUS"
shasum -a 256 "$CORPUS"
start=$(date +%s)
"$LAKE" -d "$WT/formal" env lean --run "$WT/formal/ZK60Formal/ExecOpeningCheck.lean" "$CORPUS" > "$OUT/l10check.log" 2>&1
c10=$?
echo "L10Check rc $c10, $(( $(date +%s) - start )) s"
tail -n 1 "$OUT/l10check.log"
[ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $c6 -eq 0 ] && [ $c5 -eq 0 ] && [ $g6 -eq 0 ] && [ $g5 -eq 0 ] && [ $c10 -eq 0 ]
