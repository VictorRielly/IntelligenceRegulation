#!/bin/bash
# D59 condition (5) privacy re-check (2026-11-02): the v25 STAGING Python gate on one capture bundle,
# guarded (cpu class). Usage: pygate.sh <tag> <module: w16|d55> <bundle dir> [extra args]
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-acdb40abef543db2f
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_20261101/logs/privacy_recheck
S=$R/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts
E=$R/results/zk60_w16r2_20261101/privacy_recheck_gate
# the session's gate venv (Python 3.13.13 + blake3 1.0.11; the system pythons have no blake3), the one
# round 25 ran the W16 gate under
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
TAG=$1; MOD=$2; BUNDLE=$3; shift 3
rm -f $L/$TAG.log $L/$TAG.guard.done
mkdir -p $E
$G --class cpu --need-gib 4 --cap-gib 24 --label pr-$TAG --wait-secs 7200 --max-secs 3600 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  $PY -B $S/zk60_native_rg_$MOD.py --bundle $BUNDLE --evidence $E "$@"
rc=$?
grep -v "^\[zk60-guard" $L/$TAG.log | tail -30
exit $rc
