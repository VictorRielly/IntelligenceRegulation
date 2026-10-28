#!/bin/bash
# NATIVE LANE R9 (copied from the R8 stack script): one stack run with the R9 CLI (CPU); DD=1 adds --dd (D30) to the prover and both verifies, HL_PB_TIMING=1,
# RAYON_NUM_THREADS=16, no in-process verify (the prover's statement goes to
# <run>.unverified-statement/), then a FRESH-process verify with every
# run-level control from a VERIFIER'S COPY of the export (real copies, no
# seq_*; privacy review P-5), which writes <run>/statement/ itself (review
# r5_A), then a second verify against that statement (the byte check).
# The budget is pre-checked OUTSIDE the heavy lock.
# usage: [DD=1] r9_stack.sh <export dir> <seq id> <need> <cap> [witness-cache-gib]
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
X=$D/r9/zk60_trained_block.release.bin
DDF=""; [ "${DD:-0}" = 1 ] && DDF="--dd"
E=$1; S=$2; NEED=$3; CAP=$4; WC=${5:-4}
V=$(basename "$E"); R=$D/r9/stack-$V-$S-cpu${DDF:+-dd}${TAG:-}
VE=$D/r9/verifier-exports/$V
[ -x "$X" ] || { echo "no R9 CLI $X"; exit 1; }
if [ ! -d "$VE" ]; then
  python3 -c "
import os, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
shutil.copytree(src, dst, ignore=lambda d, names: [n for n in names if d == src and n.startswith('seq_')])
print('verifier copy', dst, sorted(os.listdir(dst))[:6])" "$E" "$VE" || exit 1
fi
mkdir -p "$R"
pre() {  # $1 = need
  until out=$(python3 $G check --class cpu --need-gib $1 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
}
pre $NEED
python3 $G run --class cpu --need-gib $NEED --cap-gib $CAP --label r9-stack${DDF:+-dd}-$V --wait-secs 14400 --max-secs 5400 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=16 $X stack-prove --export "$E" --seq "$S" --out "$R/run" --witness-cache-gib $WC $DDF
rc=$?
[ $rc -eq 0 ] || { echo "stack-prove $V exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run.unverified-statement/statement.json")
for pass in verify recheck; do
  CT=""; [ $pass = verify ] && CT="--controls"
  pre ${VNEED:-2.5}
  python3 $G run --class cpu --need-gib ${VNEED:-2.5} --cap-gib ${VCAP:-8} --label r9-stack${DDF:+-dd}-$pass-$V --wait-secs 14400 --max-secs 5400 \
    --log "$R/$pass.log" --done "$R/$pass.done" --result-json "$R/$pass.guard.json" \
    -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export "$VE" --artifact "$R/run" --expect-statement "$ID" $CT $DDF
  echo "stack-$pass $V exit $(cat $R/$pass.done 2>/dev/null)"
done
