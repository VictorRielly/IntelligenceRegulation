#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02), PASS 2, after the s25 W-2 fix (every registered D55 profile measured at every
# L in 1..=32, the parameter-line length lemma; logs/s25_w2_printout_v2.log): every Python D55 gate run again, on one
# tool state, through pygate2.sh (records in records_final/, logs logs/final-*.log; pass 1 stays in records/ and
# logs/py-*.log as the evidence of the finding), each with its pair as --other:
#  1. the FOUR round-26 registered R13 bundles (pg_bundles_r26, read only): they must end D55-PASS;
#  2. the new registered bases (pg_bundles_bases): TinyLlama T128 LOW, Shieldstral T128, Shieldstral T128 with layer 1
#     at its own norm constant, Shieldstral T256.
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7/results/zk60_d60_20261102/privacy_gate_tsbases
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
N=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases
rc=0
pair() {  # tag-stem, directory, bundle stem
  bash $P/pygate2.sh final-$1-s0 $2/d55-$3-s0 --other $2/d55-$3-s1 || rc=1
  bash $P/pygate2.sh final-$1-s1 $2/d55-$3-s1 --other $2/d55-$3-s0 || rc=1
}
pair r13-rung $B r13_rung_h24
pair tiny-t128 $N r13_tiny_t128_low
pair shield-t128 $N r13_shield_t128_h24
pair shield-t128-own $N r13_shield_t128_h24-own
pair r13-8b $B r13_8b_t128_h24
export PYGATE_NEED=24 PYGATE_CAP=160 PYGATE_MAXS=28800
pair shield-t256 $N r13_shield_t256_h24
exit $rc
