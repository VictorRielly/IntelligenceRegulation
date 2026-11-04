#!/bin/bash
# W16R2 Q = 280 (D59 F2 ruling) + review F6: build, targeted tests, dev bytes, the new W16R2 goldens (CPU = Metal),
# the W16R2 privacy controls / PG-R2 gate checks, the recount on the code's own printed inputs.
# Template: results/zk60_metal_20261031/logs/m32lanes/m32_merge.sh (build / targeted / bytes), plus the W16R2 steps of
# results/zk60_w16r2_20261101/logs/close/w16r2_close_gates.sh. Every leaf goes through the resource guard.
# The heavy lock is contested by the merged privacy-gate queue, so the steps are few: (1) build, (2) CPU targeted with
# output, (3) Metal targeted (m32's set), (4) one gpu-class bundle of short by-name runs. A failed check is recorded
# and the chain goes on (each lock wait is long); the exit code is the number of failed checks.
# The full suite is NOT here: q280_deferred.sh runs it after the gate queue's follow-up checks.
set -u
export ZK60_GUARD_POLL_SECS=0.5
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a7e40cbdbbf3f1b5d
G="python3 /Users/victorrielly/IntelligenceRegulation/scripts/zk60_resource_guard.py run"
L=$R/results/zk60_w16r2_q280_20261103/logs
H=$R/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml
F=/Users/victorrielly/IntelligenceRegulation/results/zk60_1b_native_20261017/r13/loader-fixtures
T=private_block::slot_ir::accuracy::tests
FAILS=0
step() { echo "== $1 $(date +%H:%M:%S)"; }
fail() { echo "CHECK FAILED: $1"; FAILS=$((FAILS + 1)); }

# wait for the warm build (same target dir) so the two never race for the cargo lock
while [ ! -e $L/warm_build.done ]; do sleep 10; done
echo "warm build: exit $(cat $L/warm_build.done) (guard $(cat $L/warm_build.guard.done 2>/dev/null))"

step build
$G --class build --need-gib 6 --cap-gib 16 --label q280-build --wait-secs 36000 --max-secs 3600 --log $L/build.log --done $L/build.guard.done -- \
  bash -c "cargo test --release --offline --locked --features gpu-metal --manifest-path $H --lib --no-run && cargo check --release --offline --locked --manifest-path $H --lib --tests" \
  || { grep -E -A12 '^(error|warning: unused)' $L/build.log | tail -80; echo "BUILD FAILED"; exit 100; }
W=$(grep -c '^warning' $L/build.log); echo "warnings: $W (floor 133)"
[ "$W" = 133 ] || fail "the warning count is $W, not 133"
[ "$(grep -c 'Finished' $L/build.log)" -ge 2 ] || fail "the build log lacks both Finished lines"
REL=$(grep -E -o 'target/release/deps/hashline-[0-9a-f]{16}' $L/build.log | tail -1)
[ -n "$REL" ] || { echo "NO TEST BINARY IN THE BUILD LOG"; exit 101; }
B=$R/ops/zkp-mvp/gpu-metal/hashline/$REL
ls -la $B || exit 102
echo "$B" > $L/binary.path
shasum -a 256 $B | tee $L/binary.sha256

step targeted-cpu
$G --class cpu --need-gib 16 --cap-gib 80 --label q280-targeted-cpu --wait-secs 36000 --max-secs 3600 --log $L/targeted_cpu.log --done $L/targeted_cpu.guard.done -- \
  env HL_R13_LOADER_FIXTURES=$F $B --test-threads=4 --nocapture w16r2 shape token_io:: range16_tests::w16_limbs
grep -h "^test result" $L/targeted_cpu.log | tail -2
grep -q "^test result: ok" $L/targeted_cpu.log || { fail "targeted CPU set not ok"; sed -n '/^failures:$/,$p' $L/targeted_cpu.log | head -40; }
grep -q "W16R2-GOLDEN W16R2_RUNG_H24 cpu c6d5c2d8" $L/targeted_cpu.log || fail "the W16R2 rung CPU golden is not c6d5c2d8: $(grep -o 'W16R2-GOLDEN W16R2_RUNG_H24 cpu [0-9a-f]*' $L/targeted_cpu.log)"
grep -q "^W16R2 PRIVACY Q = q_pad = 280" $L/targeted_cpu.log || fail "the Q = 280 pad-block check did not print"
[ "$(grep -c '^W16R2 F6 W16R2_' $L/targeted_cpu.log)" = 3 ] || fail "the F6 counter test did not print its three W16R2 lines"
grep -o 'W16R2-ACCOUNTING {.*}' $L/targeted_cpu.log > $L/accounting_inputs_q280.log
[ "$(grep -c 'W16R2-ACCOUNTING' $L/accounting_inputs_q280.log)" = 6 ] || fail "not six W16R2-ACCOUNTING lines"
python3 $R/results/zk60_w16r2_q280_20261103/recount_q280.py $L/accounting_inputs_q280.log > $R/results/zk60_w16r2_q280_20261103/recount_q280.out.txt 2>&1 \
  || fail "the recount on the code's printed inputs failed"
tail -3 $R/results/zk60_w16r2_q280_20261103/recount_q280.out.txt

step targeted-metal
$G --class gpu --need-gib 30 --cap-gib 120 --label q280-targeted-metal --wait-secs 36000 --max-secs 3600 --log $L/targeted_metal.log --done $L/targeted_metal.guard.done -- \
  env HL_GPU=1 HL_GPU_REQUIRED=1 HL_R13_LOADER_FIXTURES=$F $B --test-threads=4 w16r2 run::fork w16_privacy_gate range16 s24_tests s25_tests s33_tests hash_domain r19b absorb d60 run_capture
grep -h "^test result\|FAILED\|panicked" $L/targeted_metal.log | tail -8
grep -q "^test result: ok" $L/targeted_metal.log || fail "targeted Metal set (m32's) not ok"

step by-name-bundle
# one gpu-class guard around short by-name runs (each `--exact`, the ignored ones alone in their process):
#  dev bytes x2 batch-tail modes; the W16R2 rung golden CPU = Metal x2; the W16R2 trained digests (CPU = Metal at every
#  pass, beside R13's and W16's pins); the W16R2 privacy gate on Metal (rung, 8B) and on the CPU at the 8B; the W16R2
#  rung run under the D12a and D55 verifiers. Logs per run under $L/byname/.
mkdir -p $L/byname
cat > $L/byname/run.sh <<EOF
set -u
B=$B
F=$F
T=$T
O=$L/byname
run() { local name=\$1; shift; echo "-- \$name \$(date +%H:%M:%S)"; "\$@" > \$O/\$name.log 2>&1; echo \$? > \$O/\$name.exit; echo "   exit \$(cat \$O/\$name.exit)"; }
run bytes_default env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 \$B --ignored --exact --nocapture --test-threads=1 \$T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
run bytes_tail0 env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_METAL_BATCH_TAIL_US=0 \$B --ignored --exact --nocapture --test-threads=1 \$T::m4_accuracy_block_proofs_are_byte_identical_on_the_cpu_and_on_metal
run r2rung_default env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 \$B --ignored --exact --nocapture --test-threads=1 private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden
run r2rung_tail0 env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_METAL_BATCH_TAIL_US=0 \$B --ignored --exact --nocapture --test-threads=1 private_block::w16r2_tests::w16r2_rung_cpu_and_metal_digests_equal_the_golden
run trained env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_M4_PHASES=1 HL_M4_WARM_PASSES=3 HL_M4_PROFILES=R13_SHIELD_T128_H24,R13_8B_T128_H24,W16_SHIELD_T128_H24,W16_8B_T128_H24,W16R2_SHIELD_T128_H24,W16R2_8B_T128_H24,W16R2_RUNG_H24 \$B --ignored --exact --nocapture --test-threads=1 \$T::m4_trained_accuracy_block_cpu_and_metal_digests_and_times
run pg_metal_rung env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_R13_LOADER_FIXTURES=\$F \$B --ignored --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16r2_privacy_gate_on_the_metal_path
run pg_metal_8b env HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_W16PG_PROFILES=W16R2_8B_T128_H24 HL_R13_LOADER_FIXTURES=\$F \$B --ignored --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16r2_privacy_gate_on_the_metal_path
run pg_cpu_8b env HL_W16PG_PROFILES=W16R2_8B_T128_H24 HL_W16PG_PAIR=1 HL_R13_LOADER_FIXTURES=\$F \$B --ignored --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16_privacy_gate_at_the_trained_t128_shapes
run pg_cpu_rung env HL_R13_LOADER_FIXTURES=\$F \$B --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::w16r2_privacy_gate_at_the_development_rung
run pg_d55_rung env HL_R13_LOADER_FIXTURES=\$F \$B --exact --nocapture --test-threads=1 private_block::w16_privacy_gate_tests::d55_fork_run_capture_passes_the_w16_gate_checks_at_the_w16r2_rung
run r2run env HL_GPU=1 HL_GPU_REQUIRED=1 HL_METAL_TIMING=0 HL_R13_LOADER_FIXTURES=\$F HL_D55_PROFILE=W16R2_RUNG_H24 HL_D55_L=3 HL_D55_WORKERS=2 HL_D55_PASSES=1 \$B --ignored --exact private_block::run::fork::tests::d55_ab_one_request_serial_against_forks --nocapture --test-threads=1
exit 0
EOF
$G --class gpu --need-gib 60 --cap-gib 160 --label q280-byname --wait-secs 36000 --max-secs 3600 --log $L/byname.log --done $L/byname.guard.done -- \
  bash $L/byname/run.sh
O=$L/byname
for n in bytes_default bytes_tail0 r2rung_default r2rung_tail0 trained pg_metal_rung pg_metal_8b pg_cpu_8b pg_cpu_rung pg_d55_rung r2run; do
  [ "$(cat $O/$n.exit 2>/dev/null)" = 0 ] || fail "$n exited $(cat $O/$n.exit 2>/dev/null)"
  grep -q "test result: ok. 1 passed" $O/$n.log || fail "$n: not 1 passed"
done
for t in bytes_default bytes_tail0; do
  grep -h -o -E "M4-ACCURACY-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{8}" $O/$t.log
  for d in "R13_RUNG_LOW cpu 01fa1b2e" "R13_RUNG_H24 cpu 992034f8" "R13_RUNG_LOW_DD cpu 371e6b00" "R13_RUNG_H24_DD cpu 3ab090df"; do
    grep -q "M4-ACCURACY-DIGEST $d" $O/$t.log || fail "DEV BYTES MOVED ($t): $d"
  done
done
for t in r2rung_default r2rung_tail0; do
  grep -h -o -E "W16R2-RUNG-DIGEST [A-Z0-9_]+ cpu [0-9a-f]{64} metal [0-9a-f]{64}" $O/$t.log
  grep -q -E "W16R2-RUNG-DIGEST W16R2_RUNG_H24 cpu c6d5c2d8[0-9a-f]* metal c6d5c2d8" $O/$t.log || fail "the W16R2 rung golden is not c6d5c2d8 on CPU and Metal ($t)"
done
grep -h "M4-TRAINED.*digest cpu" $O/trained.log | cut -c1-240
for pd in "R13_SHIELD_T128_H24 2b0d04bb" "R13_8B_T128_H24 678953f6" "W16_SHIELD_T128_H24 01a6d51d" "W16_8B_T128_H24 c5e0bdac"; do
  set -- $pd
  grep -q "M4-TRAINED $1 .*digest cpu $2" $O/trained.log || fail "TRAINED DIGEST MOVED: $1 (want $2)"
done
for p in W16R2_8B_T128_H24 W16R2_SHIELD_T128_H24 W16R2_RUNG_H24; do
  for d in $(grep -o -E "M4-TRAINED $p cpu .*digest cpu [0-9a-f]{8}" $O/trained.log | grep -o -E "[0-9a-f]{8}$" | sort -u); do
    n=$(grep -c -E "M4-TRAINED $p cpu .*digest cpu $d[0-9a-f]* metal $d" $O/trained.log)
    echo "W16R2 trained digest at Q 280: $p cpu = metal $d at $n passes"
    [ "$n" -ge 4 ] || fail "$p: digest $d is not CPU = Metal at every pass ($n)"
  done
  [ "$(grep -o -E "M4-TRAINED $p cpu .*digest cpu [0-9a-f]{8}" $O/trained.log | grep -o -E "[0-9a-f]{8}$" | sort -u | wc -l | tr -d ' ')" = 1 ] || fail "$p: not exactly one digest across the passes"
done
# pinned after the first run of this chain (2026-11-03 05:48, binary fd009444..): the W16R2 trained digests at Q = 280
for pd in "W16R2_8B_T128_H24 4e189ccc" "W16R2_SHIELD_T128_H24 a9a19ee5" "W16R2_RUNG_H24 fa656326"; do
  set -- $pd
  [ "$(grep -c "M4-TRAINED $1 cpu .*digest cpu $2[0-9a-f]* metal $2" $O/trained.log)" -ge 4 ] || fail "W16R2 TRAINED DIGEST MOVED: $1 (want $2, CPU = Metal at every pass)"
done
for t in pg_metal_rung pg_metal_8b pg_cpu_8b pg_cpu_rung pg_d55_rung; do
  echo "$t: $(grep -c ' PASS ' $O/$t.log) PASS, $(grep -c ' FAIL ' $O/$t.log) FAIL lines"; grep -h "PG-R2\|C-R2" $O/$t.log | cut -c1-260
  [ "$(grep -c ' FAIL ' $O/$t.log)" = 0 ] || fail "$t: a privacy-gate line FAILED"
done
grep -q "D55-AB W16R2_RUNG_H24 L3 serial: verified" $O/r2run.log || fail "the W16R2 serial run did not verify"
grep -q "D55-AB W16R2_RUNG_H24 L3 forks N2: verified" $O/r2run.log || fail "the W16R2 fork run did not verify"

step done
echo "failed checks: $FAILS"
exit $FAILS
