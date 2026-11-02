#!/bin/bash
# Merged gate (2026-11-02): the v25 STAGING Python D55 gate on the MAIN checkout after both lanes merged -- every part
# of round 26 plus the TS / CENSUS lane's four (TS-1, CENSUS, HASH-1, HASH-2) and the NL-1 / PRE lane's two (NL-1,
# full preimage) -- on one fork-run bundle, guarded (cpu class; the TS part runs a 16-process pool).
# Usage: pygate.sh <tag> <bundle dir> [extra args, e.g. --other <dir>]
# HASH-2 looks every measured kind up in the Rust s25 W-2 printout of the TS lane's pass 2 (076a485f; no Rust file
# changed since): logs/s25_w2_printout_v2.log.gz, unpacked outside the repo, sha256 bac4bbd6...dc53 checked
# against that lane's logs/PRINTOUTS_SHA256.txt; the record carries the digest it read.
set -u
R=/Users/victorrielly/IntelligenceRegulation
G="python3 $R/scripts/zk60_resource_guard.py run"
P=$R/results/zk60_d60_20261102/privacy_gate_merged
L=$P/logs
S=$R/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts
E=$P/records
# the session's gate venv (Python 3.13.13 + blake3 1.0.11), the one the D60 privacy gate and round 26 ran under
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
W2=/Users/victorrielly/zk60-artifacts/d60_20261102/s25_w2_printout_v2.log
TAG=$1; BUNDLE=$2; shift 2
NEED=${PYGATE_NEED:-24}; CAP=${PYGATE_CAP:-160}; MAXS=${PYGATE_MAXS:-43200}
rm -f $L/$TAG.log $L/$TAG.guard.done
mkdir -p $E $L
$G --class cpu --need-gib $NEED --cap-gib $CAP --label mg-$TAG --wait-secs 28800 --max-secs $MAXS --log $L/$TAG.log --done $L/$TAG.guard.done -- \
  env ZK60_D55TS_WORKERS=16 ZK60_S25_W2_PRINTOUT=$W2 $PY -B $S/zk60_native_rg_d55.py --bundle $BUNDLE --evidence $E --name $TAG "$@"
rc=$?
grep -v "^\[zk60-guard" $L/$TAG.log | grep -v "^   control\|^G7 census\|ResourceWarning\|return hashlib" | tail -24
grep "zk60-guard.*END" $L/$TAG.log
exit $rc
