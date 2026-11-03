#!/bin/bash
# v25 freeze fixes (FR25): the whole staging_v25 Python suite on the FIXED tool state, with every bundle the m32 suite
# named (the W16 / W16R2 scratch bundles, the round-26 R13 rung pair, the old D60 bundle, the eight registered bases)
# and the pinned s25 printout. Guarded, cpu class (the shared heavy lock): run only after the merged-gate queue ends.
# Usage: suite.sh [tool tree] [tag]   (default tree: the fr25-fixes worktree; after a merge, the main checkout)
set -u
T=${1:-/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/fr25-fixes}
TAG=${2:-suite_v25_fr25}
L=$T/results/zk60_gate_tinyllama_20261017/round27/fixes/logs
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
BR=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
O=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
N=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
W2=/Users/victorrielly/zk60-artifacts/d60_20261102/s25_w2_printout_v2.log
BASES=$N/d55-r13_tiny_t128_low-s0,$N/d55-r13_tiny_t128_low-s1,$N/d55-r13_shield_t128_h24-s0,$N/d55-r13_shield_t128_h24-s1,$N/d55-r13_shield_t128_h24-own-s0,$N/d55-r13_shield_t128_h24-own-s1,$N/d55-r13_shield_t256_h24-s0,$N/d55-r13_shield_t256_h24-s1
mkdir -p "$L"
$G --class cpu --need-gib 8 --cap-gib 48 --label fr25-$TAG --wait-secs 28800 --max-secs 3600 --log "$L/$TAG.log" --done "$L/$TAG.guard.done" -- \
  env -u ZK60_NL_CHECK_DIR ZK60_W16_RUNG_BUNDLE=$W/w16_rung_h24-s0 ZK60_W16R2_RUNG_BUNDLE=$W/w16r2_rung_h24-s0 ZK60_D55_BUNDLE=$W/d55-w16_rung_h24-s0 \
  ZK60_D55_R13_BUNDLE=$BR/d55-r13_rung_h24-s0 ZK60_D55_R13_OTHER=$BR/d55-r13_rung_h24-s1 ZK60_D60_OLD_BUNDLE=$O/d55-r13_rung_h24-s0 \
  ZK60_D55_BASE_BUNDLES=$BASES ZK60_S25_W2_PRINTOUT=$W2 \
  $PY -B -m unittest discover -s "$T/ops/zkp-mvp/gate-tinyllama/staging_v25/tests" -v
grep -E "^(FAIL|ERROR):|^Ran |^OK|^FAILED" "$L/$TAG.log"
