#!/bin/bash
# D63 Lean lane L17 (2026-11-07): while the files are written, build the named modules (iterate.sh) and run the three
# R13 agreement checkers once on their corpora (the reduced opening corpus), so that a checker's verdicts are seen in
# the same guarded job. Run through run_guarded.py (the zk60 resource guard, class cpu).
# usage: runchecks.sh <tag> "<modules>"
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1625b90fca168135
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l17_20261107
L=$WT/formal/ZK60Formal
S=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad
D=${L17_OUT:-$S/l17_out}
tag="$1"
ulimit -s 65520
start=$(date +%s)
/bin/bash "$OUT/iterate.sh" "$2"
irc=$?
echo "== CheckR13Slots =="
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Slots.lean" "$OUT/slots_corpus.txt" > "$OUT/${tag}_slots.log" 2>&1
echo "rc $? ($(( $(date +%s) - start )) s)"
grep -E "^  |CheckR13Slots|^FAILED|DEGREE GAP" "$OUT/${tag}_slots.log" | head -60
echo "== CheckR13Block =="
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Block.lean" "$OUT/block_corpus.txt" "$D/fork_frame.bin" \
  "$OUT/segment_corpus.txt" "$D/segment.bin" > "$OUT/${tag}_block.log" 2>&1
echo "rc $? ($(( $(date +%s) - start )) s)"
grep -E "^  |CheckR13Block|^FAILED" "$OUT/${tag}_block.log" | head -60
echo "== CheckR13Open (reduced corpus) =="
python3 -I "$OUT/mksmall.py" "$D/open_corpus.txt" "$S/l17_open_small.txt"
"$LAKE" -d "$WT/formal" env lean --run "$L/CheckR13Open.lean" "$S/l17_open_small.txt" > "$OUT/${tag}_open.log" 2>&1
echo "rc $? ($(( $(date +%s) - start )) s)"
grep -E "CheckR13Open|FAIL|^M |^PCS |^CHECK |^root" "$OUT/${tag}_open.log" | head -60
echo "total $(( $(date +%s) - start )) s, iterate rc $irc"
