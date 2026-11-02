#!/bin/bash
# TS / CENSUS / bases lane (2026-11-02): the v25 STAGING Python D55 gate (with this lane's TS-1, CENSUS, HASH-1 and
# HASH-2 parts) on one fork-run bundle, guarded (cpu class: the TS part runs its groups in a 16-process pool).
# Usage: pygate.sh <tag> <bundle dir> [extra args, e.g. --other <dir>]   (privacy_gate_r26/pygate.sh, this worktree)
set -u
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ad5119ba9083f7dc7
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
P=$R/results/zk60_d60_20261102/privacy_gate_tsbases
L=$P/logs
S=$R/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts
E=$P/records
# the session's gate venv (Python 3.13.13 + blake3 1.0.11), the one the D60 privacy gate and round 26 ran under
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
# the Rust s25 W-2 census printout (HASH-2 looks every measured kind up in it); its sha256 goes into the record
W2=$P/logs/s25_w2_printout.log
TAG=$1; BUNDLE=$2; shift 2
NEED=${PYGATE_NEED:-16}; CAP=${PYGATE_CAP:-96}; MAXS=${PYGATE_MAXS:-14400}
rm -f $L/$TAG.log $L/$TAG.guard.done
mkdir -p $E
$G --class cpu --need-gib $NEED --cap-gib $CAP --label tsb-$TAG --wait-secs 28800 --max-secs $MAXS --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  env ZK60_D55TS_WORKERS=${ZK60_D55TS_WORKERS:-16} ZK60_S25_W2_PRINTOUT=$W2 $PY -B $S/zk60_native_rg_d55.py --bundle $BUNDLE --evidence $E --name $TAG "$@"
rc=$?
grep -v "^\[zk60-guard" $L/$TAG.log | grep -v "^   control\|^G7 census\|ResourceWarning\|return hashlib" | tail -24
grep "zk60-guard.*END" $L/$TAG.log
exit $rc
