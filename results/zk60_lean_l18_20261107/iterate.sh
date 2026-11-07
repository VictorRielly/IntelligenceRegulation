#!/bin/bash
# D63 Lean lane L18 (2026-11-07): one guarded iteration (run_guarded.py, class cpu): build the L18 library modules,
# elaborate the checker, run the test-only Rust framing export (unless the corpus exists, or SKIP_RUST=1), then the
# checker on the corpus. Each step's output goes to this job's log.
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7ec794744dd611b8
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
OUT=$WT/results/zk60_lean_l18_20261107
L=$WT/formal/ZK60Formal
start=$(date +%s)
echo "== lake build of the L18 modules =="
"$LAKE" -d "$WT/formal" build ZK60Formal.ProtocolClassifyFS ZK60Formal.AssembleClassify ZK60Formal.ProtocolClassifyR13 ZK60Formal.ProtocolClassifyCount 2>&1 \
  | grep -v '^✔\|^⣿\|Replayed\|Built' | head -n 400
brc=${PIPESTATUS[0]}
echo "build rc $brc ($(( $(date +%s) - start )) s)"
crc=1
if [ $brc -eq 0 ]; then
  echo "== lean the checker =="
  "$LAKE" -d "$WT/formal" env lean "$L/ProtocolClassifyCheck.lean" 2>&1 | head -n 100
  crc=${PIPESTATUS[0]}
  echo "checker elaboration rc $crc"
fi
rrc=0
if [ "${SKIP_RUST:-0}" != "1" ] && [ ! -s "$OUT/corpus.txt" ]; then
  echo "== the Rust framing export =="
  /bin/bash "$OUT/export_corpus.sh" "$OUT/corpus.txt" > "$OUT/rust.log" 2>&1
  rrc=$?
  grep -E "^error|^warning: unused|LEAN-L18|test result|^test |rc " "$OUT/rust.log" | head -n 80
  echo "rust rc $rrc"
fi
if [ $crc -eq 0 ] && [ -s "$OUT/corpus.txt" ]; then
  echo "== the checker on the corpus =="
  "$LAKE" -d "$WT/formal" env lean --run "$L/ProtocolClassifyCheck.lean" "$OUT/corpus.txt" 2>&1 | tail -n 40
fi
echo "iteration done, $(( $(date +%s) - start )) s"
