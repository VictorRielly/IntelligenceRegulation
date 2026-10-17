#!/bin/bash
# NATIVE LANE round 4, R4-2 (2026-10-17): ONE generic Llama-3-8B-geometry
# block at T32 (release), memory gate need 6 / cap 9 GiB as directed (the
# gate run measured 1.96 GiB; later runs pass NEED/CAP at the measured peak); then
# the fresh-process verify of its saved segment.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
python3 $G run --class cpu --need-gib ${NEED:-6} --cap-gib ${CAP:-9} --label r4-generic-8b --wait-secs 14400 --max-secs 5400 \
  --log $D/r4/generic/prove.log --done $D/r4/generic/prove.done --result-json $D/r4/generic/prove.guard.json \
  -- /usr/bin/env RAYON_NUM_THREADS=16 ZK60_NATIVE_R4_DIR=$D/r4/generic /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $M --lib -- --ignored --test-threads=1 --nocapture native_r4_2_generic_llama3_8b_block_proves_verifies_and_every_control_refuses
rc=$?
echo "prove exit $rc"
[ $rc -eq 0 ] || exit $rc
python3 $G run --class cpu --need-gib ${VNEED:-4} --cap-gib ${VCAP:-7} --label r4-generic-8b-verify --wait-secs 14400 --max-secs 3600 \
  --log $D/r4/generic/verify.log --done $D/r4/generic/verify.done --result-json $D/r4/generic/verify.guard.json \
  -- /usr/bin/env RAYON_NUM_THREADS=16 ZK60_NATIVE_R4_DIR=$D/r4/generic /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $M --lib -- --ignored --test-threads=1 --nocapture native_r4_2_verify_the_saved_8b_segment_in_a_fresh_process
echo "verify exit $?"
