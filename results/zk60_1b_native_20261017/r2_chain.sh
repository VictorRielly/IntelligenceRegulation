#!/bin/bash
# NATIVE LANE round 2 (2026-10-17): the full guarded release suite again
# (8 test threads: the 22-thread default peaked at the 6 GiB cap and was
# killed), then R2-2 (r2_pg.sh) and R2-3 (r2_stack.sh ho00), CPU only.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
python3 $G run --class cpu --need-gib 5 --cap-gib 8 --label r2-full-release2 --wait-secs 14400 --max-secs 5400 \
  --log $D/r2-full-release2.log --done $D/r2-full-release2.done --result-json $D/r2-full-release2.guard.json \
  -- /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $M -- --test-threads=8
echo "suite exit $?"
$D/r2_pg.sh
echo "pg done"
$D/r2_stack.sh ho00
echo "stack done"
