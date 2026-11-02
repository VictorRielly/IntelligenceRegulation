#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02): every Python D55 gate run of the record, one after another on one tool state,
# each with its pair as --other:
#  1. the FOUR round-26 registered R13 bundles (pg_bundles_r26, read only): they must stay D55-PASS with the new parts;
#  2. the new registered bases (pg_bundles_bases): TinyLlama T128 LOW, Shieldstral T128, Shieldstral T128 with layer 1
#     at its own norm constant, Shieldstral T256.
# Exit 0 only if every run exits 0 (PASS or DEV-PASS); the verdicts are read from the records.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7/results/zk60_d60_20261102/privacy_gate_tsbases
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
N=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases
rc=0
pair() {  # tag-stem, directory, bundle stem
  bash $P/pygate.sh py-$1-s0 $2/d55-$3-s0 --other $2/d55-$3-s1 || rc=1
  bash $P/pygate.sh py-$1-s1 $2/d55-$3-s1 --other $2/d55-$3-s0 || rc=1
}
pair r13-rung $B r13_rung_h24
pair tiny-t128 $N r13_tiny_t128_low
pair shield-t128 $N r13_shield_t128_h24
pair shield-t128-own $N r13_shield_t128_h24-own
pair r13-8b $B r13_8b_t128_h24
export PYGATE_NEED=24 PYGATE_CAP=160 PYGATE_MAXS=28800
pair shield-t256 $N r13_shield_t256_h24
exit $rc
