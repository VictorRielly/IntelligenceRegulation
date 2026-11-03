#!/bin/bash
# NL-1 / PRE lane (2026-11-02): the staging_v25 Python suite, guarded, with every bundle named (privacy_gate_r26/suite.sh
# with this worktree's paths). Usage: suite.sh <tag>
set -u
P=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a19d9832207e830a4/results/zk60_d60_20261102/privacy_gate_nlpre
L=$P/logs
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a19d9832207e830a4
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
B=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26
O=/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles
W=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
TAG=${1:-suite_v25}
rm -f $L/$TAG.log $L/$TAG.guard.done
$G --class cpu --need-gib 4 --cap-gib 24 --label nlpre-$TAG --wait-secs 28800 --max-secs 3600 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  env ZK60_W16_RUNG_BUNDLE=$W/w16_rung_h24-s0 ZK60_W16R2_RUNG_BUNDLE=$W/w16r2_rung_h24-s0 ZK60_D55_BUNDLE=$W/d55-w16_rung_h24-s0 \
  ZK60_D55_R13_BUNDLE=$B/d55-r13_rung_h24-s0 ZK60_D55_R13_OTHER=$B/d55-r13_rung_h24-s1 ZK60_D60_OLD_BUNDLE=$O/d55-r13_rung_h24-s0 \
  $PY -B -m unittest discover -s $R/ops/zkp-mvp/gate-tinyllama/staging_v25/tests -v
grep -E "^(FAIL|ERROR):|^Ran |^OK|^FAILED" $L/$TAG.log
grep "zk60-guard.*END" $L/$TAG.log
