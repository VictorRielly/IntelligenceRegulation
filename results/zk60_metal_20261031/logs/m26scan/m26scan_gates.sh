#!/bin/bash
# M26 source-scan repair gate chain: the scans the Metal / W16 / D55 work left stale (r19b, s24 pins,
# s24 H-4, s25 module graph / census / W-2 / W-7 / W-8(7) / W-11, the absorb-label scan), then the
# standing gates. Template: m22f3_gates.sh. `quick` as $1: build + scans only.
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation
G="python3 $R/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_metal_20261031/logs/m26scan
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=$R/results/zk60_1b_native_20261017/r13/loader-fixtures
T=private_block::slot_ir::accuracy::tests
MODE=${1:-full}
mkdir -p $L
step() { echo "== $1 $(date +%H:%M:%S)"; }
# the guard APPENDS to a step's log: move any earlier attempt's step logs aside, so every grep
# below reads this run's output only
P=$L/prior-$(date +%Y%m%dT%H%M%S); for f in $L/g_*; do [ -e "$f" ] || continue; mkdir -p $P; mv "$f" $P/; done

step build
$G --class build --need-gib 4 --cap-gib 10 --label m26scan-build --wait-secs 7200 --max-secs 3600 --log $L/g_build.log --done $L/g_build.done -- \
  bash -c "cargo test --release --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --manifest-path $H --lib --tests" \
  || { grep -E -A12 '^(error|warning)' $L/g_build.log | tail -60; exit 1; }
grep -c "^warning" $L/g_build.log
# the no-feature `cargo check --tests` is the second half of the build step: it must have finished
[ "$(grep -c 'Finished' $L/g_build.log)" -ge 2 ] || { echo "THE BUILD LOG HAS NOT BOTH FINISHED LINES (gpu-metal test build, no-feature check)"; exit 1; }
# the test binary's hash moves with the build: read it from this build's log
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/g_build.log | tail -1)
[ -n "$REL" ] || { echo "NO TEST BINARY IN THE BUILD LOG"; exit 1; }
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
echo "B=$B"
ls -la $B || exit 1

# THE SCANS: the m25merge failing set (filters r19b s24 s25 absorb, 35 tests) plus s33 (the J-7a registry premise and lemma) and hash_domain:: (the T-3 text pins), 58, fixtures env set
sleep 5
step scans
$G --class cpu --need-gib 4 --cap-gib 20 --label m26scan-scans --wait-secs 7200 --max-secs 3000 --log $L/g_scans.log --done $L/g_scans.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B r19b s24 s25 absorb s33 hash_domain::
grep -h "test result\|FAILED\|panicked" $L/g_scans.log | tail -12
for t in \
  "s24_tests::the_capture_writer_pins_every_run_layer_source_it_depends_on" \
  "s24_tests::every_registered_profile_is_covered_and_every_tagged_ones_keys_are_pairwise_distinct" \
  "s25_tests::stage_24s_twelve_key_test_still_covers_every_tagged_profile" \
  "s25_tests::every_hash_call_site_in_the_lanes_own_sources_is_classified" \
  "s25_tests::r18_the_census_reads_the_batch_files_through_their_path_lines" \
  "s25_tests::r19b_every_rs_file_under_private_block_is_on_the_path_or_a_named_test_file" \
  "s25_tests::no_profile_on_this_path_can_obtain_a_generator_other_than_from_the_operating_system" \
  "s25_tests::every_hash_input_kind_of_every_registered_profile_is_printed_with_its_length" \
  "hash_domain::tests::every_absorb_label_on_the_path_is_in_the_table" \
  "run::fork::tests::d55_control_a_boundary_root_absorbed_after_a_fork_is_rejected" \
  "s33_tests::every_registered_profile_context_and_label_is_printable_ascii_with_no_nul" \
  "hash_domain::tests::the_length_formulas_are_still_the_ones_zkp_core_hashes" \
  "s33_tests::no_transcript_constructor_input_can_equal_an_absorb_input_of_the_same_length" \
  "s33_tests::the_declared_sixty_three_byte_w16_rung_pair_is_separated_at_the_positions_the_record_names"; do
  grep -q "test private_block::$t ... ok" $L/g_scans.log || { echo "SCAN NOT GREEN: $t"; exit 1; }
done
grep -q "test result: ok. 58 passed; 0 failed" $L/g_scans.log || { echo "THE SCAN SET IS NOT 58/0"; exit 1; }
# the printed census lines, for the record
$G --class cpu --need-gib 4 --cap-gib 20 --label m26scan-scans-print --wait-secs 7200 --max-secs 3000 --log $L/g_scans_print.log --done $L/g_scans_print.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B r19b s24 s25 absorb s33 hash_domain:: --nocapture --test-threads=1
grep -h "^S24 \|^S25 W-7\|^S25 W-8\|^S25 W-11\|^S25 W-2\|^TOKEN-IO R1[89]\|^TOKEN-IO R19b\|^S33 J-7a\|test result" $L/g_scans_print.log | cut -c1-400
grep -q "test result: ok. 58 passed; 0 failed" $L/g_scans_print.log || exit 1
[ "$MODE" = quick ] && { step quick-done; exit 0; }

sleep 10
step zkp-core
ZC=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
$G --class build --need-gib 4 --cap-gib 10 --label m26scan-zkpcore --wait-secs 7200 --max-secs 3600 --log $L/g_zkpcore.log --done $L/g_zkpcore.done -- \
  cargo test --release --manifest-path $ZC --lib -- m8_ fold eq_table transcript path merkle tree
grep -h "test result\|FAILED\|panicked" $L/g_zkpcore.log | tail -3
grep -q "test result: ok" $L/g_zkpcore.log || exit 1

for tail in default 0; do
  sleep 10
  step bytes-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 60 --cap-gib 160 --label m26scan-bytes-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_bytes_$tail.log --done $L/g_bytes_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
  grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}|test result.*|panicked.*" $L/g_bytes_$tail.log
  for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
    grep -q "M4-ACCURACY-DIGEST $d" $L/g_bytes_$tail.log || { echo "BYTES MOVED: $d"; exit 1; }
  done
  grep -q "test result: ok" $L/g_bytes_$tail.log || exit 1
done

for tail in default 0; do
  sleep 10
  step unit-$tail
  E="env HL_R13_LOADER_FIXTURES=$F"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class cpu --need-gib 8 --cap-gib 40 --label m26scan-unit-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_unit_$tail.log --done $L/g_unit_$tail.done -- \
    $E $B w16_f3_ w16_review review_r2 range16 the_range_tags layout m15_ accuracy_act m6_ m5c_ m4c_ m4d_ m4h_ m4i_ m4j_ s28 s29 slot_ir metal range16 accuracy_layout accuracy_profile
  grep -h "test result\|FAILED\|panicked" $L/g_unit_$tail.log | grep -v "layout.rs:481" | tail -4
  grep -q "test result: ok" $L/g_unit_$tail.log || exit 1
done

sleep 10
step trained
$G --class gpu --need-gib 60 --cap-gib 160 --label m26scan-trained --wait-secs 7200 --max-secs 3000 --log $L/g_trained.log --done $L/g_trained.done -- \
  env HL_GPU_REQUIRED=1 HL_M4_PHASES=1 HL_M4_WARM_PASSES=3 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24 $B --ignored --exact --nocapture --test-threads=1 $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times
grep -h "M4-TRAINED.*metal-warm\|test result\|FAILED\|panicked" $L/g_trained.log | cut -c1-260
grep -q "M4-TRAINED R13_SHIELD_T128_H24 .*digest cpu 2b0d04bb" $L/g_trained.log || { echo "SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED R13_8B_T128_H24 .*digest cpu 678953f6" $L/g_trained.log || { echo "8B DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_SHIELD_T128_H24 .*digest cpu 01a6d51d" $L/g_trained.log || { echo "W16 SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_8B_T128_H24 .*digest cpu c5e0bdac" $L/g_trained.log || { echo "W16 8B DIGEST MOVED"; exit 1; }
grep -q "test result: ok" $L/g_trained.log || exit 1

sleep 10
step r13
$G --class gpu --need-gib 8 --cap-gib 40 --label m26scan-r13 --wait-secs 7200 --max-secs 3000 --log $L/g_r13.log --done $L/g_r13.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies --nocapture --test-threads=1
grep -h "test result\|FAILED\|panicked" $L/g_r13.log | tail -2
grep -q "test result: ok. 1 passed" $L/g_r13.log || exit 1

sleep 10
step golden
python3 $R/results/zk60_metal_20261031/run_golden.py --child --bin $B
cat $R/results/zk60_metal_20261031/logs/golden.done
grep -q "^ALL 0" $R/results/zk60_metal_20261031/logs/golden.done || exit 1

# THE WHOLE LIB SUITE once, no filter (catches any other stale scan); reported, gated last
sleep 10
step full-suite
$G --class cpu --need-gib 24 --cap-gib 160 --label m26scan-full --wait-secs 7200 --max-secs 7200 --log $L/g_full.log --done $L/g_full.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --test-threads=8
grep -h "test result" $L/g_full.log
# the six failures the Mac bring-up records (ZK60_MAC_BRINGUP_20261031.md, the Mac's own environment:
# laptop-only fixtures and receipts, two macOS bugs in production code); any other failure fails here
KNOWN=$(printf '%s\n' \
  private_block::review_tests::a_toy_receipt_made_before_the_lane_still_verifies \
  private_block::token_io::classify_cli::batch::r18::r18_a_rung_batch_proves_every_job_and_each_receipt_verifies_owner_checks_and_labels \
  private_block::token_io::classify_cli::batch::r18::r18_each_batch_job_reloads_every_block_through_its_own_digest_checked_readers \
  private_block::token_io::classify_cli::batch::r18::r18_the_request_reader_refuses_a_symlink_and_a_fifo_without_blocking \
  private_block::trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces \
  private_block::trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name | sort)
GOT=$(grep -E '^test .* \.\.\. FAILED$' $L/g_full.log | awk '{print $2}' | sort)
echo "full-suite failures:"; echo "$GOT"
[ "$GOT" = "$KNOWN" ] || { echo "THE FULL SUITE'S FAILURES ARE NOT EXACTLY THE SIX KNOWN MAC-ENVIRONMENT ONES"; exit 1; }
grep -q "test result: FAILED. [0-9]* passed; 6 failed" $L/g_full.log || { echo "THE FULL SUITE'S TOTALS ARE NOT n/6"; exit 1; }

step done
