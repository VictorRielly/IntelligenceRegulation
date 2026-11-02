#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02): after build.sh, every guarded test-binary run of the record, in order:
#  0. the Rust s25 W-2 census with its printout (HASH-2 looks every measured kind up in it);
#  1. the registered D55 bundles at the three bases never captured: TinyLlama T128 LOW, Shieldstral T128, Shieldstral
#     T256 (two hidden inputs each), and Shieldstral T128 with layer 1 at its OWN norm constant (the per-layer path),
#     each base in its own writer run (the writer reads every bundle back and runs the Rust gate checks on it).
# CPU only (run.sh unsets HL_GPU). Exit 0 only if every run exits 0.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7/results/zk60_d60_20261102/privacy_gate_tsbases
D=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases
C=${SOURCE_COMMIT:-e44c01f5}
T="--ignored --exact --nocapture --test-threads=1 private_block::run::fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles"
rc=0
bash $P/run.sh s25_w2 cpu 4 16 -- --exact --nocapture --test-threads=1 private_block::s25_tests::every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length || rc=1
cp $P/logs/s25_w2.log $P/logs/s25_w2_printout.log
for c in "tiny R13_TINY_T128_LOW:0,R13_TINY_T128_LOW:1" "shield128 R13_SHIELD_T128_H24:0,R13_SHIELD_T128_H24:1" \
         "shield256 R13_SHIELD_T256_H24:0,R13_SHIELD_T256_H24:1" "shield128own R13_SHIELD_T128_H24:0:own,R13_SHIELD_T128_H24:1:own"; do
  set -- $c
  bash $P/run.sh write-$1 cpu 32 200 HL_D60PG_CAPTURE_DIR=$D HL_D60PG_CASES=$2 HL_TEST_SOURCE_COMMIT=$C -- $T || rc=1
done
exit $rc
