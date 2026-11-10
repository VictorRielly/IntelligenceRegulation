#!/bin/bash
# D63 Lean lane L49 (2026-11-10), sub-agent pub, deliverable 4 (gap GB-6): ONE block of the app's Shieldstral-1.0-3B
# T128 R13 export, proved by the production prove_core and accepted by verify_core on the CPU (HL_GPU unset), and its
# record for the Lean checker (src/lean_l49_export_tests.rs, lean_l49_export_a_shieldstral_block); then the rung export
# again (its corpus must be byte-identical to the committed one after the record writer's refactor), and hashline's
# census tests s25_tests and hash_domain. The weights, the receipt and the full corpora stay in $1 (outside the
# repository); the short corpora are copied here when under 1 MB; every file's sha256 goes to l49_export_sha256.txt.
# Run through run_guarded.py (class cpu).
# usage: pub_shield_export.sh <out dir outside the repo> [layer]
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a09954f00024476bf
OUT=$WT/results/zk60_lean_l49_20261110
M=$WT/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
C="/opt/homebrew/bin/cargo test --release --offline --locked -j 2 --manifest-path $M --lib"
EXPORT=/Users/victorrielly/IntelligenceRegulation/results/zk60_shieldstral_export_20261026/native_low_h24_t128
MODELS=/Users/victorrielly/IntelligenceRegulation/results/zk60_astra_20261026/flashprove_runtime_20261104/models
D="$1"
L="${2:-0}"
start=$(date +%s)
mkdir -p "$D"
echo "== the Shieldstral block (layer $L), CPU only =="
env -u HL_GPU -u HL_GPU_REQUIRED HL_L49_SHIELD_EXPORT="$EXPORT" HL_L49_SHIELD_LAYER="$L" ZK60_MODELS="$MODELS" \
  LEAN_L49_SHIELD_CORPUS="$D/pub_shield_full.txt" LEAN_L49_SHIELD_CORPUS_SHORT="$D/pub_shield_short.txt" \
  $C lean_l49_export_a_shieldstral_block -- --ignored --nocapture --test-threads 1
rc=$?
echo "Shieldstral export rc $rc, $(( $(date +%s) - start )) s"
echo "== the rung export again (byte identity with the committed corpus) =="
env -u HL_GPU -u HL_GPU_REQUIRED LEAN_L49_CORPUS="$D/pub_r13_host_full_re.txt" LEAN_L49_CORPUS_SHORT="$D/pub_r13_host_short_re.txt" \
  $C lean_l49_export_the_r13_host_tables -- --nocapture --test-threads 1
rr=$?
echo "rung export rc $rr"
( cd "$D" && shasum -a 256 pub_r13_host_full.txt pub_r13_host_short.txt pub_shield_full.txt pub_shield_short.txt ) > "$OUT/l49_export_sha256.txt"
cat "$OUT/l49_export_sha256.txt"
( cd "$D" && shasum -a 256 pub_r13_host_full_re.txt pub_r13_host_short_re.txt )
for f in pub_shield_full.txt pub_shield_short.txt; do
  if [ -f "$D/$f" ]; then
    sz=$(stat -f %z "$D/$f")
    echo "$f $sz bytes"
    if [ "$sz" -lt 1000000 ]; then cp "$D/$f" "$OUT/$f"; fi
  fi
done
crc=0
for f in s25_tests hash_domain; do
  $C $f > "$OUT/pub_shield_$f.log" 2>&1
  r=$?
  echo "hashline $f rc=$r"
  grep -E "^test result" "$OUT/pub_shield_$f.log"
  [ $r -ne 0 ] && crc=$r
done
echo "total $(( $(date +%s) - start )) s"
[ $rc -eq 0 ] && [ $rr -eq 0 ] && [ $crc -eq 0 ]
