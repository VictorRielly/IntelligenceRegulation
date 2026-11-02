#!/bin/bash
# D59 condition (5) privacy re-check (2026-11-02): the staging_v25 unit suite (as round 25 ran it), with the
# W16 rung, W16R2 rung and D55 bundles named so their bundle tests run; guarded (cpu class)
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_20261101/logs/privacy_recheck
B=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/bundles
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
TAG=${1:-suite_v25}
D55=${2:-d55-w16r2_rung_h24-s0}
rm -f $L/$TAG.log $L/$TAG.guard.done
$G --class cpu --need-gib 4 --cap-gib 24 --label pr-$TAG --wait-secs 7200 --max-secs 3600 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  env ZK60_W16_RUNG_BUNDLE=$B/w16_rung_h24-s0 ZK60_W16R2_RUNG_BUNDLE=$B/w16r2_rung_h24-s0 ZK60_D55_BUNDLE=$B/$D55 \
  $PY -B -m unittest discover -s $R/ops/zkp-mvp/gate-tinyllama/staging_v25/tests -v
rc=$?
grep -E "^(FAIL|ERROR):|^Ran |^OK|^FAILED" $L/$TAG.log
exit $rc
