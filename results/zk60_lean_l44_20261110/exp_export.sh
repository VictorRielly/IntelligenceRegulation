#!/bin/bash
# D63 Lean lane L44 (2026-11-10), deliverable 5: build hashline's tests and run the TEST-ONLY export
# (src/lean_l44_export_tests.rs: every slot's tables, claims and the plane offsets of a W16R2 and an R13 rung block
# receipt, proved by the production prove_core with w16r2_tests' seeded recipe and accepted by verify_core), then
# hashline's census tests s25_tests and hash_domain. The corpora land in $1 (outside the repository) and are copied
# here when under 1 MB; every file's sha256 is recorded. Run through run_guarded.py (class cpu).
# usage: exp_export.sh <out dir outside the repo> [census]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-aef3f43a89ff2e7cf
OUT=$WT/results/zk60_lean_l44_20261110
M=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
D="$1"
start=$(date +%s)
mkdir -p "$D"
env LEAN_L44_CORPUS="$D/l44_w16r2_corpus.txt" LEAN_L44_CORPUS_R13="$D/l44_r13_corpus.txt" \
  $C lean_l44_export -- --nocapture --test-threads 1
rc=$?
echo "export rc $rc, $(( $(date +%s) - start )) s"
( cd "$D" && shasum -a 256 l44_w16r2_corpus.txt l44_r13_corpus.txt ) > "$OUT/l44_export_sha256.txt"
cat "$OUT/l44_export_sha256.txt"
for f in l44_w16r2_corpus.txt l44_r13_corpus.txt; do
  if [ -f "$D/$f" ]; then
    sz=$(stat -f %z "$D/$f")
    echo "$f $sz bytes"
    if [ "$sz" -lt 1000000 ]; then cp "$D/$f" "$OUT/$f"; fi
  fi
done
crc=0
if [ "$2" = "census" ]; then
  for f in s25_tests hash_domain; do
    $C $f > "$OUT/exp_$f.log" 2>&1
    r=$?
    echo "hashline $f rc=$r"
    grep -E "^test result" "$OUT/exp_$f.log"
    [ $r -ne 0 ] && crc=$r
  done
fi
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ $crc -eq 0 ]
