#!/bin/bash
# NATIVE LANE round 3: full guarded release suite on the round-3 tree, then
# the heavy (ignored) round-3 and TinyLlama tests in release.
set -u
D=/home/victor/IntelligenceRegulation/results/zk60_1b_native_20261017
G=/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py
M=/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b/hashline/Cargo.toml
$D/r3_suite.sh r3-suite-final
echo "suite exit $(cat $D/r3-suite-final.done 2>/dev/null)"
python3 $G run --class cpu --need-gib 5 --cap-gib 8 --label r3-heavy --wait-secs 14400 --max-secs 5400 \
  --log $D/r3-heavy.log --done $D/r3-heavy.done --result-json $D/r3-heavy.guard.json \
  -- /usr/bin/env RAYON_NUM_THREADS=16 /home/victor/.cargo/bin/cargo test --release --offline --locked -j2 --manifest-path $M --lib -- --ignored --test-threads=1 --nocapture \
     native_witness_time_per_block_at_the_trained_tinyllama_shapes the_parallel_products_equal_the_sequential_ones_at_the_tinyllama_dimensions \
     review_f_the_naive_quotient_forgery_is_rejected_at_slot_17_at_the_trained_tinyllama_profile native_the_half_p_alias_is_refused_end_to_end_at_the_trained_tinyllama_profile \
     native_t3_generic_trained_tinyllama_block_proves_and_verifies
echo "heavy exit $?"
