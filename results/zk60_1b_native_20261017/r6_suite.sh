#!/bin/bash
# NATIVE LANE R6: the full guarded release suite on the R6 tree, every
# target run (--no-fail-fast). Budget pre-checked outside the heavy lock.
# usage: r6_suite.sh <label>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
L=$1
python3 -B $D/r5_manifest.py $D/r6/manifest_$L.json "sources at the start of r6_suite.sh $L"
until out=$(python3 $G check --class cpu --need-gib ${NEED:-4.5} 2>&1); echo "$out" | grep -q "OK to start now" || ! echo "$out" | sed 's/[^;]*is held//g' | grep -q "budget\|MemAvailable"; do sleep 30; done
python3 $G run --class cpu --need-gib ${NEED:-4.5} --cap-gib ${CAP:-8} --label $L --wait-secs 14400 --max-secs 5400 \
  --log $D/r6/$L.log --done $D/r6/$L.done --result-json $D/r6/$L.guard.json \
  -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --no-fail-fast --manifest-path $M -- --test-threads=8
echo "suite $L exit $(cat $D/r6/$L.done 2>/dev/null)"
