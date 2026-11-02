#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02): the staging_v25 Python suite, guarded, with every bundle round 26 named plus
# this lane's new registered bases (ZK60_D55_BASE_BUNDLES, for test_d55_ts_hash.TheRegisteredBases).
# Usage: suite.sh <tag>      (privacy_gate_r26/suite.sh with this worktree's paths)
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7/results/zk60_d60_20261102/privacy_gate_tsbases
L=$P/logs
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
O=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
N=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_bases
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
BASES=$N/d55-r13_tiny_t128_low-s0,$N/d55-r13_tiny_t128_low-s1,$N/d55-r13_shield_t128_h24-s0,$N/d55-r13_shield_t128_h24-s1,$N/d55-r13_shield_t128_h24-own-s0,$N/d55-r13_shield_t128_h24-own-s1,$N/d55-r13_shield_t256_h24-s0,$N/d55-r13_shield_t256_h24-s1
TAG=${1:-suite_v25}
rm -f $L/$TAG.log $L/$TAG.guard.done
$G --class cpu --need-gib 8 --cap-gib 48 --label tsb-$TAG --wait-secs 28800 --max-secs 3600 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  env ZK60_W16_RUNG_BUNDLE=$W/w16_rung_h24-s0 ZK60_W16R2_RUNG_BUNDLE=$W/w16r2_rung_h24-s0 ZK60_D55_BUNDLE=$W/d55-w16_rung_h24-s0 \
  ZK60_D55_R13_BUNDLE=$B/d55-r13_rung_h24-s0 ZK60_D55_R13_OTHER=$B/d55-r13_rung_h24-s1 ZK60_D60_OLD_BUNDLE=$O/d55-r13_rung_h24-s0 \
  ZK60_D55_BASE_BUNDLES=$BASES \
  $PY -B -m unittest discover -s $R/ops/zkp-mvp/gate-tinyllama/staging_v25/tests -v
grep -E "^(FAIL|ERROR):|^Ran |^OK|^FAILED" $L/$TAG.log
grep "zk60-guard.*END" $L/$TAG.log
