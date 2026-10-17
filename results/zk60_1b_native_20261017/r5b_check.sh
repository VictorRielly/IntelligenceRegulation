#!/bin/bash
# NATIVE LANE R5b (evening): compile the working copy's release lib tests and
# run the CLI / census tests the R5b edits touch (privacy review P-1, P-3,
# P-5, P-6, P-7): trained_block_tests, trained_stack_tests, the review-e
# door test, the s25 census, cs_port, run_tests' r3_6 test.
# usage: r5b_check.sh <label>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
L=$1
python3 -B $D/r5_manifest.py $D/r5/manifest_$L.json "sources at the start of r5b_check.sh $L"
until out=$(python3 $G check --class cpu --need-gib 4 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
python3 $G run --class cpu --need-gib 4 --cap-gib 7 --label $L --wait-secs 14400 --max-secs 3600 \
  --log $D/$L.log --done $D/$L.done --result-json $D/$L.guard.json \
  -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $M --lib -- --test-threads=4 \
     trained_block_tests trained_stack_tests review_e_ s25_tests cs_port_tests review_r3_6 trained_calib_tests
echo "$L exit $(cat $D/$L.done 2>/dev/null)"
