#!/bin/bash
# NATIVE LANE, speed plan stretch task 4 (2026-10-17 evening): the first
# private 32-block Llama-3-8B stack at T=128 on the CPU, from the calibration
# lane's verified export llama3_8b_pg_rot1_b6_T128, with the working copy's
# CLI ("cli4": R5 frozen tree + the 8B T64/T128 profiles, PENDING INDEPENDENT
# REVIEW of the T128 profile). (1) guarded CLI build into r5/cli4/ (its own
# path: r5/zk60_trained_block.release.bin may be executing), (2) ONE guarded
# cpu stack-prove (HL_PB_TIMING=1, RAYON_NUM_THREADS=16, no in-process
# verify), (3) a FRESH-process verify with the 11 run-level controls.
# usage: r5_t4_stack.sh <need GiB> <cap GiB> <seq>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
H=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline
M=$H/Cargo.toml
C=/home/victor/.cargo/bin/cargo
E=/home/victor/IntelligenceRegulation/results/zk60_8b_calibration_20261017/export/llama3_8b_pg_rot1_b6_T128
NEED=$1; CAP=$2; S=${3:-ho00}
mkdir -p $D/r5/cli4
X=$D/r5/cli4/zk60_trained_block.release.bin
if [ ! -f $D/r5/cli4/build.done ]; then
  python3 -B $D/r5_manifest.py $D/r5/cli4/manifest.json "sources of the cli4 build (R5 frozen tree + 8B T64/T128 profiles)"
  python3 $G run --class build --need-gib 2.5 --cap-gib 5 --label r5-cli4-build --wait-secs 14400 --max-secs 3600 \
    --log $D/r5/cli4/build.log --done $D/r5/cli4/build.done --result-json $D/r5/cli4/build.guard.json \
    -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block
  [ "$(cat $D/r5/cli4/build.done)" = 0 ] || { echo "cli4 build failed"; exit 1; }
  cp $H/target/release/examples/zk60_trained_block $X
  sha256sum $X > $D/r5/cli4/binary.sha256
fi
R=$D/r5/stack-llama3_8b_pg_rot1_b6_T128-$S-cpu
mkdir -p "$R"
# the guard takes the heavy lock BEFORE it waits for admission: wait for the
# memory budget OUTSIDE the lock first (a lock that is merely held is fine)
until out=$(python3 $G check --class cpu --need-gib $NEED 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do
  sleep 30
done
echo "budget pre-check passed $(date -u +%H:%M:%S): $out"
python3 $G run --class cpu --need-gib $NEED --cap-gib $CAP --label r5-t4-stack-8b-T128 --wait-secs 14400 --max-secs 5400 \
  --log "$R/prove.log" --done "$R/prove.done" --result-json "$R/prove.guard.json" \
  -- /usr/bin/env HL_PB_TIMING=1 RAYON_NUM_THREADS=16 $X stack-prove --export "$E" --seq "$S" --out "$R/run"
rc=$?
[ $rc -eq 0 ] || { echo "t4 stack-prove exit $rc"; exit $rc; }
ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['trained_statement_identity'])" "$R/run/statement/statement.json")
python3 $G run --class cpu --need-gib ${VNEED:-3} --cap-gib ${VCAP:-8} --label r5-t4-verify-8b-T128 --wait-secs 14400 --max-secs 5400 \
  --log "$R/verify.log" --done "$R/verify.done" --result-json "$R/verify.guard.json" \
  -- /usr/bin/env RAYON_NUM_THREADS=16 $X stack-verify --export "$E" --artifact "$R/run" --expect-statement "$ID" --controls
echo "t4 stack-verify exit $?"
