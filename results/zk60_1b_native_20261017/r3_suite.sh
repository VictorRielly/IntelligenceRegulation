#!/bin/bash
# NATIVE LANE round 3: the full guarded release suite (8 test threads).
# usage: r3_suite.sh <label>
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
L=$1
python3 $G run --class cpu --need-gib 5 --cap-gib 8 --label $L --wait-secs 14400 --max-secs 5400 \
  --log $D/$L.log --done $D/$L.done --result-json $D/$L.guard.json \
  -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $M -- --test-threads=8
