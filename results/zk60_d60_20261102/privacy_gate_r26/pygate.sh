#!/bin/bash
# Gate round 26 wiring (2026-11-02): the v25 STAGING Python D55 gate on one fork-run bundle, guarded (cpu class).
# Usage: pygate.sh <tag> <bundle dir> [extra args, e.g. --other <dir>]   (privacy_gate/pygate.sh, this worktree)
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad2863f50f3102344
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/privacy_gate_r26/logs
S=$R/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts
E=$R/results/zk60_d60_20261102/privacy_gate_r26/records
# the session's gate venv (Python 3.13.13 + blake3 1.0.11; the system pythons have no blake3), the one the
# D60 privacy gate, the privacy re-check and round 25 ran under
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
TAG=$1; BUNDLE=$2; shift 2
rm -f $L/$TAG.log $L/$TAG.guard.done
mkdir -p $E
$G --class cpu --need-gib 4 --cap-gib 24 --label r26-$TAG --wait-secs 7200 --max-secs 3600 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  $PY -B $S/zk60_native_rg_d55.py --bundle $BUNDLE --evidence $E --name $TAG "$@"
rc=$?
grep -v "^\[zk60-guard" $L/$TAG.log | tail -24
grep "zk60-guard.*END" $L/$TAG.log
exit $rc
