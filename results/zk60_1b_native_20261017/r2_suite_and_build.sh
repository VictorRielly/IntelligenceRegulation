#!/bin/bash
# NATIVE LANE round 2 (2026-10-17): the full guarded release suite on the
# fixed tree (review findings F-1..F-6 + R2-1/R2-4/R2-5 code), then the
# release CLI build, copied beside the evidence with its SHA-256.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
C=/home/victor/.cargo/bin/cargo
python3 $G run --class cpu --need-gib 3 --cap-gib 6 --label r2-full-release --wait-secs 14400 --max-secs 5400 \
  --log $D/r2-full-release.log --done $D/r2-full-release.done --result-json $D/r2-full-release.guard.json \
  -- $C test --release --offline --locked -j2 --manifest-path $M
echo "suite exit $?"
python3 $G run --class build --need-gib 3 --cap-gib 5 --label r2-cli-build --wait-secs 14400 --max-secs 3000 \
  --log $D/r2-cli-build.log --done $D/r2-cli-build.done --result-json $D/r2-cli-build.guard.json \
  -- $C build --release --offline --locked -j2 --manifest-path $M --example zk60_trained_block
rc=$?
echo "build exit $rc"
if [ $rc -eq 0 ]; then
  mkdir -p $D/r2
  cp /home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/target/release/examples/zk60_trained_block $D/r2/zk60_trained_block.release.bin
  sha256sum $D/r2/zk60_trained_block.release.bin > $D/r2/zk60_trained_block.release.sha256
fi
