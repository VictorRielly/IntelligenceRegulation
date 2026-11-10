#!/bin/bash
# D63 Lean lane L47 (2026-11-10), fork D: build hashline's tests and run the TEST-ONLY export
# (src/lean_l47_export_tests.rs: the lookup side's public tables of a W16R2 rung block receipt, proved by the production
# prove_core with w16r2_tests' seeded recipe and accepted by verify_core, with the public data they are built from, the
# verifier's slot kinds and its LogUp sum claim), then hashline's census tests s25_tests and hash_domain. The FULL corpus
# lands in $1 (outside the repository); the SHORT corpus (no full tables) is copied here when under 1 MB; every file's
# sha256 is recorded. A copy of results/zk60_lean_l44_20261110/exp_export.sh. Run through run_guarded.py (class cpu).
# usage: exp_export.sh <out dir outside the repo> [census]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a12c7ac7215ab5406
OUT=$WT/results/zk60_lean_l47_20261110
M=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
D="$1"
start=$(date +%s)
mkdir -p "$D"
env LEAN_L47_CORPUS="$D/l47_w16r2_full.txt" LEAN_L47_CORPUS_SHORT="$D/l47_w16r2_short.txt" \
  $C lean_l47_export -- --nocapture --test-threads 1
rc=$?
echo "export rc $rc, $(( $(date +%s) - start )) s"
( cd "$D" && shasum -a 256 l47_w16r2_full.txt l47_w16r2_short.txt ) > "$OUT/l47_export_sha256.txt"
cat "$OUT/l47_export_sha256.txt"
for f in l47_w16r2_full.txt l47_w16r2_short.txt; do
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
