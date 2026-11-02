#!/bin/bash
# W16R2 (D59) gate chain (2026-11-01): the opt-in, unregistered rate-1/2 W16 profiles. Template:
# results/zk60_metal_20261031/logs/m27d55/m27d55_gates.sh, re-pointed at this worktree (every path below is
# the worktree's, except the shared resource guard and the R13 loader fixtures, which are the main
# checkout's). Adds: the W16R2 tests in the unit steps, the W16R2 rung's CPU = Metal golden, the W16R2
# trained digests (CPU = Metal) beside W16's and R13's, and one W16R2 run (boundaries and endpoints at rate
# 1/2) through the D12a serial and the D55 fork verifiers. `quick` as $1: build + scans only.
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-ac8a2b43086591196
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_20261101/logs/chain
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
T=private_block::slot_ir::accuracy::tests
MODE=${1:-full}
mkdir -p $L
step() { echo "== $1 $(date +%H:%M:%S)"; }
# the guard APPENDS to a step's log: move any earlier attempt's step logs aside
P=$L/prior-$(date +%Y%m%dT%H%M%S); for f in $L/g_*; do [ -e "$f" ] || continue; mkdir -p $P; mv "$f" $P/; done

step build
$G --class build --need-gib 4 --cap-gib 10 --label w16r2-build --wait-secs 7200 --max-secs 3600 --log $L/g_build.log --done $L/g_build.done -- \
  bash -c "cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --offline --locked --manifest-path $H --lib --tests" \
  || { grep -E -A12 '^(error|warning)' $L/g_build.log | tail -60; exit 1; }
grep -c "^warning" $L/g_build.log
# the no-feature `cargo check --tests` is the second half of the build step: it must have finished
[ "$(grep -c 'Finished' $L/g_build.log)" -ge 2 ] || { echo "THE BUILD LOG HAS NOT BOTH FINISHED LINES (gpu-metal test build, no-feature check)"; exit 1; }
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/g_build.log | tail -1)
[ -n "$REL" ] || { echo "NO TEST BINARY IN THE BUILD LOG"; exit 1; }
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
echo "B=$B"
ls -la $B || exit 1
echo "$B" > $L/binary.path
shasum -a 256 $B | tee $L/binary.sha256

# THE SCANS: m27d55's set (58 tests), which now also carry the W16R2 profiles (s24's opt-in list, s25's
# W-2 census and TEST_ONLY_FILES, s33's J-7a premise and lemma)
sleep 5
step scans
$G --class cpu --need-gib 4 --cap-gib 20 --label w16r2-scans --wait-secs 7200 --max-secs 3000 --log $L/g_scans.log --done $L/g_scans.done -- \
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
  "s25_tests::the_generator_is_never_cloned_and_each_prover_constructs_exactly_one" \
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
# the printed census lines, for the record (the D55 rows and the W16R2 profiles among them)
$G --class cpu --need-gib 4 --cap-gib 20 --label w16r2-scans-print --wait-secs 7200 --max-secs 3000 --log $L/g_scans_print.log --done $L/g_scans_print.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B r19b s24 s25 absorb s33 hash_domain:: --nocapture --test-threads=1
grep -h "^S24 \|^S25 W-7\|^S25 W-8\|^S25 W-11\|^S25 W-2\|^TOKEN-IO R1[89]\|^TOKEN-IO R19b\|^S33 J-7a\|^D55 F3\|test result" $L/g_scans_print.log | cut -c1-400
grep -q "test result: ok. 58 passed; 0 failed" $L/g_scans_print.log || exit 1
# (unanchored: under --test-threads=1 a test's first stderr line shares the `test ... ` line)
for d in "S25 W-8(7) D55:" "S25 W-8(5) D55" "S25 W-2 D55:" "D55 F3 label scan:" "D55 fork-run profile strings" "D55 fork-run constructor domains"; do
  grep -q "$d" $L/g_scans_print.log || { echo "A D55 SCAN LINE IS MISSING: $d"; exit 1; }
done
# the W-2 census measured each W16R2 profile (its own table of hash input kinds)
for p in private-block-rung-lh-t32-w16r2-d/1 private-block-shieldstral-3b-t128-lh24-w16r2/1 private-block-llama-3-8b-t128-lh-w16r2/1; do
  grep -q -- "--- hashline-zk-mr1/$p (" $L/g_scans_print.log || { echo "THE W-2 CENSUS DID NOT MEASURE $p"; exit 1; }
done
[ "$MODE" = quick ] && { step quick-done; exit 0; }

sleep 10
step zkp-core
ZC=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
$G --class build --need-gib 4 --cap-gib 10 --label w16r2-zkpcore --wait-secs 7200 --max-secs 3600 --log $L/g_zkpcore.log --done $L/g_zkpcore.done -- \
  cargo test --release --offline --locked --manifest-path $ZC --lib -- m8_ fold eq_table transcript path merkle tree
grep -h "test result\|FAILED\|panicked" $L/g_zkpcore.log | tail -3
grep -q "test result: ok" $L/g_zkpcore.log || exit 1

# ---- D55: the prototype's own tests (F1, F2, F3-F5 stats), on the CPU and with the Metal device: unchanged
for arm in cpu metal; do
  sleep 10
  step d55-$arm
  if [ $arm = metal ]; then E="env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F"; C=gpu; else E="env HL_R13_LOADER_FIXTURES=$F"; C=cpu; fi
  $G --class $C --need-gib 8 --cap-gib 40 --label w16r2-d55-$arm --wait-secs 7200 --max-secs 3000 --log $L/g_d55_$arm.log --done $L/g_d55_$arm.done -- \
    $E $B private_block::run::fork:: --nocapture --test-threads=1
  grep -h "D55 \|test result\|FAILED\|panicked" $L/g_d55_$arm.log | cut -c1-400
  grep -q "test result: ok. 10 passed; 0 failed; 1 ignored" $L/g_d55_$arm.log || exit 1
  grep -q "D55 F1 TAMPER | all 27 families rejected by verify_run_with_forks, 27 of them inside fork 1" $L/g_d55_$arm.log || { echo "F1 TAMPER LINE MISSING"; exit 1; }
done

# ---- D55: one honest fork run captured (F5) and the W16 gate's Rust checks on it: unchanged
sleep 10
step d55-capture
$G --class cpu --need-gib 8 --cap-gib 40 --label w16r2-capture --wait-secs 7200 --max-secs 3000 --log $L/g_d55_capture.log --done $L/g_d55_capture.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --exact private_block::w16_privacy_gate_tests::d55_fork_run_capture_passes_the_w16_gate_checks_at_the_development_rung --nocapture --test-threads=1
grep -h "^W16-PG\|test result\|FAILED\|panicked" $L/g_d55_capture.log | cut -c1-300
grep -q "W16-PG VERDICT 20 checks, all PASS" $L/g_d55_capture.log || exit 1
grep -q "test result: ok. 1 passed" $L/g_d55_capture.log || exit 1

# ---- D12a's blocks-only R13 run test (two stages, two gate denominators): unchanged
sleep 10
step d12a-run
$G --class cpu --need-gib 8 --cap-gib 40 --label w16r2-d12a-run --wait-secs 7200 --max-secs 3000 --log $L/g_d12a_run.log --done $L/g_d12a_run.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --ignored --exact private_block::accuracy_proof_tests::accuracy_two_stage_private_boundary_with_different_gate_shifts_verifies --nocapture --test-threads=1
grep -h "R13 two-stage\|test result\|FAILED\|panicked" $L/g_d12a_run.log | tail -3
grep -q "test result: ok. 1 passed" $L/g_d12a_run.log || exit 1

for tail in default 0; do
  sleep 10
  step bytes-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 60 --cap-gib 160 --label w16r2-bytes-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_bytes_$tail.log --done $L/g_bytes_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
  grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}|test result.*|panicked.*" $L/g_bytes_$tail.log
  for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
    grep -q "M4-ACCURACY-DIGEST $d" $L/g_bytes_$tail.log || { echo "BYTES MOVED: $d"; exit 1; }
  done
  grep -q "test result: ok" $L/g_bytes_$tail.log || exit 1
done

# ---- the W16R2 rung: its pinned golden, CPU = Metal, in both batch-tail modes
for tail in default 0; do
  sleep 10
  step w16r2-rung-metal-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 8 --cap-gib 40 --label w16r2-rung-metal-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_r2rung_$tail.log --done $L/g_r2rung_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden
  grep -h -o -E "W16R2-RUNG-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}[0-9a-f]* metal [0-9a-f]{8}|test result.*|panicked.*" $L/g_r2rung_$tail.log
  grep -q "W16R2-RUNG-DIGEST W16R2_RUNG_H24 cpu 334e168f" $L/g_r2rung_$tail.log || { echo "W16R2 RUNG GOLDEN MOVED"; exit 1; }
  grep -q "test result: ok. 1 passed" $L/g_r2rung_$tail.log || exit 1
done

for tail in default 0; do
  sleep 10
  step unit-$tail
  E="env HL_R13_LOADER_FIXTURES=$F"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class cpu --need-gib 8 --cap-gib 40 --label w16r2-unit-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_unit_$tail.log --done $L/g_unit_$tail.done -- \
    $E $B w16_f3_ w16_review review_r2 range16 the_range_tags layout m15_ accuracy_act m6_ m5c_ m4c_ m4d_ m4h_ m4i_ m4j_ s28 s29 slot_ir metal range16 accuracy_layout accuracy_profile w16r2_
  grep -h "test result\|FAILED\|panicked" $L/g_unit_$tail.log | grep -v "layout.rs:481" | tail -4
  grep -q "test result: ok" $L/g_unit_$tail.log || exit 1
  # the W16R2 set itself: 15 tests run, 2 ignored (the Metal golden above and the A/B), every one ok
  [ "$(grep -c '^test private_block::w16r2_tests::.* \.\.\. ok$' $L/g_unit_$tail.log)" = 15 ] || { echo "THE W16R2 SET IS NOT 15 OK"; exit 1; }
done

sleep 10
step trained
$G --class gpu --need-gib 60 --cap-gib 160 --label w16r2-trained --wait-secs 7200 --max-secs 3000 --log $L/g_trained.log --done $L/g_trained.done -- \
  env HL_GPU_REQUIRED=1 HL_M4_PHASES=1 HL_M4_WARM_PASSES=3 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24,W16R2_RUNG_H24 $B --ignored --exact --nocapture --test-threads=1 $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times
grep -h "M4-TRAINED.*metal-warm\|test result\|FAILED\|panicked" $L/g_trained.log | cut -c1-260
grep -q "M4-TRAINED R13_SHIELD_T128_H24 .*digest cpu 2b0d04bb" $L/g_trained.log || { echo "SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED R13_8B_T128_H24 .*digest cpu 678953f6" $L/g_trained.log || { echo "8B DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_SHIELD_T128_H24 .*digest cpu 01a6d51d" $L/g_trained.log || { echo "W16 SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_8B_T128_H24 .*digest cpu c5e0bdac" $L/g_trained.log || { echo "W16 8B DIGEST MOVED"; exit 1; }
# the W16R2 digests: CPU = Metal is the test's own assertion at every pass; the values are recorded
grep -h -o -E "M4-TRAINED W16R2_[A-Z0-9_]+ .*metal-warm.*digest cpu [0-9a-f]{8}" $L/g_trained.log | sed -E 's/ \(prove core.*digest cpu / digest cpu /' | sort -u
for p in W16R2_SHIELD_T128_H24 W16R2_8B_T128_H24 W16R2_RUNG_H24; do
  grep -q "M4-TRAINED $p .*metal-warm" $L/g_trained.log || { echo "NO W16R2 TRAINED LINE: $p"; exit 1; }
done
grep -q "test result: ok" $L/g_trained.log || exit 1

sleep 10
step r13
$G --class gpu --need-gib 8 --cap-gib 40 --label w16r2-r13 --wait-secs 7200 --max-secs 3000 --log $L/g_r13.log --done $L/g_r13.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies --nocapture --test-threads=1
grep -h "test result\|FAILED\|panicked" $L/g_r13.log | tail -2
grep -q "test result: ok. 1 passed" $L/g_r13.log || exit 1

# ---- a W16R2 RUN at the rung: three blocks, two internal boundaries and both endpoints at rate 1/2, proved
# and verified by the D12a serial run verifier and by the D55 fork verifier (the D55 A/B harness, L = 3)
sleep 10
step w16r2-run
$G --class gpu --need-gib 8 --cap-gib 40 --label w16r2-run --wait-secs 7200 --max-secs 3000 --log $L/g_r2run.log --done $L/g_r2run.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F HL_D55_PROFILE=W16R2_RUNG_H24 HL_D55_L=3 HL_D55_WORKERS=2 HL_D55_PASSES=1 \
  $B --ignored --exact private_block::run::fork::tests::d55_ab_one_request_serial_against_forks --nocapture --test-threads=1
grep -h "D55-AB\|test result\|FAILED\|panicked" $L/g_r2run.log | cut -c1-300
grep -q "D55-AB W16R2_RUNG_H24 L3 serial: verified" $L/g_r2run.log || { echo "THE W16R2 SERIAL RUN DID NOT VERIFY"; exit 1; }
grep -q "D55-AB W16R2_RUNG_H24 L3 forks N2: verified" $L/g_r2run.log || { echo "THE W16R2 FORK RUN DID NOT VERIFY"; exit 1; }
grep -q "test result: ok. 1 passed" $L/g_r2run.log || exit 1

sleep 10
step golden
python3 $L/run_golden.py --child --bin $B
cat $L/golden/golden.done
grep -q "^ALL 0" $L/golden/golden.done || exit 1

# THE WHOLE LIB SUITE once, no filter; reported, gated last
sleep 10
step full-suite
$G --class cpu --need-gib 24 --cap-gib 160 --label w16r2-full --wait-secs 7200 --max-secs 7200 --log $L/g_full.log --done $L/g_full.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --test-threads=8
grep -h "test result" $L/g_full.log
# the six failures the Mac bring-up records (ZK60_MAC_BRINGUP_20261031.md); any other failure fails here
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
