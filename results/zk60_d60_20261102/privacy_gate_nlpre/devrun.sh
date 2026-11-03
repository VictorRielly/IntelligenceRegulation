#!/bin/bash
# NL-1 / PRE lane (2026-11-02): one guarded DEVELOPMENT run of a v25 staging module's CLI (cpu class), log in dev/.
# Usage: devrun.sh <tag> <module.py> <args...>      (records under dev/; not the record of this directory)
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a19d9832207e830a4
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/privacy_gate_nlpre/dev
S=$R/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
TAG=$1; MOD=$2; shift 2
rm -f $L/$TAG.log $L/$TAG.guard.done
$G --class cpu --need-gib 8 --cap-gib 24 --label nlpre-$TAG --wait-secs 7200 --max-secs 14400 --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  $PY -B $S/$MOD "$@"
rc=$?
grep -v "^\[zk60-guard" $L/$TAG.log | tail -40
grep "zk60-guard.*END" $L/$TAG.log
exit $rc
