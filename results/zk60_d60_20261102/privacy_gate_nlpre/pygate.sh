#!/bin/bash
# NL-1 / PRE lane (2026-11-02): the v25 STAGING Python D55 gate (with the NL-1 and PRE parts) on one fork-run bundle,
# guarded (cpu class).  Usage: pygate.sh <tag> <bundle dir> [extra args, e.g. --other <dir>]
# (privacy_gate_r26/pygate.sh with this worktree's paths; max-secs 21600: an 8B record is ~3 h of exact Fp, most of it
# the six ah_controls re-solving A / H; wait-secs 28800: the run queues behind the other lane's heavy jobs, coordinator
# 2026-11-02 -- the first launch, with 14400, was refused after its wait ran out)
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a19d9832207e830a4
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/privacy_gate_nlpre/logs
S=$R/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts
E=$R/results/zk60_d60_20261102/privacy_gate_nlpre/records
# the session's gate venv (Python 3.13.13 + blake3 1.0.11), the one the D60 privacy gate and round 26 ran under
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
TAG=$1; BUNDLE=$2; shift 2
rm -f $L/$TAG.log $L/$TAG.guard.done
mkdir -p $E
$G --class cpu --need-gib 8 --cap-gib 24 --label nlpre-$TAG --wait-secs 28800 --max-secs 21600 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  $PY -B $S/zk60_native_rg_d55.py --bundle $BUNDLE --evidence $E --name $TAG "$@"
rc=$?
grep -v "^\[zk60-guard" $L/$TAG.log | tail -30
grep "zk60-guard.*END" $L/$TAG.log
exit $rc
