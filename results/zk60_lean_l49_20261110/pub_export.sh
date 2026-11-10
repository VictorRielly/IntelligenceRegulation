#!/bin/bash
# D63 Lean lane L49 (2026-11-10), sub-agent pub: build hashline's tests and run the TEST-ONLY export
# (src/lean_l49_export_tests.rs: every public table but SC_TAB's and SC_ZS's of a REAL R13 rung block receipt, proved by
# the production prove_core with w16r2_tests' seeded recipe and accepted by verify_core, with the public data they are
# built from and every slot's draws; and the Shieldstral T128 R13 shape's supp(Dom::L)), then hashline's census tests
# s25_tests and hash_domain. The FULL corpus lands in $1 (outside the repository); the SHORT corpus (no full tables, no
# weights) is copied here when under 1 MB; every file's sha256 is recorded in l49_export_sha256.txt. A copy of
# results/zk60_lean_l47_20261110/exp_export.sh. Run through run_guarded.py (class cpu).
# usage: pub_export.sh <out dir outside the repo> [census]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a09954f00024476bf
OUT=$WT/results/zk60_lean_l49_20261110
M=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
D="$1"
start=$(date +%s)
mkdir -p "$D"
env LEAN_L49_CORPUS="$D/pub_r13_host_full.txt" LEAN_L49_CORPUS_SHORT="$D/pub_r13_host_short.txt" \
  $C lean_l49_export -- --nocapture --test-threads 1
rc=$?
echo "export rc $rc, $(( $(date +%s) - start )) s"
( cd "$D" && shasum -a 256 pub_r13_host_full.txt pub_r13_host_short.txt ) > "$OUT/l49_export_sha256.txt"
cat "$OUT/l49_export_sha256.txt"
for f in pub_r13_host_full.txt pub_r13_host_short.txt; do
  if [ -f "$D/$f" ]; then
    sz=$(stat -f %z "$D/$f")
    echo "$f $sz bytes"
    if [ "$sz" -lt 1000000 ]; then cp "$D/$f" "$OUT/$f"; fi
  fi
done
crc=0
if [ "$2" = "census" ]; then
  for f in s25_tests hash_domain; do
    $C $f > "$OUT/pub_$f.log" 2>&1
    r=$?
    echo "hashline $f rc=$r"
    grep -E "^test result" "$OUT/pub_$f.log"
    [ $r -ne 0 ] && crc=$r
  done
fi
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ $crc -eq 0 ]
