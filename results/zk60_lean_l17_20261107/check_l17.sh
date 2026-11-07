#!/bin/bash
# D63 Lean lane L17 (2026-11-07, the R13 block): the full Lean build, the axiom audit of every theorem of the L17
# library files, the source scan, the root imports, the regressions (L6Check, L5Check, the fixture L1 check with
# check_l15merge.sh's / check_l8merge.sh's arguments, L11Check on its committed corpus), the three R13 agreement checks
# (CheckR13Block on the R13 rung's fork frame and the real D12a segment, CheckR13Slots, CheckR13Open on the reduced and
# on the full opening corpus) with their negative controls, and hashline's R19b / s25 censuses, as ONE guarded job.
# Run through run_guarded.py (the zk60 resource guard, class cpu). The corpora come first from export_corpus.sh (its
# own guarded job); the large ones stay OUTSIDE the repository (sha256 in large_files.sha256).
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1625b90fca168135
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l17_20261107
O6=$WT/results/zk60_lean_l6_20261106
O5=$WT/results/zk60_lean_l5_20261106
O11=$WT/results/zk60_lean_l11_20261107
R1=$WT/results/zk60_lean_l1l2_20261106
V=$WT/ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors
L=$WT/formal/ZK60Formal
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
D=${L17_OUT:-$S/l17_out}
LIB="ExecBlockR13 SlotR13 OpeningR13 LayoutR13 ShapeR13"
FILES="$L/ExecBlockR13.lean $L/SlotR13.lean $L/OpeningR13.lean $L/LayoutR13.lean $L/ShapeR13.lean $L/CheckR13Block.lean $L/CheckR13Slots.lean $L/CheckR13Open.lean"
ulimit -s 65520
start=$(date +%s)
echo "== the large files (outside the repository) against their committed sha256 =="
( cd "$D" && shasum -a 256 -c "$OUT/large_files.sha256" )
crl=$?
echo "== lake build (full) =="
"$LAKE" -d "$WT/formal" build > "$OUT/full.log" 2>&1
rc=$?
echo "lake build rc $rc"
tail -n 3 "$OUT/full.log"
echo "warnings: $(grep -c 'warning' "$OUT/full.log")"
echo "errors: $(grep -c 'error' "$OUT/full.log")"
echo "sorry: $(grep -c 'sorry' "$OUT/full.log")"
echo "== axiom audit =="
python3 -I "$OUT/gen_axioms.py" "$L" "$OUT/axioms_l17.lean"
"$LAKE" -d "$WT/formal" env lean "$OUT/axioms_l17.lean" > "$OUT/axioms.log" 2>&1
arc=$?
echo "axioms rc $arc"
echo "declarations audited: $(grep -c 'depends on axioms\|does not depend on any axioms' "$OUT/axioms.log")"
echo "sorryAx: $(grep -c 'sorryAx' "$OUT/axioms.log")"
echo "ofReduceBool: $(grep -c 'ofReduceBool' "$OUT/axioms.log")"
echo "other axioms: $(grep 'depends on axioms' "$OUT/axioms.log" | grep -v -E "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]" | wc -l | tr -d ' ')"
grep -oE "axioms: \[[^]]*\]" "$OUT/axioms.log" | sort | uniq -c
echo "== source scan of the L17 files =="
grep -n -E '\bsorry\b|\baxiom\b|native_decide|admit|maxRecDepth|maxHeartbeats|implemented_by|@\[extern|\bextern\b|bv_decide|ofReduceBool' $FILES || echo "none"
echo "== the library root imports the L17 library files, not the checkers =="
for m in $LIB; do grep -n "ZK60Formal.$m\$" "$WT/formal/ZK60Formal.lean" || echo "MISSING $m"; done
grep -n "ZK60Formal.CheckR13" "$WT/formal/ZK60Formal.lean" && echo "UNEXPECTED: a checker is imported" || echo "the checkers (main) are not imported"
echo "== regression: L6Check on the committed L6 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L6Check.lean" "$O6/corpus.txt" > "$OUT/l6check_regression.log" 2>&1
c6=$?
tail -n 1 "$OUT/l6check_regression.log"
echo "== regression: L5Check on the committed L5 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L5Check.lean" "$O5/corpus.txt" > "$OUT/l5check_regression.log" 2>&1
c5=$?
tail -n 1 "$OUT/l5check_regression.log"
echo "== regression: the fixture L1 check =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L1Check.lean" "$V/block_fixture_t32.tsv" "$V/block_trace_low_h24_t32.tsv" \
  "$V/block_trace_low_t32.tsv" "$R1/rust_fixture_trace.tsv" "$V/r13_requant_vectors.tsv" > "$OUT/l1check_regression.log" 2>&1
c1=$?
tail -n 1 "$OUT/l1check_regression.log"
echo "== regression: L11Check on the committed L11 corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/L11Check.lean" "$O11/corpus.txt" > "$OUT/l11check_regression.log" 2>&1
c11=$?
tail -n 1 "$OUT/l11check_regression.log"
echo "== CheckR13Slots on the R13 rung's slots corpus =="
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Slots.lean" "$OUT/slots_corpus.txt" > "$OUT/slots_check.log" 2>&1
cs=$?
grep -E "^  |CheckR13Slots|^FAILED|DEGREE GAP" "$OUT/slots_check.log"
echo "== CheckR13Slots negative control (seven changes) =="
python3 -I "$OUT/mutate_slots.py" "$OUT/slots_corpus.txt" "$S/l17_slots_neg.txt"
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Slots.lean" "$S/l17_slots_neg.txt" > "$OUT/slots_negative.log" 2>&1
grep -E "^FAILED|CheckR13Slots" "$OUT/slots_negative.log"
echo "== CheckR13Block on the R13 rung's fork frame and the real D12a segment =="
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Block.lean" "$OUT/block_corpus.txt" "$D/fork_frame.bin" \
  "$OUT/segment_corpus.txt" "$D/segment.bin" > "$OUT/block_check.log" 2>&1
cb=$?
grep -E "^  |CheckR13Block|^FAILED" "$OUT/block_check.log"
echo "== CheckR13Block negative control (six block changes, two segment changes) =="
python3 -I "$OUT/mutate_block.py" "$OUT/block_corpus.txt" "$S/l17_block_neg.txt" "$OUT/segment_corpus.txt" "$S/l17_segment_neg.txt"
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Block.lean" "$S/l17_block_neg.txt" "$D/fork_frame.bin" \
  "$S/l17_segment_neg.txt" "$D/segment.bin" > "$OUT/block_negative.log" 2>&1
grep -E "^FAILED|CheckR13Block" "$OUT/block_negative.log"
echo "== CheckR13Open on the reduced opening corpus, then its negative control, then the full corpus =="
python3 -I "$OUT/mksmall.py" "$D/open_corpus.txt" "$S/l17_open_small.txt"
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Open.lean" "$S/l17_open_small.txt" > "$OUT/open_check_small.log" 2>&1
cos=$?
grep -E "CheckR13Open|FAIL" "$OUT/open_check_small.log"
python3 -I "$OUT/negctl_open.py" "$S/l17_open_small.txt" "$S/l17_open_neg.txt"
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Open.lean" "$S/l17_open_neg.txt" > "$OUT/open_negative.log" 2>&1
grep -E "CheckR13Open|^FAIL" "$OUT/open_negative.log"
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Open.lean" "$D/open_corpus.txt" > "$OUT/open_check_full.log" 2>&1
cof=$?
grep -E "CheckR13Open|FAIL|^M |^PCS |^CHECK |^root" "$OUT/open_check_full.log"
echo "== hashline's R19b file census and the s25 tests (TEST_ONLY_FILES) =="
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" \
  --lib r19b > "$OUT/r19b.log" 2>&1
cr=$?
grep -E "^test |test result" "$OUT/r19b.log"
/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" \
  --lib s25_tests > "$OUT/s25.log" 2>&1
c25=$?
grep -E "test result" "$OUT/s25.log"
g6=1; grep -q '^L6Check: 1206 checks, 0 failed$' "$OUT/l6check_regression.log" && g6=0
g5=1; grep -q '^L5Check: 5553 checks, 0 failed$' "$OUT/l5check_regression.log" && g5=0
g1=1; grep -q '101956 checks, 0 failed' "$OUT/l1check_regression.log" && g1=0
g11=1; grep -q '404 checks, 0 failed' "$OUT/l11check_regression.log" && g11=0
ns=1; grep -q 'checks, 7 failed$' "$OUT/slots_negative.log" && ns=0
nb=1; grep -q 'checks, 8 failed$' "$OUT/block_negative.log" && nb=0
no=1; grep -q 'checks, 8 failed$' "$OUT/open_negative.log" && no=0
echo "verdicts: large files $crl, build $rc, axioms $arc, L6 $c6/$g6, L5 $c5/$g5, L1 $c1/$g1, L11 $c11/$g11, slots $cs/neg $ns, block $cb/neg $nb, open small $cos/neg $no/full $cof, r19b $cr, s25 $c25 (0 = as required); $(( $(date +%s) - start )) s"
[ $crl -eq 0 ] && [ $rc -eq 0 ] && [ $arc -eq 0 ] && [ $c6 -eq 0 ] && [ $g6 -eq 0 ] && [ $c5 -eq 0 ] && [ $g5 -eq 0 ] \
  && [ $c1 -eq 0 ] && [ $g1 -eq 0 ] && [ $c11 -eq 0 ] && [ $g11 -eq 0 ] && [ $cs -eq 0 ] && [ $ns -eq 0 ] && [ $cb -eq 0 ] \
  && [ $nb -eq 0 ] && [ $cos -eq 0 ] && [ $no -eq 0 ] && [ $cof -eq 0 ] && [ $cr -eq 0 ] && [ $c25 -eq 0 ]
