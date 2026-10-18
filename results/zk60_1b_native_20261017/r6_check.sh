#!/bin/bash
# NATIVE LANE R6 item 1: compile the working copy's release lib tests and run
# the tests the per-layer sh_s edits touch: the new r6_tests, the trained
# stack/block CLI tests (per-layer export end to end), the trained statement
# and calibration tests, review-d24 / r4 literals, the s24/s25 census, the
# review-e door test, cs_port.
# usage: r6_check.sh <label>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
L=$1
mkdir -p $D/r6
python3 -B $D/r5_manifest.py $D/r6/manifest_$L.json "sources at the start of r6_check.sh $L"
until out=$(python3 $G check --class cpu --need-gib 4 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
python3 $G run --class cpu --need-gib 4 --cap-gib 7 --label $L --wait-secs 14400 --max-secs 3600 \
  --log $D/r6/$L.log --done $D/r6/$L.done --result-json $D/r6/$L.guard.json \
  -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $M --lib -- --test-threads=4 \
     r6_tests trained_block_tests trained_stack_tests trained_statement review_e_ s25_tests s24_tests cs_port_tests trained_calib_tests review_d24 r4_tests
echo "$L exit $(cat $D/r6/$L.done 2>/dev/null)"
