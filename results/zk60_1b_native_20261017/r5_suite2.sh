#!/bin/bash
# NATIVE LANE round 5 (evening): the full guarded release suite on the R5
# tree after the cs6 test fix (19:03 UTC), every target run (--no-fail-fast).
# usage: r5_suite2.sh <label>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
L=$1
python3 -B $D/r5_manifest.py $D/r5/manifest_$L.json "sources at the start of r5_suite2.sh $L"
python3 $G run --class cpu --need-gib ${NEED:-4.5} --cap-gib ${CAP:-8} --label $L --wait-secs 14400 --max-secs 5400 \
  --log $D/$L.log --done $D/$L.done --result-json $D/$L.guard.json \
  -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path $M -- --test-threads=8
echo "suite $L exit $(cat $D/$L.done 2>/dev/null)"
