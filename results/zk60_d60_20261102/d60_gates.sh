#!/bin/bash
# D60 (2026-11-02) gate chain: the D55 "commit, fork, join" run profile REGISTERED (production code, twelve
# registered D55 run profiles over the R13 blocks-only bases). Template: results/zk60_w16r2_20261101/logs/chain/
# w16r2_gates.sh, re-pointed at this worktree (every path below is the worktree's, except the shared resource
# guard and the R13 loader fixtures, which are the main checkout's). Adds: the D60 tests (registry, door, F7,
# the headline and the R13 limb families under the registered profile), the fresh-process test receipts (two
# test-binary processes) and the CLI receipts (cli_receipts.sh). `quick` as $1: build + scans only.
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a13712d1ade4dcee1
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_d60_20261102/logs/chain
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
T=private_block::slot_ir::accuracy::tests
A=/Users/victorrielly/zk60-artifacts/d60_20261102
MODE=${1:-full}
mkdir -p $L
step() { echo "== $1 $(date +%H:%M:%S)"; }
# the guard APPENDS to a step's log: move any earlier attempt's step logs aside. `tail` as $1 RESUMES at the
# trained step on the binary the full run recorded (logs/chain/binary.path) and moves only its own step logs
P=$L/prior-$(date +%Y%m%dT%H%M%S)
if [ "$MODE" = tail ]; then
  for f in $L/g_trained* $L/g_r13* $L/g_r2run* $L/g_full* $L/golden; do [ -e "$f" ] || continue; mkdir -p $P; mv "$f" $P/; done
  B=$(cat $L/binary.path); echo "TAIL: resuming at the trained step, B=$B"
else
for f in $L/g_*; do [ -e "$f" ] || continue; mkdir -p $P; mv "$f" $P/; done

step build
$G --class build --need-gib 4 --cap-gib 10 --label d60-build --wait-secs 7200 --max-secs 3600 --log $L/g_build.log --done $L/g_build.done -- \
  bash -c "cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --offline --locked --manifest-path $H --lib --tests" \
  || { grep -E -A12 '^(error|warning)' $L/g_build.log | tail -60; exit 1; }
W=$(grep -c "^warning" $L/g_build.log); echo "warnings: $W"
[ "$W" -le 134 ] || { echo "NEW COMPILER WARNINGS: $W > 134"; exit 1; }
[ "$(grep -c 'Finished' $L/g_build.log)" -ge 2 ] || { echo "THE BUILD LOG HAS NOT BOTH FINISHED LINES (gpu-metal test build, no-feature check)"; exit 1; }
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/g_build.log | tail -1)
[ -n "$REL" ] || { echo "NO TEST BINARY IN THE BUILD LOG"; exit 1; }
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
echo "B=$B"
ls -la $B || exit 1
echo "$B" > $L/binary.path
shasum -a 256 $B | tee $L/binary.sha256

sleep 5
step scans
$G --class cpu --need-gib 4 --cap-gib 20 --label d60-scans --wait-secs 7200 --max-secs 3000 --log $L/g_scans.log --done $L/g_scans.done -- \
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
$G --class cpu --need-gib 4 --cap-gib 20 --label d60-scans-print --wait-secs 7200 --max-secs 3000 --log $L/g_scans_print.log --done $L/g_scans_print.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B r19b s24 s25 absorb s33 hash_domain:: --nocapture --test-threads=1
grep -h "^S24 \|^S25 W-7\|^S25 W-8\|^S25 W-11\|^S25 W-2\|^TOKEN-IO R1[89]\|^TOKEN-IO R19b\|^S33 J-7a\|^D55 F3\|test result" $L/g_scans_print.log | cut -c1-400
grep -q "test result: ok. 58 passed; 0 failed" $L/g_scans_print.log || exit 1
for d in "S25 W-8(7) D55:" "S25 W-8(5) D55" "S25 W-2 D55:" "D55 F3 label scan:" "D55 fork-run profile strings" "D55 fork-run constructor domains" "the 12 registered D55 run profiles among them"; do
  grep -q "$d" $L/g_scans_print.log || { echo "A D55 SCAN LINE IS MISSING: $d"; exit 1; }
done
# the W-2 census measured each registered D55 profile (its own table of hash input kinds)
for p in private-run-rung-lh-t32-dev/1 private-run-llama-3-8b-t128-lh24-v1-statement/1 private-run-shieldstral-3b-t128-lowh24-blocks-run/1; do
  grep -q -- "--- hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/$p (" $L/g_scans_print.log || { echo "THE W-2 CENSUS DID NOT MEASURE THE REGISTERED D55 PROFILE OVER $p"; exit 1; }
done
[ "$MODE" = quick ] && { step quick-done; exit 0; }

sleep 10
step zkp-core
ZC=$R/ops/zkp-mvp/gpu-metal/zkp-core/Cargo.toml
$G --class build --need-gib 4 --cap-gib 10 --label d60-zkpcore --wait-secs 7200 --max-secs 3600 --log $L/g_zkpcore.log --done $L/g_zkpcore.done -- \
  cargo test --release --offline --locked --manifest-path $ZC --lib -- m8_ fold eq_table transcript path merkle tree
grep -h "test result\|FAILED\|panicked" $L/g_zkpcore.log | tail -3
grep -q "test result: ok" $L/g_zkpcore.log || exit 1

# ---- D55 / D60: the fork run's tests (prototype F1-F5 + D60's), on the CPU and with the Metal device
for arm in cpu metal; do
  sleep 10
  step d55-$arm
  if [ $arm = metal ]; then E="env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F"; C=gpu; else E="env HL_R13_LOADER_FIXTURES=$F"; C=cpu; fi
  $G --class $C --need-gib 8 --cap-gib 40 --label d60-d55-$arm --wait-secs 7200 --max-secs 3600 --log $L/g_d55_$arm.log --done $L/g_d55_$arm.done -- \
    $E $B private_block::run::fork:: --nocapture --test-threads=1
  grep -h "D55 \|D60 \|test result\|FAILED\|panicked" $L/g_d55_$arm.log | cut -c1-400
  grep -q "test result: ok. 18 passed; 0 failed; 3 ignored" $L/g_d55_$arm.log || { echo "THE D55 SET IS NOT 18 OK / 3 IGNORED"; exit 1; }
  grep -q "D60 CAPTURE | the registered R13-rung D55 run's bundle WRITTEN by run_capture::write_bundle" $L/g_d55_$arm.log || { echo "THE D60 CAPTURE LINE IS MISSING"; exit 1; }
  grep -q "D55 F1 TAMPER | all 27 families rejected by verify_run_with_forks, 27 of them inside fork 1" $L/g_d55_$arm.log || { echo "F1 TAMPER LINE MISSING"; exit 1; }
  grep -q "D60 TAMPER | 13 R13 limb families rejected by verify_run_with_forks under hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1, 13 of them inside fork 1" $L/g_d55_$arm.log || { echo "D60 TAMPER LINE MISSING"; exit 1; }
  [ "$(grep -c 'D60 HEADLINE | hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1 | .* | REJECTED by the verifier' $L/g_d55_$arm.log)" = 2 ] || { echo "THE D60 HEADLINE VARIANTS ARE NOT BOTH REJECTED"; exit 1; }
done

# ---- one honest fork run captured (F5) and the W16 gate's Rust checks on it (the W16 rung's TEST-ONLY D55
# identity, through the now-production prover and verifier): unchanged
sleep 10
step d55-capture
$G --class cpu --need-gib 8 --cap-gib 40 --label d60-capture --wait-secs 7200 --max-secs 3000 --log $L/g_d55_capture.log --done $L/g_d55_capture.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --exact private_block::w16_privacy_gate_tests::d55_fork_run_capture_passes_the_w16_gate_checks_at_the_development_rung --nocapture --test-threads=1
grep -h "^W16-PG\|test result\|FAILED\|panicked" $L/g_d55_capture.log | cut -c1-300
grep -q "W16-PG VERDICT 20 checks, all PASS" $L/g_d55_capture.log || exit 1
grep -q "test result: ok. 1 passed" $L/g_d55_capture.log || exit 1

# ---- D60: the FRESH-PROCESS test receipts, two separate test-binary processes (write, then verify)
sleep 5
step fresh-process
rm -rf $A/test-binary
for half in write verify; do
  $G --class cpu --need-gib 8 --cap-gib 40 --label d60-fresh-$half --wait-secs 7200 --max-secs 3000 --log $L/g_fresh_$half.log --done $L/g_fresh_$half.done -- \
    env HL_R13_LOADER_FIXTURES=$F HL_D60_RECEIPT_DIR=$A/test-binary $B --ignored --exact private_block::run::fork::tests::d60_fresh_process_${half}_test_receipts --nocapture --test-threads=1
  grep -h "D60 FRESH\|test result\|FAILED\|panicked" $L/g_fresh_$half.log | cut -c1-300
  grep -q "test result: ok. 1 passed" $L/g_fresh_$half.log || exit 1
done
cp $A/test-binary/MANIFEST.txt $L/g_fresh_manifest.txt
grep -q "the D12a receipt VERIFIES under D12a; all four cross-checks refused" $L/g_fresh_verify.log || exit 1

# ---- D60: the CLI receipts (stack-prove / stack-verify), fresh processes
sleep 5
step cli
rm -rf $A/cli
bash $R/results/zk60_d60_20261102/cli_receipts.sh > $L/g_cli.log 2>&1; echo $? > $L/g_cli.done
tail -40 $L/g_cli.log
[ "$(cat $L/g_cli.done)" = 0 ] || exit 1

# ---- D12a's blocks-only R13 run test (two stages, two gate denominators): unchanged
sleep 10
step d12a-run
$G --class cpu --need-gib 8 --cap-gib 40 --label d60-d12a-run --wait-secs 7200 --max-secs 3000 --log $L/g_d12a_run.log --done $L/g_d12a_run.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --ignored --exact private_block::accuracy_proof_tests::accuracy_two_stage_private_boundary_with_different_gate_shifts_verifies --nocapture --test-threads=1
grep -h "R13 two-stage\|test result\|FAILED\|panicked" $L/g_d12a_run.log | tail -3
grep -q "test result: ok. 1 passed" $L/g_d12a_run.log || exit 1

for tail in default 0; do
  sleep 10
  step bytes-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 60 --cap-gib 160 --label d60-bytes-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_bytes_$tail.log --done $L/g_bytes_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
  grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}|test result.*|panicked.*" $L/g_bytes_$tail.log
  for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
    grep -q "M4-ACCURACY-DIGEST $d" $L/g_bytes_$tail.log || { echo "BYTES MOVED: $d"; exit 1; }
  done
  grep -q "test result: ok" $L/g_bytes_$tail.log || exit 1
done

# ---- the W16R2 rung's pinned golden, CPU = Metal (unchanged by D60)
for tail in default 0; do
  sleep 10
  step w16r2-rung-metal-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 8 --cap-gib 40 --label d60-r2rung-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_r2rung_$tail.log --done $L/g_r2rung_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden
  grep -h -o -E "W16R2-RUNG-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}[0-9a-f]* metal [0-9a-f]{8}|test result.*|panicked.*" $L/g_r2rung_$tail.log
  grep -q "W16R2-RUNG-DIGEST W16R2_RUNG_H24 cpu 334e168f" $L/g_r2rung_$tail.log || { echo "W16R2 RUNG GOLDEN MOVED"; exit 1; }
  grep -q "test result: ok. 1 passed" $L/g_r2rung_$tail.log || exit 1
done

for tail in default 0; do
  sleep 10
  step unit-$tail
  E="env HL_R13_LOADER_FIXTURES=$F"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class cpu --need-gib 8 --cap-gib 40 --label d60-unit-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_unit_$tail.log --done $L/g_unit_$tail.done -- \
    $E $B w16_f3_ w16_review review_r2 range16 the_range_tags layout m15_ accuracy_act m6_ m5c_ m4c_ m4d_ m4h_ m4i_ m4j_ s28 s29 slot_ir metal range16 accuracy_layout accuracy_profile w16r2_
  grep -h "test result\|FAILED\|panicked" $L/g_unit_$tail.log | grep -v "layout.rs:481" | tail -4
  grep -q "test result: ok" $L/g_unit_$tail.log || exit 1
done

fi # (the tail resumes here)
sleep 10
step trained
$G --class gpu --need-gib 60 --cap-gib 160 --label d60-trained --wait-secs 7200 --max-secs 3000 --log $L/g_trained.log --done $L/g_trained.done -- \
  env HL_GPU_REQUIRED=1 HL_M4_PHASES=1 HL_M4_WARM_PASSES=3 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24,W16R2_RUNG_H24 $B --ignored --exact --nocapture --test-threads=1 $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times
grep -h "M4-TRAINED.*metal-warm\|test result\|FAILED\|panicked" $L/g_trained.log | cut -c1-260
grep -q "M4-TRAINED R13_SHIELD_T128_H24 .*digest cpu 2b0d04bb" $L/g_trained.log || { echo "SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED R13_8B_T128_H24 .*digest cpu 678953f6" $L/g_trained.log || { echo "8B DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_SHIELD_T128_H24 .*digest cpu 01a6d51d" $L/g_trained.log || { echo "W16 SHIELD DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16_8B_T128_H24 .*digest cpu c5e0bdac" $L/g_trained.log || { echo "W16 8B DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16R2_8B_T128_H24 .*digest cpu 5343008a" $L/g_trained.log || { echo "W16R2 8B DIGEST MOVED"; exit 1; }
grep -q "M4-TRAINED W16R2_SHIELD_T128_H24 .*digest cpu e0bb5917" $L/g_trained.log || { echo "W16R2 SHIELD DIGEST MOVED"; exit 1; }
# (the trained test's W16R2 rung digest is its own recipe's, d6879fae as the W16R2 chain recorded it; the rung
# GOLDEN 334e168f is the w16r2-rung-metal steps' above)
grep -q "M4-TRAINED W16R2_RUNG_H24 .*digest cpu d6879fae" $L/g_trained.log || { echo "W16R2 RUNG TRAINED DIGEST MOVED"; exit 1; }
grep -q "test result: ok" $L/g_trained.log || exit 1

sleep 10
step r13
$G --class gpu --need-gib 8 --cap-gib 40 --label d60-r13 --wait-secs 7200 --max-secs 3000 --log $L/g_r13.log --done $L/g_r13.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies --nocapture --test-threads=1
grep -h "test result\|FAILED\|panicked" $L/g_r13.log | tail -2
grep -q "test result: ok. 1 passed" $L/g_r13.log || exit 1

# ---- a W16R2 RUN at the rung through the D12a serial and the D55 fork verifiers (the A/B harness, L = 3; the
# W16R2 base's TEST-ONLY D55 identity): unchanged
sleep 10
step w16r2-run
$G --class gpu --need-gib 8 --cap-gib 40 --label d60-r2run --wait-secs 7200 --max-secs 3000 --log $L/g_r2run.log --done $L/g_r2run.done -- \
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
$G --class cpu --need-gib 24 --cap-gib 160 --label d60-full --wait-secs 7200 --max-secs 7200 --log $L/g_full.log --done $L/g_full.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --test-threads=8
grep -h "test result" $L/g_full.log
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
