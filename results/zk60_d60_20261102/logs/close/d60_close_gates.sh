#!/bin/bash
# D60 review closure gate chain (2026-11-02): REVIEW_D60_20261102.md findings F1-F9. Copied from
# results/zk60_w16r2_20261101/logs/close/w16r2_close_gates.sh and ../chain/d60_gates.sh, re-pointed at this
# worktree (every path below is the worktree's, except the shared resource guard and the R13 loader fixtures,
# which are the main checkout's). Changes against those chains:
#  * merged with perf/zk-batch-optimizations at 05490b79 (the D60 privacy gate on registered R13 fork bundles);
#  * the D55 / D60 set is 23 passed / 7 ignored (18 + F1, F3, F4, F7, F8; ignored 3 + the two F2 tools, the F5
#    block-size probe and the privacy gate's bundle writer), each
#    new test's printed line checked, on the CPU and with the Metal device;
#  * the CLI step is cli_close.sh (L = 3 / N = 3 on the release CLI, the cross-binary check both ways, the
#    tamper probes at L = 3, the F3 fail-closed rule on the release binary, F5's peak memory);
#  * the full suite must fail at most the six known Mac-only tests (F4 gives the token batch reader its macOS
#    O_NOFOLLOW / O_NONBLOCK values, so the three r18 tests that failed only on their absence may now pass);
#  * warnings <= 133 (the D60 chain's count method over the build log).
# `quick` as $1: build + scans only.
set -u
export ZK60_GUARD_POLL_SECS=0.05
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a2e328baa581cb5b0
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
C=$R/results/zk60_d60_20261102/logs/close
L=$C/chain
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
T=private_block::slot_ir::accuracy::tests
A=/Users/victorrielly/zk60-artifacts/d60_20261102/close
MODE=${1:-full}
mkdir -p $L
step() { echo "== $1 $(date +%H:%M:%S)"; }
P=$L/prior-$(date +%Y%m%dT%H%M%S); for f in $L/g_*; do [ -e "$f" ] || continue; mkdir -p $P; mv "$f" $P/; done

step build
$G --class build --need-gib 4 --cap-gib 10 --label d60close-build --wait-secs 7200 --max-secs 3600 --log $L/g_build.log --done $L/g_build.done -- \
  bash -c "cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --offline --locked --manifest-path $H --lib --tests" \
  || { grep -E -A12 '^(error|warning)' $L/g_build.log | tail -60; exit 1; }
W=$(grep -c "^warning" $L/g_build.log); echo "warnings: $W"
[ "$(grep -c 'Finished' $L/g_build.log)" -ge 2 ] || { echo "THE BUILD LOG HAS NOT BOTH FINISHED LINES (gpu-metal test build, no-feature check)"; exit 1; }
[ "$W" -le 133 ] || { echo "NEW COMPILER WARNINGS: $W > 133"; exit 1; }
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/g_build.log | tail -1)
[ -n "$REL" ] || { echo "NO TEST BINARY IN THE BUILD LOG"; exit 1; }
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
echo "B=$B"
ls -la $B || exit 1
echo "$B" > $L/binary.path
shasum -a 256 $B | tee $L/binary.sha256
$G --class build --need-gib 4 --cap-gib 10 --label d60close-build-cli --wait-secs 7200 --max-secs 3600 --log $L/g_build_cli.log --done $L/g_build_cli.done -- \
  cargo build --release --offline --locked --features gpu-metal --manifest-path $H --example zk60_trained_block || exit 1
shasum -a 256 $R/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_trained_block | tee $L/cli_binary.sha256

sleep 5
step scans
$G --class cpu --need-gib 4 --cap-gib 20 --label d60close-scans --wait-secs 7200 --max-secs 3000 --log $L/g_scans.log --done $L/g_scans.done -- \
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
$G --class cpu --need-gib 4 --cap-gib 20 --label d60close-scans-print --wait-secs 7200 --max-secs 3000 --log $L/g_scans_print.log --done $L/g_scans_print.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B r19b s24 s25 absorb s33 hash_domain:: --nocapture --test-threads=1
grep -q "test result: ok. 58 passed; 0 failed" $L/g_scans_print.log || exit 1
for d in "S25 W-8(7) D55:" "S25 W-8(5) D55" "S25 W-2 D55:" "D55 F3 label scan:" "D55 fork-run profile strings" "D55 fork-run constructor domains" "the 12 registered D55 run profiles among them"; do
  grep -q "$d" $L/g_scans_print.log || { echo "A D55 SCAN LINE IS MISSING: $d"; exit 1; }
done
[ "$MODE" = quick ] && { step quick-done; exit 0; }

# ---- D55 / D60: the fork run's tests (prototype F1-F5, D60's, and this closure's F1/F3/F4/F7/F8), CPU and Metal
for arm in cpu metal; do
  sleep 5
  step d55-$arm
  if [ $arm = metal ]; then E="env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F"; CL=gpu; else E="env HL_R13_LOADER_FIXTURES=$F"; CL=cpu; fi
  $G --class $CL --need-gib 8 --cap-gib 40 --label d60close-d55-$arm --wait-secs 7200 --max-secs 3600 --log $L/g_d55_$arm.log --done $L/g_d55_$arm.done -- \
    $E $B private_block::run::fork:: --nocapture --test-threads=1
  grep -h "D60 F[13478] \|test result\|FAILED\|panicked" $L/g_d55_$arm.log | grep -v "D60 F8 test switch" | cut -c1-300
  grep -q "test result: ok. 23 passed; 0 failed; 7 ignored" $L/g_d55_$arm.log || { echo "THE D55 SET IS NOT 23 OK / 7 IGNORED"; exit 1; }
  grep -q "D60 CAPTURE | the registered R13-rung D55 run's bundle WRITTEN by run_capture::write_bundle" $L/g_d55_$arm.log || { echo "THE D60 CAPTURE LINE IS MISSING"; exit 1; }
  grep -q "D55 F1 TAMPER | all 27 families rejected by verify_run_with_forks, 27 of them inside fork 1" $L/g_d55_$arm.log || { echo "F1 TAMPER LINE MISSING"; exit 1; }
  grep -q "D60 TAMPER | 13 R13 limb families rejected by verify_run_with_forks under hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1, 13 of them inside fork 1" $L/g_d55_$arm.log || { echo "D60 TAMPER LINE MISSING"; exit 1; }
  [ "$(grep -c 'D60 HEADLINE | hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/private-run-rung-lh-t32-dev/1 | .* | REJECTED by the verifier' $L/g_d55_$arm.log)" = 2 ] || { echo "THE D60 HEADLINE VARIANTS ARE NOT BOTH REJECTED"; exit 1; }
  # this closure's tests
  # (no ^ anchor: a test's first printed line follows its `test … … ` name on the same line)
  [ "$(grep -c 'D60 F1 | .* | REFUSED' $L/g_d55_$arm.log)" = 10 ] || { echo "F1: NOT EVERY PREFLIGHT CASE WAS REFUSED"; exit 1; }
  grep -q "D60 F3 | stack-prove --d55-workers 1 without --d55-test-receipt-not-for-publication: REFUSED, nothing created" $L/g_d55_$arm.log || { echo "F3 REFUSAL LINE MISSING"; exit 1; }
  grep -q '"event":"d55-publication","not_for_publication":true,"test_receipt_marker":"present"' $L/g_d55_$arm.log || { echo "F3: THE MARKER WAS NOT REPORTED PRESENT"; exit 1; }
  grep -q '"event":"d55-publication","not_for_publication":true,"test_receipt_marker":"ABSENT"' $L/g_d55_$arm.log || { echo "F3: A MISSING MARKER WAS NOT REPORTED ABSENT"; exit 1; }
  [ "$(grep -c 'D60 F4 | .* | REFUSED without hanging' $L/g_d55_$arm.log)" = 8 ] || { echo "F4: NOT ALL 8 SWAPS REFUSED"; exit 1; }
  [ "$(grep -c 'D60 F7 | .* | REFUSED by the reader at that header' $L/g_d55_$arm.log)" = 5 ] || { echo "F7: NOT ALL 5 HEADER CASES REFUSED"; exit 1; }
  grep -q "D60 F8 | every fork worker panics (L3, 2 workers) | the prover FAILS" $L/g_d55_$arm.log || { echo "F8 LINE MISSING"; exit 1; }
done

# ---- one honest fork run captured and the W16 gate's Rust checks on it (unchanged)
sleep 5
step d55-capture
$G --class cpu --need-gib 8 --cap-gib 40 --label d60close-capture --wait-secs 7200 --max-secs 3000 --log $L/g_d55_capture.log --done $L/g_d55_capture.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --exact private_block::w16_privacy_gate_tests::d55_fork_run_capture_passes_the_w16_gate_checks_at_the_development_rung --nocapture --test-threads=1
grep -q "W16-PG VERDICT 20 checks, all PASS" $L/g_d55_capture.log || exit 1
grep -q "test result: ok. 1 passed" $L/g_d55_capture.log || exit 1

# ---- the fresh-process test receipts, two separate test-binary processes (write, then verify): unchanged
sleep 5
step fresh-process
mkdir -p $A
FD=$A/test-binary-$(date +%Y%m%dT%H%M%S)
for half in write verify; do
  $G --class cpu --need-gib 8 --cap-gib 40 --label d60close-fresh-$half --wait-secs 7200 --max-secs 3000 --log $L/g_fresh_$half.log --done $L/g_fresh_$half.done -- \
    env HL_R13_LOADER_FIXTURES=$F HL_D60_RECEIPT_DIR=$FD $B --ignored --exact private_block::run::fork::tests::d60_fresh_process_${half}_test_receipts --nocapture --test-threads=1
  grep -q "test result: ok. 1 passed" $L/g_fresh_$half.log || exit 1
done
grep -q "the D12a receipt VERIFIES under D12a; all four cross-checks refused" $L/g_fresh_verify.log || exit 1

# ---- the CLI closure: F2 (L = 3, N = 3, cross-binary, probes), F3 on the release binary, F5 memory
sleep 5
step cli
bash $C/cli_close.sh $B > $L/g_cli.log 2>&1; echo $? > $L/g_cli.done
tail -60 $L/g_cli.log
[ "$(cat $L/g_cli.done)" = 0 ] || exit 1

# ---- the Python D55 gate (read-only, the merged staging_v25) on REGISTERED R13-rung bundles written by THIS
# build (whose run.json now describes the run as registered): both hidden inputs, each with its pair; then the
# gate's own unit tests on the pair
sleep 5
step pygate
PY=/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/01ce547c-a1e2-4e9f-8e3d-f16c477ac05b/scratchpad/gatevenv/bin/python3
S=$R/ops/zkp-mvp/gate-tinyllama/staging_v25
PG=$A/pg-$(date +%Y%m%dT%H%M%S)
mkdir -p $PG/evidence
$G --class cpu --need-gib 8 --cap-gib 40 --label d60close-pg-write --wait-secs 7200 --max-secs 3000 --log $L/g_pg_write.log --done $L/g_pg_write.done -- \
  env HL_R13_LOADER_FIXTURES=$F HL_D60PG_CAPTURE_DIR=$PG/bundles HL_D60PG_CASES=R13_RUNG_H24:0,R13_RUNG_H24:1 $B --ignored --exact private_block::run::fork::tests::d60_privacy_gate_write_registered_r13_fork_bundles --nocapture --test-threads=1
grep -q "test result: ok. 1 passed" $L/g_pg_write.log || { echo "THE REGISTERED BUNDLES WERE NOT WRITTEN"; exit 1; }
grep -h -o '"transcript_program":\["[^"]*' $PG/bundles/d55-r13_rung_h24-s0/run.json | cut -c1-140
for s in 0 1; do
  o=$((1 - s))
  $G --class cpu --need-gib 4 --cap-gib 24 --label d60close-pg-py-s$s --wait-secs 7200 --max-secs 3600 --log $L/g_pg_py_s$s.log --done $L/g_pg_py_s$s.done -- \
    $PY -B $S/scripts/zk60_native_rg_d55.py --bundle $PG/bundles/d55-r13_rung_h24-s$s --evidence $PG/evidence --name close-r13-rung-s$s --other $PG/bundles/d55-r13_rung_h24-s$o
  grep -h "status:" $L/g_pg_py_s$s.log | cut -c1-200
  grep -q "status: D55-DEV-PASS" $L/g_pg_py_s$s.log || { echo "THE PYTHON D55 GATE DID NOT PASS ON s$s"; exit 1; }
done
$G --class cpu --need-gib 4 --cap-gib 24 --label d60close-pg-unittest --wait-secs 7200 --max-secs 3600 --log $L/g_pg_unittest.log --done $L/g_pg_unittest.done -- \
  env ZK60_D55_R13_BUNDLE=$PG/bundles/d55-r13_rung_h24-s0 ZK60_D55_R13_OTHER=$PG/bundles/d55-r13_rung_h24-s1 $PY -B -m unittest discover -s $S/tests -p test_d55_r13_gate.py -v
tail -4 $L/g_pg_unittest.log
grep -q "^OK" $L/g_pg_unittest.log || { echo "THE GATE'S D55 R13 TESTS DID NOT PASS"; exit 1; }
grep -E "skipped" $L/g_pg_unittest.log | head -3

# ---- D12a's blocks-only R13 run test (two stages, two gate denominators): unchanged
sleep 5
step d12a-run
$G --class cpu --need-gib 8 --cap-gib 40 --label d60close-d12a-run --wait-secs 7200 --max-secs 3000 --log $L/g_d12a_run.log --done $L/g_d12a_run.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --ignored --exact private_block::accuracy_proof_tests::accuracy_two_stage_private_boundary_with_different_gate_shifts_verifies --nocapture --test-threads=1
grep -q "test result: ok. 1 passed" $L/g_d12a_run.log || exit 1

for tail in default 0; do
  sleep 5
  step bytes-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 60 --cap-gib 160 --label d60close-bytes-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_bytes_$tail.log --done $L/g_bytes_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 $T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
  grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}|test result.*|panicked.*" $L/g_bytes_$tail.log
  for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
    grep -q "M4-ACCURACY-DIGEST $d" $L/g_bytes_$tail.log || { echo "BYTES MOVED: $d"; exit 1; }
  done
  grep -q "test result: ok" $L/g_bytes_$tail.log || exit 1
done

for tail in default 0; do
  sleep 5
  step w16r2-rung-metal-$tail
  E="env HL_GPU_REQUIRED=1"; [ $tail = 0 ] && E="$E HL_METAL_BATCH_TAIL_US=0"
  $G --class gpu --need-gib 8 --cap-gib 40 --label d60close-r2rung-$tail --wait-secs 7200 --max-secs 3000 --log $L/g_r2rung_$tail.log --done $L/g_r2rung_$tail.done -- \
    $E HL_METAL_TIMING=0 $B --ignored --exact --nocapture --test-threads=1 private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden
  grep -q "W16R2-RUNG-DIGEST W16R2_RUNG_H24 cpu 334e168f" $L/g_r2rung_$tail.log || { echo "W16R2 RUNG GOLDEN MOVED"; exit 1; }
  grep -q "test result: ok. 1 passed" $L/g_r2rung_$tail.log || exit 1
done

sleep 5
step trained
$G --class gpu --need-gib 60 --cap-gib 160 --label d60close-trained --wait-secs 7200 --max-secs 3000 --log $L/g_trained.log --done $L/g_trained.done -- \
  env HL_GPU_REQUIRED=1 HL_M4_PHASES=1 HL_M4_WARM_PASSES=3 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24,W16R2_RUNG_H24 $B --ignored --exact --nocapture --test-threads=1 $T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times
grep -h "M4-TRAINED.*metal-warm\|test result\|FAILED\|panicked" $L/g_trained.log | cut -c1-260
for pd in "R13_SHIELD_T128_H24 2b0d04bb" "R13_8B_T128_H24 678953f6" "W16_SHIELD_T128_H24 01a6d51d" "W16_8B_T128_H24 c5e0bdac" "W16R2_8B_T128_H24 5343008a" "W16R2_SHIELD_T128_H24 e0bb5917" "W16R2_RUNG_H24 d6879fae"; do
  set -- $pd
  grep -q "M4-TRAINED $1 .*digest cpu $2" $L/g_trained.log || { echo "TRAINED DIGEST MOVED: $1 (want $2)"; exit 1; }
  n=$(grep -c "M4-TRAINED $1 cpu .*digest cpu $2[0-9a-f]* metal $2" $L/g_trained.log)
  echo "trained: $1 digest cpu = metal $2 at $n passes"
done
grep -q "test result: ok" $L/g_trained.log || exit 1

sleep 5
step r13
$G --class gpu --need-gib 8 --cap-gib 40 --label d60close-r13 --wait-secs 7200 --max-secs 3000 --log $L/g_r13.log --done $L/g_r13.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B r16_an_r13_classifier_run_with_two_gate_denominators_proves_and_verifies --nocapture --test-threads=1
grep -q "test result: ok. 1 passed" $L/g_r13.log || exit 1

sleep 5
step w16r2-run
$G --class gpu --need-gib 8 --cap-gib 40 --label d60close-r2run --wait-secs 7200 --max-secs 3000 --log $L/g_r2run.log --done $L/g_r2run.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F HL_D55_PROFILE=W16R2_RUNG_H24 HL_D55_L=3 HL_D55_WORKERS=2 HL_D55_PASSES=1 \
  $B --ignored --exact private_block::run::fork::tests::d55_ab_one_request_serial_against_forks --nocapture --test-threads=1
grep -q "D55-AB W16R2_RUNG_H24 L3 serial: verified" $L/g_r2run.log || { echo "THE W16R2 SERIAL RUN DID NOT VERIFY"; exit 1; }
grep -q "D55-AB W16R2_RUNG_H24 L3 forks N2: verified" $L/g_r2run.log || { echo "THE W16R2 FORK RUN DID NOT VERIFY"; exit 1; }
grep -q "test result: ok. 1 passed" $L/g_r2run.log || exit 1

sleep 5
step golden
python3 $C/run_golden.py --child --bin $B
cat $C/golden/golden.done
grep -q "^ALL 0" $C/golden/golden.done || exit 1

# THE WHOLE LIB SUITE once, no filter; gated last: its failures must be among the six known Mac-only ones
sleep 5
step full-suite
$G --class cpu --need-gib 24 --cap-gib 160 --label d60close-full --wait-secs 7200 --max-secs 7200 --log $L/g_full.log --done $L/g_full.done -- \
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
NEW=$(comm -13 <(echo "$KNOWN") <(echo "$GOT") | grep -v '^$')
[ -z "$NEW" ] || { echo "THE FULL SUITE FAILS TESTS OUTSIDE THE SIX KNOWN MAC-ENVIRONMENT ONES: $NEW"; exit 1; }
echo "now passing among the known six:"; comm -23 <(echo "$KNOWN") <(echo "$GOT")
grep -q "test result: .* passed; [0-6] failed" $L/g_full.log || { echo "THE FULL SUITE'S TOTALS ARE NOT n/<=6"; exit 1; }

step done
