#!/bin/bash
# D63 Lean lane L17 (2026-11-07): build hashline's tests and run the TEST-ONLY R13 corpus export
# (private_block/lean_l17_export_tests.rs: a real R13 rung block core proved by the production prove_core and accepted by
# verify_core, exported in L9's, L10's and L11's formats; a real one-stage R13 D12a run on the public loader fixture
# r13-h24-wide; the Shieldstral T128 R13 shape's facts). Then the small corpora are copied into this directory and the
# large files' sha256 recorded (the large files stay OUTSIDE the repository). Optionally (second argument "lake") the
# full Lean build, to warm this worktree's build. Run through run_guarded.py (class cpu).
# usage: export_corpus.sh <out dir outside the repo> [lake]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a1625b90fca168135
OUT=$WT/results/zk60_lean_l17_20261107
LAKE=/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake
D="$1"
start=$(date +%s)
mkdir -p "$D"
env L17_OUT="$D" HL_R13_LOADER_FIXTURES="$WT/results/zk60_1b_native_20261017/r13/loader-fixtures" \
  /opt/homebrew/bin/cargo test --release --offline --locked -j 2 \
  --manifest-path "$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml" --lib lean_l17_export -- --nocapture --test-threads 1
rc=$?
echo "export rc $rc, $(( $(date +%s) - start )) s"
for f in block_corpus.txt slots_corpus.txt segment_corpus.txt shape_corpus.txt; do
  [ -f "$D/$f" ] && cp "$D/$f" "$OUT/$f" && wc -c "$OUT/$f"
done
( cd "$D" && shasum -a 256 fork_frame.bin segment.bin open_corpus.txt 2>/dev/null ) > "$OUT/large_files.sha256"
cat "$OUT/large_files.sha256"
ls -l "$D"
lrc=0
if [ "$2" = "lake" ]; then
  echo "== lake build (full, warming the worktree) =="
  "$LAKE" -d "$WT/formal" build > "$OUT/warm.log" 2>&1
  lrc=$?
  echo "lake build rc $lrc"
  tail -n 3 "$OUT/warm.log"
fi
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ $lrc -eq 0 ]
